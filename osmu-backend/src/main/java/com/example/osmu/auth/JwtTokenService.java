package com.example.osmu.auth;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.UserProfile;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class JwtTokenService {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {
    };
    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder BASE64_URL_DECODER = Base64.getUrlDecoder();

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final byte[] secretBytes;
    private final String issuer;
    private final long accessTokenTtlSeconds;
    private final long refreshTokenTtlSeconds;

    public JwtTokenService(
            @Value("${osmu.auth.jwt.secret}") String secret,
            @Value("${osmu.auth.jwt.issuer:osmu}") String issuer,
            @Value("${osmu.auth.jwt.access-token-ttl-seconds:3600}") long accessTokenTtlSeconds,
            @Value("${osmu.auth.jwt.refresh-token-ttl-seconds:604800}") long refreshTokenTtlSeconds
    ) {
        if (secret == null || secret.length() < 32) {
            throw new IllegalStateException("osmu.auth.jwt.secret must be at least 32 characters.");
        }
        if (accessTokenTtlSeconds <= 0 || refreshTokenTtlSeconds <= 0) {
            throw new IllegalStateException("JWT token TTL values must be positive.");
        }
        this.secretBytes = secret.getBytes(StandardCharsets.UTF_8);
        this.issuer = issuer;
        this.accessTokenTtlSeconds = accessTokenTtlSeconds;
        this.refreshTokenTtlSeconds = refreshTokenTtlSeconds;
    }

    public String createAccessToken(UserProfile user) {
        return createToken(user, "access", accessTokenTtlSeconds);
    }

    public String createRefreshToken(UserProfile user) {
        return createToken(user, "refresh", refreshTokenTtlSeconds);
    }

    public JwtClaims verifyAccessToken(String token) {
        JwtClaims claims = verify(token);
        if (!"access".equals(claims.tokenType())) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access token.");
        }
        return claims;
    }

    public JwtClaims verifyRefreshToken(String token) {
        JwtClaims claims = verify(token);
        if (!"refresh".equals(claims.tokenType())) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid refresh token.");
        }
        return claims;
    }

    public String tokenHash(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("Failed to hash token.", exception);
        }
    }

    private String createToken(UserProfile user, String tokenType, long ttlSeconds) {
        long now = Instant.now().getEpochSecond();
        Map<String, Object> header = Map.of(
                "alg", "HS256",
                "typ", "JWT"
        );
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("iss", issuer);
        payload.put("sub", Long.toString(user.id()));
        payload.put("loginId", user.loginId());
        payload.put("role", user.role());
        payload.put("typ", tokenType);
        payload.put("jti", UUID.randomUUID().toString());
        payload.put("iat", now);
        payload.put("exp", now + ttlSeconds);

        String unsignedToken = encodeJson(header) + "." + encodeJson(payload);
        return unsignedToken + "." + sign(unsignedToken);
    }

    private JwtClaims verify(String token) {
        try {
            String[] parts = token.split("\\.", -1);
            if (parts.length != 3) {
                throw invalidToken();
            }

            String unsignedToken = parts[0] + "." + parts[1];
            String expectedSignature = sign(unsignedToken);
            if (!MessageDigest.isEqual(
                    expectedSignature.getBytes(StandardCharsets.UTF_8),
                    parts[2].getBytes(StandardCharsets.UTF_8)
            )) {
                throw invalidToken();
            }

            Map<String, Object> header = decodeJson(parts[0]);
            if (!"HS256".equals(header.get("alg"))) {
                throw invalidToken();
            }

            Map<String, Object> payload = decodeJson(parts[1]);
            if (!issuer.equals(payload.get("iss"))) {
                throw invalidToken();
            }

            long expiresAt = asLong(payload.get("exp"));
            if (expiresAt <= Instant.now().getEpochSecond()) {
                throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access token expired.");
            }

            return new JwtClaims(
                    requiredString(payload, "sub"),
                    requiredString(payload, "loginId"),
                    requiredString(payload, "role"),
                    requiredString(payload, "typ"),
                    expiresAt
            );
        } catch (ApiException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw invalidToken();
        }
    }

    private String encodeJson(Map<String, Object> value) {
        try {
            return BASE64_URL_ENCODER.encodeToString(objectMapper.writeValueAsBytes(value));
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Failed to encode JWT.", exception);
        }
    }

    private Map<String, Object> decodeJson(String encoded) {
        try {
            return objectMapper.readValue(BASE64_URL_DECODER.decode(encoded), MAP_TYPE);
        } catch (Exception exception) {
            throw invalidToken();
        }
    }

    private String sign(String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secretBytes, "HmacSHA256"));
            return BASE64_URL_ENCODER.encodeToString(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("Failed to sign JWT.", exception);
        }
    }

    private String requiredString(Map<String, Object> payload, String key) {
        Object value = payload.get(key);
        if (value instanceof String text && !text.isBlank()) {
            return text;
        }
        throw invalidToken();
    }

    private long asLong(Object value) {
        if (value instanceof Number number) {
            return number.longValue();
        }
        throw invalidToken();
    }

    private ApiException invalidToken() {
        return new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access token.");
    }
}
