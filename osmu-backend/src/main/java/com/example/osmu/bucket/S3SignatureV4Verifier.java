package com.example.osmu.bucket;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Enumeration;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeSet;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class S3SignatureV4Verifier {

    private static final String ALGORITHM = "AWS4-HMAC-SHA256";
    private static final String SERVICE = "s3";
    private static final String TERMINATOR = "aws4_request";
    private static final String CONTENT_SHA256_HEADER = "x-amz-content-sha256";
    private static final String DATE_HEADER = "x-amz-date";
    private static final String PRESIGNED_ALGORITHM = "X-Amz-Algorithm";
    private static final String PRESIGNED_CREDENTIAL = "X-Amz-Credential";
    private static final String PRESIGNED_DATE = "X-Amz-Date";
    private static final String PRESIGNED_EXPIRES = "X-Amz-Expires";
    private static final String PRESIGNED_SIGNED_HEADERS = "X-Amz-SignedHeaders";
    private static final String PRESIGNED_SIGNATURE = "X-Amz-Signature";
    private static final String UNSIGNED_PAYLOAD = "UNSIGNED-PAYLOAD";
    private static final long MAX_PRESIGNED_EXPIRES_SECONDS = 604800L;
    private static final DateTimeFormatter AMZ_DATE_FORMATTER =
            DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'").withZone(ZoneOffset.UTC);
    private static final HexFormat HEX = HexFormat.of();

    private final Clock clock;
    private final Duration maxClockSkew;

    @Autowired
    public S3SignatureV4Verifier(
            @Value("${osmu.s3.sigv4.clock-skew-seconds:900}") long maxClockSkewSeconds
    ) {
        this(Clock.systemUTC(), maxClockSkewSeconds);
    }

    S3SignatureV4Verifier(Clock clock, long maxClockSkewSeconds) {
        this.clock = clock;
        this.maxClockSkew = Duration.ofSeconds(Math.max(0L, maxClockSkewSeconds));
    }

    public boolean isSignatureRequest(HttpServletRequest request) {
        String authorization = request.getHeader("Authorization");
        return authorization != null && authorization.startsWith(ALGORITHM)
                || ALGORITHM.equals(request.getParameter(PRESIGNED_ALGORITHM));
    }

    public String accessKey(HttpServletRequest request) {
        if (isPresignedRequest(request)) {
            return parsePresignedAuthorization(request).accessKey();
        }
        return parseAuthorization(request).accessKey();
    }

    public void verify(HttpServletRequest request, String secretKey) {
        if (secretKey == null || secretKey.isBlank()) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key signing secret is unavailable.");
        }
        if (isPresignedRequest(request)) {
            verifyPresigned(request, secretKey);
            return;
        }
        ParsedAuthorization authorization = parseAuthorization(request);
        if (!SERVICE.equals(authorization.service()) || !TERMINATOR.equals(authorization.terminator())) {
            throw invalidSignature();
        }

        String requestDate = requiredHeader(request, DATE_HEADER);
        if (!requestDate.startsWith(authorization.date())) {
            throw invalidSignature();
        }
        assertWithinClockSkew(requestDate);

        String canonicalRequest = canonicalRequest(request, authorization.signedHeaders());
        String credentialScope = authorization.date() + "/" + authorization.region() + "/" + authorization.service() + "/" + authorization.terminator();
        String stringToSign = ALGORITHM + "\n"
                + requestDate + "\n"
                + credentialScope + "\n"
                + sha256Hex(canonicalRequest);
        String expectedSignature = HEX.formatHex(hmac(signingKey(secretKey, authorization), stringToSign)).toLowerCase(Locale.ROOT);
        if (!MessageDigest.isEqual(
                expectedSignature.getBytes(StandardCharsets.UTF_8),
                authorization.signature().toLowerCase(Locale.ROOT).getBytes(StandardCharsets.UTF_8)
        )) {
            throw invalidSignature();
        }
    }

    public void verifyAny(HttpServletRequest request, List<String> secretKeys) {
        if (secretKeys == null || secretKeys.isEmpty()) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key signing secret is unavailable.");
        }
        ApiException lastException = null;
        for (String secretKey : secretKeys) {
            try {
                verify(request, secretKey);
                return;
            } catch (ApiException exception) {
                lastException = exception;
            }
        }
        throw lastException == null ? invalidSignature() : lastException;
    }

    private void verifyPresigned(HttpServletRequest request, String secretKey) {
        ParsedAuthorization authorization = parsePresignedAuthorization(request);
        String requestDate = requiredParameter(request, PRESIGNED_DATE);
        if (!requestDate.startsWith(authorization.date())) {
            throw invalidSignature();
        }
        assertPresignedNotExpired(requestDate, requiredParameter(request, PRESIGNED_EXPIRES));

        String canonicalRequest = canonicalRequest(request, authorization.signedHeaders(), UNSIGNED_PAYLOAD, PRESIGNED_SIGNATURE);
        String credentialScope = authorization.date() + "/" + authorization.region() + "/" + authorization.service() + "/" + authorization.terminator();
        String stringToSign = ALGORITHM + "\n"
                + requestDate + "\n"
                + credentialScope + "\n"
                + sha256Hex(canonicalRequest);
        String expectedSignature = HEX.formatHex(hmac(signingKey(secretKey, authorization), stringToSign)).toLowerCase(Locale.ROOT);
        if (!MessageDigest.isEqual(
                expectedSignature.getBytes(StandardCharsets.UTF_8),
                authorization.signature().toLowerCase(Locale.ROOT).getBytes(StandardCharsets.UTF_8)
        )) {
            throw invalidSignature();
        }
    }

    private ParsedAuthorization parseAuthorization(HttpServletRequest request) {
        String authorization = request.getHeader("Authorization");
        if (authorization == null || !authorization.startsWith(ALGORITHM)) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "AWS SigV4 authorization required.");
        }
        Map<String, String> attributes = parseAuthorizationAttributes(authorization.substring(ALGORITHM.length()).trim());
        String credential = requiredAttribute(attributes, "Credential");
        String signedHeaders = requiredAttribute(attributes, "SignedHeaders");
        String signature = requiredAttribute(attributes, "Signature");
        String[] credentialParts = credential.split("/");
        if (credentialParts.length != 5) {
            throw invalidSignature();
        }
        return new ParsedAuthorization(
                credentialParts[0],
                credentialParts[1],
                credentialParts[2],
                credentialParts[3],
                credentialParts[4],
                signedHeaders.toLowerCase(Locale.ROOT),
                signature
        );
    }

    private ParsedAuthorization parsePresignedAuthorization(HttpServletRequest request) {
        if (!ALGORITHM.equals(request.getParameter(PRESIGNED_ALGORITHM))) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "AWS SigV4 authorization required.");
        }
        String credential = urlDecode(requiredParameter(request, PRESIGNED_CREDENTIAL));
        requiredParameter(request, PRESIGNED_DATE);
        String expires = requiredParameter(request, PRESIGNED_EXPIRES);
        String signedHeaders = requiredParameter(request, PRESIGNED_SIGNED_HEADERS);
        String signature = requiredParameter(request, PRESIGNED_SIGNATURE);
        try {
            long expiresSeconds = Long.parseLong(expires);
            if (expiresSeconds <= 0 || expiresSeconds > MAX_PRESIGNED_EXPIRES_SECONDS) {
                throw invalidSignature();
            }
        } catch (NumberFormatException exception) {
            throw invalidSignature();
        }
        String[] credentialParts = credential.split("/");
        if (credentialParts.length != 5) {
            throw invalidSignature();
        }
        if (!SERVICE.equals(credentialParts[3]) || !TERMINATOR.equals(credentialParts[4])) {
            throw invalidSignature();
        }
        return new ParsedAuthorization(
                credentialParts[0],
                credentialParts[1],
                credentialParts[2],
                credentialParts[3],
                credentialParts[4],
                signedHeaders.toLowerCase(Locale.ROOT),
                signature
        );
    }

    private Map<String, String> parseAuthorizationAttributes(String value) {
        Map<String, String> attributes = new LinkedHashMap<>();
        for (String token : value.split(",")) {
            int separator = token.indexOf('=');
            if (separator <= 0) {
                continue;
            }
            attributes.put(token.substring(0, separator).trim(), token.substring(separator + 1).trim());
        }
        return attributes;
    }

    private String requiredAttribute(Map<String, String> attributes, String name) {
        String value = attributes.get(name);
        if (value == null || value.isBlank()) {
            throw invalidSignature();
        }
        return value;
    }

    private String canonicalRequest(HttpServletRequest request, String signedHeaders) {
        return canonicalRequest(request, signedHeaders, requiredPayloadHashHeader(request), null);
    }

    private String canonicalRequest(HttpServletRequest request, String signedHeaders, String payloadHash, String excludedQueryName) {
        CanonicalHeaders headers = canonicalHeaders(request, signedHeaders);
        return request.getMethod() + "\n"
                + canonicalUri(request) + "\n"
                + canonicalQueryString(request, excludedQueryName) + "\n"
                + headers.value() + "\n"
                + headers.signedHeaders() + "\n"
                + payloadHash.trim();
    }

    private String requiredPayloadHashHeader(HttpServletRequest request) {
        String payloadHash = request.getHeader(CONTENT_SHA256_HEADER);
        if (payloadHash == null || payloadHash.isBlank()) {
            throw invalidSignature();
        }
        return payloadHash;
    }

    private String canonicalUri(HttpServletRequest request) {
        String uri = request.getAttribute(VirtualHostedStyleS3RequestFilter.ORIGINAL_REQUEST_URI_ATTRIBUTE) instanceof String originalUri
                ? originalUri
                : request.getRequestURI();
        if (uri == null || uri.isBlank()) {
            return "/";
        }
        return uriEncode(urlDecode(uri), false);
    }

    private String canonicalQueryString(HttpServletRequest request) {
        return canonicalQueryString(request, null);
    }

    private String canonicalQueryString(HttpServletRequest request, String excludedName) {
        String queryString = request.getQueryString();
        if (queryString == null || queryString.isBlank()) {
            return "";
        }
        List<QueryPart> parts = new ArrayList<>();
        for (String token : queryString.split("&", -1)) {
            int separator = token.indexOf('=');
            String name = separator < 0 ? token : token.substring(0, separator);
            String value = separator < 0 ? "" : token.substring(separator + 1);
            if (excludedName != null && excludedName.equals(urlDecode(name))) {
                continue;
            }
            parts.add(new QueryPart(uriEncode(urlDecode(name), true), uriEncode(urlDecode(value), true)));
        }
        return parts.stream()
                .sorted(Comparator.comparing(QueryPart::name).thenComparing(QueryPart::value))
                .map(part -> part.name() + "=" + part.value())
                .reduce((left, right) -> left + "&" + right)
                .orElse("");
    }

    private CanonicalHeaders canonicalHeaders(HttpServletRequest request, String signedHeaders) {
        TreeSet<String> names = new TreeSet<>();
        for (String rawName : signedHeaders.split(";")) {
            String name = rawName.trim().toLowerCase(Locale.ROOT);
            if (name.isBlank()) {
                throw invalidSignature();
            }
            names.add(name);
        }
        String canonicalSignedHeaders = String.join(";", names);
        if (!canonicalSignedHeaders.equals(signedHeaders)) {
            throw invalidSignature();
        }
        StringBuilder canonical = new StringBuilder();
        for (String name : names) {
            canonical.append(name).append(':').append(headerValue(request, name)).append('\n');
        }
        return new CanonicalHeaders(canonical.toString(), canonicalSignedHeaders);
    }

    private String headerValue(HttpServletRequest request, String name) {
        List<String> values = new ArrayList<>();
        Enumeration<String> headers = request.getHeaders(name);
        while (headers != null && headers.hasMoreElements()) {
            values.add(headers.nextElement());
        }
        if (values.isEmpty() && "host".equals(name)) {
            values.add(hostFallback(request));
        }
        if (values.isEmpty()) {
            throw invalidSignature();
        }
        return String.join(",", values).trim().replaceAll("\\s+", " ");
    }

    private String hostFallback(HttpServletRequest request) {
        int port = request.getServerPort();
        if (port == 80 || port == 443 || port <= 0) {
            return request.getServerName();
        }
        return request.getServerName() + ":" + port;
    }

    private String requiredHeader(HttpServletRequest request, String name) {
        String value = request.getHeader(name);
        if (value == null || value.isBlank()) {
            throw invalidSignature();
        }
        return value.trim();
    }

    private String requiredParameter(HttpServletRequest request, String name) {
        String value = request.getParameter(name);
        if (value == null || value.isBlank()) {
            throw invalidSignature();
        }
        return value.trim();
    }

    private boolean isPresignedRequest(HttpServletRequest request) {
        return ALGORITHM.equals(request.getParameter(PRESIGNED_ALGORITHM));
    }

    private void assertWithinClockSkew(String requestDate) {
        Instant signedAt = parseAmzDate(requestDate);
        Instant now = Instant.now(clock);
        if (signedAt.isBefore(now.minus(maxClockSkew)) || signedAt.isAfter(now.plus(maxClockSkew))) {
            throw invalidSignature();
        }
    }

    private void assertPresignedNotExpired(String requestDate, String expires) {
        Instant signedAt = parseAmzDate(requestDate);
        long expiresSeconds;
        try {
            expiresSeconds = Long.parseLong(expires);
        } catch (NumberFormatException exception) {
            throw invalidSignature();
        }
        Instant now = Instant.now(clock);
        Instant validFrom = signedAt.minus(maxClockSkew);
        Instant validUntil = signedAt.plusSeconds(expiresSeconds).plus(maxClockSkew);
        if (now.isBefore(validFrom) || now.isAfter(validUntil)) {
            throw invalidSignature();
        }
    }

    private Instant parseAmzDate(String value) {
        try {
            return AMZ_DATE_FORMATTER.parse(value, Instant::from);
        } catch (DateTimeParseException exception) {
            throw invalidSignature();
        }
    }

    private byte[] signingKey(String secretKey, ParsedAuthorization authorization) {
        byte[] dateKey = hmac(("AWS4" + secretKey).getBytes(StandardCharsets.UTF_8), authorization.date());
        byte[] regionKey = hmac(dateKey, authorization.region());
        byte[] serviceKey = hmac(regionKey, authorization.service());
        return hmac(serviceKey, authorization.terminator());
    }

    private byte[] hmac(byte[] key, String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            return mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "HMAC-SHA256 is unavailable.");
        }
    }

    private String sha256Hex(String value) {
        try {
            return HEX.formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "SHA-256 is unavailable.");
        }
    }

    private String urlDecode(String value) {
        return URLDecoder.decode(value == null ? "" : value, StandardCharsets.UTF_8);
    }

    private String uriEncode(String value, boolean encodeSlash) {
        StringBuilder output = new StringBuilder();
        for (byte current : value.getBytes(StandardCharsets.UTF_8)) {
            int unsigned = current & 0xff;
            if (isUnreserved(unsigned) || (!encodeSlash && unsigned == '/')) {
                output.append((char) unsigned);
            } else {
                output.append('%');
                String hex = Integer.toHexString(unsigned).toUpperCase(Locale.ROOT);
                if (hex.length() == 1) {
                    output.append('0');
                }
                output.append(hex);
            }
        }
        return output.toString();
    }

    private boolean isUnreserved(int value) {
        return value >= 'A' && value <= 'Z'
                || value >= 'a' && value <= 'z'
                || value >= '0' && value <= '9'
                || value == '-' || value == '_' || value == '.' || value == '~';
    }

    private ApiException invalidSignature() {
        return new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid AWS SigV4 signature.");
    }

    private record ParsedAuthorization(
            String accessKey,
            String date,
            String region,
            String service,
            String terminator,
            String signedHeaders,
            String signature
    ) {
    }

    private record QueryPart(String name, String value) {
    }

    private record CanonicalHeaders(String value, String signedHeaders) {
    }
}
