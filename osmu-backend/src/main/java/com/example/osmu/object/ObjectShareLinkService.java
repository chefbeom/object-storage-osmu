package com.example.osmu.object;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.repository.ObjectShareLinkRepository;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class ObjectShareLinkService {

    private static final int DEFAULT_EXPIRES_SECONDS = 3600;
    private static final int MIN_EXPIRES_SECONDS = 60;
    private static final int MAX_EXPIRES_SECONDS = 7 * 24 * 60 * 60;
    private static final int MAX_NOTE_LENGTH = 512;
    private static final int MAX_DOWNLOAD_LIMIT = 100_000;
    private static final int MIN_PASSWORD_LENGTH = 8;
    private static final int MAX_PASSWORD_LENGTH = 128;
    private static final int MAX_IP_ALLOWLIST_LENGTH = 512;
    private static final int MAX_IP_ALLOWLIST_ENTRIES = 20;
    private static final String IPV4_LITERAL_PATTERN =
            "^(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}$";
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final ObjectShareLinkRepository shareLinkRepository;
    private final ObjectSharePolicyService sharePolicyService;
    private final BucketService bucketService;
    private final ObjectService objectService;

    public ObjectShareLinkService(
            ObjectShareLinkRepository shareLinkRepository,
            ObjectSharePolicyService sharePolicyService,
            BucketService bucketService,
            ObjectService objectService
    ) {
        this.shareLinkRepository = shareLinkRepository;
        this.sharePolicyService = sharePolicyService;
        this.bucketService = bucketService;
        this.objectService = objectService;
    }

    public ObjectShareLinkIssue create(String bucketName, ObjectShareLinkCreateRequest request, AuthenticatedUser user) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.assertCanRead(bucket.name(), user);
        ObjectMetadataDetail metadata = objectService.metadata(bucket.name(), request.key(), user);
        if (metadata.storageSizeBytes() == null) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Object is missing in storage.");
        }

        OffsetDateTime now = OffsetDateTime.now();
        String token = generateUniqueToken();
        String tokenHash = hashToken(token);
        ObjectSharePolicy policy = sharePolicyService.current();
        String password = password(request.password(), policy);
        String allowedIpCidrs = normalizeAllowedIpCidrs(request.allowedIpCidrs(), policy);
        ObjectShareLink link = shareLinkRepository.save(new ObjectShareLink(
                shareLinkRepository.nextId(),
                tokenHash,
                hashPassword(tokenHash, password),
                allowedIpCidrs,
                bucket.name(),
                metadata.key(),
                user.id(),
                "ACTIVE",
                now.plusSeconds(expiresInSeconds(request.expiresInSeconds(), policy)),
                note(request.note()),
                maxDownloads(request.maxDownloads(), policy),
                0,
                null,
                now,
                null
        ));
        return new ObjectShareLinkIssue(link, token);
    }

    public List<ObjectShareLink> list(String bucketName, String objectKey, Integer limit, AuthenticatedUser user) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.assertCanRead(bucket.name(), user);
        int normalizedLimit = normalizeLimit(limit);
        List<ObjectShareLink> links = clean(objectKey).isBlank()
                ? shareLinkRepository.findByBucket(bucket.name(), normalizedLimit)
                : shareLinkRepository.findByBucketAndKey(bucket.name(), objectService.metadata(bucket.name(), objectKey, user).key(), normalizedLimit);
        return links.stream().map(this::expireIfNeeded).toList();
    }

    public ObjectShareLink revoke(String bucketName, long linkId, AuthenticatedUser user) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        ObjectShareLink link = shareLinkRepository.findById(linkId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object share link not found."));
        if (!link.bucketName().equals(bucket.name())) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Object share link not found.");
        }
        if (link.createdByUserId() != user.id()) {
            bucketService.assertCanManage(user, bucket);
        }
        ObjectShareLink current = expireIfNeeded(link);
        if (!"ACTIVE".equals(current.status())) {
            return current;
        }
        return shareLinkRepository.save(current.withStatus("REVOKED", OffsetDateTime.now()));
    }

    public ObjectShareLinkCleanupResponse cleanupExpired(String bucketName, AuthenticatedUser user) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.assertCanManage(user, bucket);
        return new ObjectShareLinkCleanupResponse(
                bucket.name(),
                shareLinkRepository.expireActiveBefore(bucket.name(), OffsetDateTime.now())
        );
    }

    public ObjectShareLinkDownload openDownload(String token, String password, String clientIp) {
        String tokenHash = hashToken(normalizeToken(token));
        ObjectShareLink link = shareLinkRepository.findByTokenHash(tokenHash)
                .map(this::expireIfNeeded)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object share link not found."));
        if (!"ACTIVE".equals(link.status())) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Object share link not found.");
        }
        assertPasswordMatches(link, tokenHash, password);
        assertClientIpAllowed(link, clientIp);
        ObjectShareLink limited = limitIfNeeded(link);
        ObjectShareLink downloaded = shareLinkRepository.recordDownload(limited, OffsetDateTime.now());
        return new ObjectShareLinkDownload(downloaded, objectService.downloadShared(downloaded.bucketName(), downloaded.objectKey()));
    }

    private ObjectShareLink expireIfNeeded(ObjectShareLink link) {
        if (!"ACTIVE".equals(link.status()) || link.expiresAt().isAfter(OffsetDateTime.now())) {
            return link;
        }
        return shareLinkRepository.save(link.withStatus("EXPIRED", null));
    }

    private ObjectShareLink limitIfNeeded(ObjectShareLink link) {
        if (link.maxDownloads() == null || link.downloadCount() < link.maxDownloads()) {
            return link;
        }
        shareLinkRepository.save(link.withStatus("LIMIT_REACHED", null));
        throw new ApiException(ApiErrorCode.NOT_FOUND, "Object share link not found.");
    }

    private String generateUniqueToken() {
        for (int attempt = 0; attempt < 5; attempt++) {
            byte[] bytes = new byte[32];
            SECURE_RANDOM.nextBytes(bytes);
            String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
            if (shareLinkRepository.findByTokenHash(hashToken(token)).isEmpty()) {
                return token;
            }
        }
        throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object share link token generation failed.");
    }

    private String hashToken(String token) {
        return sha256(token);
    }

    private String hashPassword(String tokenHash, String password) {
        return password.isBlank() ? "" : sha256(tokenHash + ":" + password);
    }

    private void assertPasswordMatches(ObjectShareLink link, String tokenHash, String password) {
        if (!link.passwordProtected()) {
            return;
        }
        String provided = clean(password);
        if (provided.isBlank() || !hashPassword(tokenHash, provided).equals(link.passwordHash())) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Object share link not found.");
        }
    }

    private void assertClientIpAllowed(ObjectShareLink link, String clientIp) {
        if (!link.ipRestricted()) {
            return;
        }
        InetAddress clientAddress = parseIpLiteral(clean(clientIp), ApiErrorCode.NOT_FOUND);
        for (String cidr : link.allowedIpCidrs().split(",")) {
            if (cidrMatches(parseCidrBlock(cidr, ApiErrorCode.NOT_FOUND), clientAddress)) {
                return;
            }
        }
        throw new ApiException(ApiErrorCode.NOT_FOUND, "Object share link not found.");
    }

    private String sha256(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "SHA-256 is not available.");
        }
    }

    private String normalizeToken(String token) {
        String normalized = clean(token);
        if (normalized.length() < 32 || normalized.length() > 256 || !normalized.matches("^[A-Za-z0-9_-]+$")) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Object share link not found.");
        }
        return normalized;
    }

    private int expiresInSeconds(Integer value, ObjectSharePolicy policy) {
        int normalized = value == null ? DEFAULT_EXPIRES_SECONDS : value;
        int maxAllowed = Math.min(MAX_EXPIRES_SECONDS, policy.maxExpiresSeconds());
        if (normalized < MIN_EXPIRES_SECONDS || normalized > maxAllowed) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "expiresInSeconds must be between 60 and " + maxAllowed + ".");
        }
        return normalized;
    }

    private int normalizeLimit(Integer limit) {
        if (limit == null) {
            return 50;
        }
        if (limit < 1 || limit > 200) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "limit must be between 1 and 200.");
        }
        return limit;
    }

    private String note(String value) {
        String normalized = clean(value);
        if (normalized.length() > MAX_NOTE_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "note must be 512 characters or fewer.");
        }
        return normalized;
    }

    private Integer maxDownloads(Integer value, ObjectSharePolicy policy) {
        Integer maxAllowed = policy.maxDownloadsLimit() == null
                ? MAX_DOWNLOAD_LIMIT
                : Math.min(MAX_DOWNLOAD_LIMIT, policy.maxDownloadsLimit());
        if (value == null) {
            return policy.maxDownloadsLimit();
        }
        if (value < 1 || value > maxAllowed) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "maxDownloads must be between 1 and " + maxAllowed + ".");
        }
        return value;
    }

    private String password(String value, ObjectSharePolicy policy) {
        String normalized = clean(value);
        if (policy.requirePassword() && normalized.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Share policy requires password.");
        }
        if (normalized.isBlank()) {
            return "";
        }
        if (normalized.length() < MIN_PASSWORD_LENGTH || normalized.length() > MAX_PASSWORD_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "password must be between 8 and 128 characters.");
        }
        return normalized;
    }

    private String normalizeAllowedIpCidrs(String value, ObjectSharePolicy policy) {
        String normalized = clean(value);
        if (policy.requireIpAllowlist() && normalized.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Share policy requires allowedIpCidrs.");
        }
        if (normalized.isBlank()) {
            return "";
        }
        if (normalized.length() > MAX_IP_ALLOWLIST_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "allowedIpCidrs must be 512 characters or fewer.");
        }
        List<String> cidrs = new ArrayList<>();
        for (String entry : normalized.split("[,\\s]+")) {
            String cidr = clean(entry);
            if (cidr.isBlank()) {
                continue;
            }
            if (cidrs.size() >= MAX_IP_ALLOWLIST_ENTRIES) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "allowedIpCidrs supports up to 20 entries.");
            }
            cidrs.add(normalizeCidr(cidr));
        }
        return String.join(",", cidrs);
    }

    private String normalizeCidr(String value) {
        CidrBlock block = parseCidrBlock(value, ApiErrorCode.VALIDATION_ERROR);
        if (!value.contains("/")) {
            return block.address().getHostAddress();
        }
        return block.address().getHostAddress() + "/" + block.prefixLength();
    }

    private CidrBlock parseCidrBlock(String value, ApiErrorCode errorCode) {
        String cidr = clean(value);
        String[] parts = cidr.split("/", -1);
        if (parts.length > 2 || parts[0].isBlank()) {
            throw shareIpException(errorCode);
        }
        InetAddress address = parseIpLiteral(parts[0], errorCode);
        int bits = address.getAddress().length * 8;
        int prefixLength = bits;
        if (parts.length == 2) {
            try {
                prefixLength = Integer.parseInt(parts[1]);
            } catch (NumberFormatException exception) {
                throw shareIpException(errorCode);
            }
            if (prefixLength < 0 || prefixLength > bits) {
                throw shareIpException(errorCode);
            }
        }
        return new CidrBlock(address, prefixLength);
    }

    private InetAddress parseIpLiteral(String value, ApiErrorCode errorCode) {
        String ip = clean(value);
        if (ip.isBlank() || ip.contains("%") || (!ip.contains(":") && !ip.matches(IPV4_LITERAL_PATTERN))) {
            throw shareIpException(errorCode);
        }
        try {
            return InetAddress.getByName(ip);
        } catch (UnknownHostException exception) {
            throw shareIpException(errorCode);
        }
    }

    private boolean cidrMatches(CidrBlock block, InetAddress clientAddress) {
        byte[] network = block.address().getAddress();
        byte[] client = clientAddress.getAddress();
        if (network.length != client.length) {
            return false;
        }
        int fullBytes = block.prefixLength() / 8;
        int remainingBits = block.prefixLength() % 8;
        for (int index = 0; index < fullBytes; index++) {
            if (network[index] != client[index]) {
                return false;
            }
        }
        if (remainingBits == 0) {
            return true;
        }
        int mask = (0xFF << (8 - remainingBits)) & 0xFF;
        return (network[fullBytes] & mask) == (client[fullBytes] & mask);
    }

    private ApiException shareIpException(ApiErrorCode errorCode) {
        if (errorCode == ApiErrorCode.VALIDATION_ERROR) {
            return new ApiException(ApiErrorCode.VALIDATION_ERROR, "allowedIpCidrs must contain IP or CIDR literals.");
        }
        return new ApiException(ApiErrorCode.NOT_FOUND, "Object share link not found.");
    }

    private String clean(String value) {
        return value == null ? "" : value.trim();
    }

    private record CidrBlock(InetAddress address, int prefixLength) {
    }
}
