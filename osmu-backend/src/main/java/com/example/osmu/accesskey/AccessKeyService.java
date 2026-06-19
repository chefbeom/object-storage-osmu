package com.example.osmu.accesskey;

import com.example.osmu.accesskey.repository.AccessKeyRepository;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.organization.repository.TeamRepository;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.UserRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class AccessKeyService {

    private static final List<String> DEFAULT_PERMISSIONS = List.of("READ", "WRITE", "DELETE");
    private static final Set<String> ALLOWED_PERMISSIONS = Set.of("READ", "WRITE", "DELETE", "ADMIN");

    private final AccessKeyRepository accessKeyRepository;
    private final BucketService bucketService;
    private final UserRepository userRepository;
    private final TeamRepository teamRepository;
    private final S3AccessPolicyGenerator policyGenerator;
    private final S3AccessPolicyProvisioner policyProvisioner;
    private final AccessKeySecretCipher secretCipher;
    private final long rotationGraceSeconds;
    private final SecureRandom random = new SecureRandom();

    public AccessKeyService(
            AccessKeyRepository accessKeyRepository,
            BucketService bucketService,
            UserRepository userRepository,
            TeamRepository teamRepository,
            S3AccessPolicyGenerator policyGenerator,
            S3AccessPolicyProvisioner policyProvisioner,
            AccessKeySecretCipher secretCipher,
            @Value("${osmu.access-key.rotation-grace-seconds:300}") long rotationGraceSeconds
    ) {
        this.accessKeyRepository = accessKeyRepository;
        this.bucketService = bucketService;
        this.userRepository = userRepository;
        this.teamRepository = teamRepository;
        this.policyGenerator = policyGenerator;
        this.policyProvisioner = policyProvisioner;
        this.secretCipher = secretCipher;
        this.rotationGraceSeconds = Math.max(0L, rotationGraceSeconds);
    }

    public List<AccessKeyRecord> list(AuthenticatedUser user) {
        return accessKeyRepository.findAllRecords().stream()
                .filter(key -> user.isAdmin() || key.ownerId() == user.id())
                .toList();
    }

    public synchronized CreateAccessKeyResponse create(CreateAccessKeyRequest request, AuthenticatedUser user) {
        long id = accessKeyRepository.nextId();
        String accessKey = "osmu_" + token(18);
        String secretKey = token(36);
        List<AccessKeyBucketScope> bucketScopes = resolveBucketScopes(request, user);
        List<String> allowedBuckets = allowedBuckets(bucketScopes);
        List<String> permissions = permissions(bucketScopes);
        AccessKeyEntity entity = new AccessKeyEntity(
                id,
                user.id(),
                request.name(),
                accessKey,
                secretHash(secretKey),
                secretCipher.encrypt(secretKey),
                null,
                null,
                null,
                allowedBuckets,
                permissions,
                bucketScopes,
                "ACTIVE",
                OffsetDateTime.now(),
                request.expiresAt(),
                null,
                0L
        );
        AccessKeyRecord record = entity.toRecord();
        S3AccessPolicy policy = policyGenerator.generate(id, bucketScopes);
        policyProvisioner.provision(record, secretKey, policy);
        try {
            accessKeyRepository.save(entity);
        } catch (RuntimeException exception) {
            cleanupProvisionedAccessKey(record, exception);
            throw exception;
        }
        return new CreateAccessKeyResponse(
                id,
                request.name(),
                accessKey,
                secretKey,
                policy.policyName(),
                policy.policyDocument(),
                allowedBuckets,
                permissions,
                bucketScopes
        );
    }

    private void cleanupProvisionedAccessKey(AccessKeyRecord record, RuntimeException originalException) {
        try {
            policyProvisioner.deactivate(record);
        } catch (RuntimeException cleanupException) {
            originalException.addSuppressed(cleanupException);
        }
    }

    public void delete(long id, AuthenticatedUser user) {
        AccessKeyRecord existing = accessKeyRepository.findRecordById(id)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Access key not found."));
        if (!user.isAdmin() && existing.ownerId() != user.id()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Access key access denied.");
        }
        deactivate(existing);
    }

    public synchronized BulkDisableAccessKeysResponse bulkDisable(BulkDisableAccessKeysRequest request, AuthenticatedUser user) {
        List<Long> requestedIds = request.keyIds().stream()
                .filter(id -> id != null)
                .distinct()
                .toList();
        List<Long> disabledIds = new ArrayList<>();
        List<Long> skippedIds = new ArrayList<>();
        for (Long keyId : requestedIds) {
            AccessKeyRecord existing = accessKeyRepository.findRecordById(keyId)
                    .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Access key not found."));
            if (!user.isAdmin() && existing.ownerId() != user.id()) {
                throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Access key access denied.");
            }
            if (!"ACTIVE".equals(existing.status())) {
                skippedIds.add(existing.id());
                continue;
            }
            deactivate(existing);
            disabledIds.add(existing.id());
        }
        return new BulkDisableAccessKeysResponse(
                requestedIds.size(),
                disabledIds.size(),
                skippedIds.size(),
                disabledIds,
                skippedIds
        );
    }

    public synchronized CreateAccessKeyResponse rotate(long id, AuthenticatedUser user) {
        AccessKeyRecord existing = accessKeyRepository.findRecordById(id)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Access key not found."));
        if (!user.isAdmin() && existing.ownerId() != user.id()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Access key access denied.");
        }
        if (!"ACTIVE".equals(existing.status()) || isExpired(existing)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Only active access keys can be rotated.");
        }

        String oldSecretKey = decryptStoredSecret(existing.accessKey());
        String rotatedSecretKey = token(36);
        OffsetDateTime previousSecretKeyExpiresAt = rotationGraceSeconds > 0 && oldSecretKey != null && !oldSecretKey.isBlank()
                ? OffsetDateTime.now().plusSeconds(rotationGraceSeconds)
                : null;
        S3AccessPolicy policy = policyGenerator.generate(existing.id(), bucketScopes(existing));
        policyProvisioner.rotateSecret(existing, rotatedSecretKey);
        try {
            accessKeyRepository.updateSecret(
                    existing.id(),
                    secretHash(rotatedSecretKey),
                    secretCipher.encrypt(rotatedSecretKey),
                    previousSecretKeyExpiresAt == null ? null : secretHash(oldSecretKey),
                    previousSecretKeyExpiresAt == null ? null : secretCipher.encrypt(oldSecretKey),
                    previousSecretKeyExpiresAt
            );
        } catch (RuntimeException exception) {
            rollbackSecretRotation(existing, oldSecretKey, exception);
            throw exception;
        }

        return new CreateAccessKeyResponse(
                existing.id(),
                existing.name(),
                existing.accessKey(),
                rotatedSecretKey,
                existing.policyName(),
                policy.policyDocument(),
                existing.allowedBuckets(),
                existing.permissions(),
                bucketScopes(existing)
        );
    }

    public AuthenticatedUser authenticate(String accessKey, String secretKey, String bucketName, String requiredPermission) {
        return authenticateAny(accessKey, secretKey, bucketName, requiredPermission);
    }

    public AuthenticatedUser authenticateAny(String accessKey, String secretKey, String bucketName, String... requiredPermissions) {
        String normalizedAccessKey = accessKey == null ? "" : accessKey.trim();
        String normalizedSecretKey = secretKey == null ? "" : secretKey.trim();
        List<String> normalizedPermissions = normalizeRequiredPermissions(requiredPermissions);
        String normalizedBucketName = bucketService.normalizeName(bucketName);
        if (normalizedAccessKey.isBlank() || normalizedSecretKey.isBlank() || normalizedBucketName.isBlank()) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key authentication required.");
        }
        AccessKeyCredential credential = accessKeyRepository.findCredentialByAccessKey(normalizedAccessKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access key credentials."));
        if (!"ACTIVE".equals(credential.status()) || isExpired(credential) || !matchesActiveSecret(normalizedSecretKey, credential)) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access key credentials.");
        }
        AuthenticatedUser owner = authenticatedOwner(credential.ownerId());
        if (owner == null) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access key owner.");
        }
        boolean allowed = normalizedPermissions.stream()
                .anyMatch(permission -> scopeAllows(credential.bucketScopes(), normalizedBucketName, permission)
                        && canUsePermission(normalizedBucketName, permission, owner));
        if (!allowed) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Access key scope denied.");
        }
        markUsed(credential);
        return owner;
    }

    public String signingSecret(String accessKey) {
        return signingSecrets(accessKey).get(0);
    }

    public List<String> signingSecrets(String accessKey) {
        AccessKeyCredential credential = credential(accessKey);
        assertCredentialActive(credential);
        authenticatedOwnerOrThrow(credential);
        List<String> signingSecrets = new ArrayList<>();
        addSigningSecret(signingSecrets, credential.secretKeyCiphertext());
        if (previousSecretGraceActive(credential)) {
            addSigningSecret(signingSecrets, credential.previousSecretKeyCiphertext());
        }
        if (signingSecrets.isEmpty()) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key signing secret is unavailable.");
        }
        return signingSecrets;
    }

    public AuthenticatedUser authenticateSignedAny(String accessKey, String bucketName, String... requiredPermissions) {
        AccessKeyCredential credential = credential(accessKey);
        assertCredentialActive(credential);
        AuthenticatedUser owner = authenticatedOwnerOrThrow(credential);
        List<String> normalizedPermissions = normalizeRequiredPermissions(requiredPermissions);
        String normalizedBucketName = bucketService.normalizeName(bucketName);
        if (normalizedBucketName.isBlank()) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key authentication required.");
        }
        boolean allowed = normalizedPermissions.stream()
                .anyMatch(permission -> scopeAllows(credential.bucketScopes(), normalizedBucketName, permission)
                        && canUsePermission(normalizedBucketName, permission, owner));
        if (!allowed) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Access key scope denied.");
        }
        markUsed(credential);
        return owner;
    }

    public AccessKeyBucketList authenticateSignedBucketList(String accessKey) {
        AccessKeyCredential credential = credential(accessKey);
        assertCredentialActive(credential);
        AuthenticatedUser owner = authenticatedOwnerOrThrow(credential);
        List<BucketRecord> buckets = scopedBuckets(credential, owner);
        if (buckets.isEmpty()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Access key scope denied.");
        }
        markUsed(credential);
        return new AccessKeyBucketList(owner, buckets);
    }

    public AccessKeyBucketList authenticateBucketList(String accessKey, String secretKey) {
        String normalizedAccessKey = accessKey == null ? "" : accessKey.trim();
        String normalizedSecretKey = secretKey == null ? "" : secretKey.trim();
        if (normalizedAccessKey.isBlank() || normalizedSecretKey.isBlank()) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key authentication required.");
        }
        AccessKeyCredential credential = accessKeyRepository.findCredentialByAccessKey(normalizedAccessKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access key credentials."));
        if (!"ACTIVE".equals(credential.status()) || isExpired(credential) || !matchesActiveSecret(normalizedSecretKey, credential)) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access key credentials.");
        }
        AuthenticatedUser owner = authenticatedOwner(credential.ownerId());
        if (owner == null) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access key owner.");
        }
        List<BucketRecord> buckets = scopedBuckets(credential, owner);
        if (buckets.isEmpty()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Access key scope denied.");
        }
        markUsed(credential);
        return new AccessKeyBucketList(owner, buckets);
    }

    private AccessKeyCredential credential(String accessKey) {
        String normalizedAccessKey = accessKey == null ? "" : accessKey.trim();
        if (normalizedAccessKey.isBlank()) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key authentication required.");
        }
        return accessKeyRepository.findCredentialByAccessKey(normalizedAccessKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access key credentials."));
    }

    private void assertCredentialActive(AccessKeyCredential credential) {
        if (!"ACTIVE".equals(credential.status()) || isExpired(credential)) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access key credentials.");
        }
    }

    private AuthenticatedUser authenticatedOwnerOrThrow(AccessKeyCredential credential) {
        AuthenticatedUser owner = authenticatedOwner(credential.ownerId());
        if (owner == null) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid access key owner.");
        }
        return owner;
    }

    public int deactivateByOwnerId(long ownerId) {
        int deactivated = 0;
        for (AccessKeyRecord accessKey : accessKeyRepository.findRecordsByOwnerId(ownerId)) {
            if (!"ACTIVE".equals(accessKey.status())) {
                continue;
            }
            deactivate(accessKey);
            deactivated++;
        }
        return deactivated;
    }

    private void deactivate(AccessKeyRecord accessKey) {
        policyProvisioner.deactivate(accessKey);
        accessKeyRepository.updateStatus(accessKey.id(), "INACTIVE");
    }

    public synchronized int reconcileActiveKeysForSubject(String subjectType, long subjectId) {
        return reconcileActiveKeysForOwners(ownerIdsForSubject(subjectType, subjectId));
    }

    public synchronized int reconcileActiveKeysForOwners(List<Long> ownerIds) {
        int changed = 0;
        LinkedHashSet<Long> uniqueOwnerIds = new LinkedHashSet<>(ownerIds == null ? List.of() : ownerIds);
        for (Long ownerId : uniqueOwnerIds) {
            if (ownerId == null) {
                continue;
            }
            for (AccessKeyRecord accessKey : accessKeyRepository.findRecordsByOwnerId(ownerId)) {
                if (!"ACTIVE".equals(accessKey.status())) {
                    continue;
                }
                AuthenticatedUser owner = authenticatedOwner(accessKey);
                if (owner == null) {
                    deactivate(accessKey);
                    changed++;
                    continue;
                }
                AccessKeyScope scope = currentScope(accessKey, owner);
                if (scope.bucketScopes().isEmpty()) {
                    deactivate(accessKey);
                    changed++;
                    continue;
                }
                if (scope.equals(new AccessKeyScope(bucketScopes(accessKey)))) {
                    continue;
                }
                List<String> scopedAllowedBuckets = allowedBuckets(scope.bucketScopes());
                List<String> scopedPermissions = permissions(scope.bucketScopes());
                AccessKeyRecord scopedRecord = new AccessKeyRecord(
                        accessKey.id(),
                        accessKey.ownerId(),
                        accessKey.name(),
                        accessKey.accessKey(),
                        accessKey.policyName(),
                        scopedAllowedBuckets,
                        scopedPermissions,
                        scope.bucketScopes(),
                        accessKey.status(),
                        accessKey.createdAt(),
                        accessKey.expiresAt(),
                        accessKey.lastUsedAt(),
                        accessKey.usageCount(),
                        accessKey.rotationGraceExpiresAt()
                );
                try {
                    policyProvisioner.syncPolicy(scopedRecord, policyGenerator.generate(scopedRecord.id(), scope.bucketScopes()));
                    accessKeyRepository.updateScope(scopedRecord.id(), scopedAllowedBuckets, scopedPermissions, scope.bucketScopes());
                    changed++;
                } catch (RuntimeException exception) {
                    deactivate(accessKey);
                    throw exception;
                }
            }
        }
        return changed;
    }

    private List<Long> ownerIdsForSubject(String subjectType, long subjectId) {
        if ("USER".equals(subjectType)) {
            return List.of(subjectId);
        }
        if ("ORGANIZATION".equals(subjectType)) {
            return userRepository.findAll().stream()
                    .filter(user -> user.organizationId() != null && user.organizationId() == subjectId)
                    .map(UserAccount::id)
                    .toList();
        }
        if ("TEAM".equals(subjectType)) {
            return teamRepository.findMemberIds(subjectId);
        }
        return List.of();
    }

    private AuthenticatedUser authenticatedOwner(AccessKeyRecord accessKey) {
        return authenticatedOwner(accessKey.ownerId());
    }

    private AuthenticatedUser authenticatedOwner(long ownerId) {
        UserAccount user = userRepository.findById(ownerId).orElse(null);
        if (user == null || !"ACTIVE".equals(user.status())) {
            return null;
        }
        return new AuthenticatedUser(user.id(), user.loginId(), user.role(), user.organizationId());
    }

    private AccessKeyScope currentScope(AccessKeyRecord accessKey, AuthenticatedUser owner) {
        List<BucketPermissionDecision> decisions = bucketScopes(accessKey).stream()
                .flatMap(scope -> normalizedBuckets(scope.bucketName(), owner).stream()
                        .map(bucketName -> new BucketPermissionDecision(bucketName, currentPermissions(bucketName, scope.permissions(), owner))))
                .filter(decision -> !decision.permissions().isEmpty())
                .toList();
        if (decisions.isEmpty()) {
            return new AccessKeyScope(List.of());
        }
        return new AccessKeyScope(decisions.stream()
                .map(decision -> new AccessKeyBucketScope(decision.bucketName(), decision.permissions()))
                .toList());
    }

    private List<String> normalizedBuckets(String bucketName, AuthenticatedUser owner) {
        if (!"*".equals(bucketName)) {
            return List.of(bucketName);
        }
        if (owner.isAdmin()) {
            return List.of("*");
        }
        return bucketService.list(owner).stream()
                .map(BucketRecord::name)
                .toList();
    }

    private List<String> currentPermissions(String bucketName, List<String> permissions, AuthenticatedUser owner) {
        if ("*".equals(bucketName) && owner.isAdmin()) {
            return permissions;
        }
        List<String> currentPermissions = new ArrayList<>();
        for (String permission : permissions) {
            if (canUsePermission(bucketName, permission, owner)) {
                currentPermissions.add(permission);
            }
        }
        return currentPermissions;
    }

    private List<BucketRecord> scopedBuckets(AccessKeyCredential credential, AuthenticatedUser owner) {
        LinkedHashMap<String, BucketRecord> bucketsByName = new LinkedHashMap<>();
        List<AccessKeyBucketScope> bucketScopes = credential.bucketScopes() == null ? List.of() : credential.bucketScopes();
        for (AccessKeyBucketScope scope : bucketScopes) {
            if (scope == null) {
                continue;
            }
            List<String> permissions = scope.permissions() == null ? List.of() : scope.permissions();
            if ("*".equals(scope.bucketName())) {
                for (BucketRecord bucket : bucketService.list(owner)) {
                    if (permissions.stream().anyMatch(permission -> canUsePermission(bucket.name(), permission, owner))) {
                        bucketsByName.putIfAbsent(bucket.name(), bucket);
                    }
                }
                continue;
            }
            String bucketName = bucketService.normalizeName(scope.bucketName());
            if (bucketName.isBlank()) {
                continue;
            }
            if (permissions.stream().anyMatch(permission -> canUsePermission(bucketName, permission, owner))) {
                bucketsByName.putIfAbsent(bucketName, bucketService.get(bucketName));
            }
        }
        return List.copyOf(bucketsByName.values());
    }

    private boolean canUsePermission(String bucketName, String permission, AuthenticatedUser owner) {
        try {
            if ("READ".equals(permission)) {
                bucketService.assertCanRead(bucketName, owner);
            } else if ("WRITE".equals(permission)) {
                bucketService.assertCanWrite(bucketName, owner);
            } else if ("DELETE".equals(permission)) {
                bucketService.assertCanDeleteObject(bucketName, owner);
            } else if ("ADMIN".equals(permission)) {
                bucketService.assertCanManage(owner, bucketService.get(bucketName));
            } else {
                return false;
            }
            return true;
        } catch (ApiException exception) {
            if (exception.code() == ApiErrorCode.AUTHORIZATION_FAILED || exception.code() == ApiErrorCode.NOT_FOUND) {
                return false;
            }
            throw exception;
        }
    }

    private String token(int size) {
        byte[] bytes = new byte[size];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private List<String> resolveAllowedBuckets(CreateAccessKeyRequest request, AuthenticatedUser user) {
        if (request.allowedBuckets() == null || request.allowedBuckets().isEmpty()) {
            List<String> buckets = bucketService.list(user).stream()
                    .map(BucketRecord::name)
                    .toList();
            if (buckets.isEmpty()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Access key requires at least one bucket.");
            }
            return buckets;
        }

        LinkedHashSet<String> bucketNames = new LinkedHashSet<>();
        for (String rawBucketName : request.allowedBuckets()) {
            String bucketName = bucketService.normalizeName(rawBucketName);
            if (bucketName.isBlank()) {
                continue;
            }
            bucketNames.add(bucketService.get(bucketName, user).name());
        }
        if (bucketNames.isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Access key requires at least one bucket.");
        }
        return List.copyOf(bucketNames);
    }

    private List<AccessKeyBucketScope> resolveBucketScopes(CreateAccessKeyRequest request, AuthenticatedUser user) {
        if (request.bucketScopes() != null && !request.bucketScopes().isEmpty()) {
            return normalizeBucketScopes(request.bucketScopes(), user);
        }
        List<String> allowedBuckets = resolveAllowedBuckets(request, user);
        List<String> permissions = normalizePermissions(request.permissions(), DEFAULT_PERMISSIONS);
        List<AccessKeyBucketScope> bucketScopes = allowedBuckets.stream()
                .map(bucketName -> new AccessKeyBucketScope(bucketName, permissions))
                .toList();
        validateRequestedScope(bucketScopes, user);
        return bucketScopes;
    }

    private List<AccessKeyBucketScope> normalizeBucketScopes(List<AccessKeyBucketScope> rawBucketScopes, AuthenticatedUser user) {
        LinkedHashMap<String, LinkedHashSet<String>> permissionsByBucket = new LinkedHashMap<>();
        for (AccessKeyBucketScope rawBucketScope : rawBucketScopes) {
            if (rawBucketScope == null) {
                continue;
            }
            String bucketName = bucketService.normalizeName(rawBucketScope.bucketName());
            if (bucketName.isBlank()) {
                continue;
            }
            String normalizedBucketName = bucketService.get(bucketName, user).name();
            permissionsByBucket.computeIfAbsent(normalizedBucketName, ignored -> new LinkedHashSet<>())
                    .addAll(normalizePermissions(rawBucketScope.permissions(), List.of()));
        }
        if (permissionsByBucket.isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Access key requires at least one bucket scope.");
        }
        List<AccessKeyBucketScope> normalized = permissionsByBucket.entrySet().stream()
                .map(entry -> new AccessKeyBucketScope(entry.getKey(), List.copyOf(entry.getValue())))
                .toList();
        validateRequestedScope(normalized, user);
        return normalized;
    }

    private List<String> normalizePermissions(List<String> rawPermissions, List<String> defaultPermissions) {
        if (rawPermissions == null || rawPermissions.isEmpty()) {
            if (defaultPermissions.isEmpty()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Access key requires at least one permission.");
            }
            return defaultPermissions;
        }
        LinkedHashSet<String> permissions = new LinkedHashSet<>();
        for (String rawPermission : rawPermissions) {
            String permission = rawPermission == null ? "" : rawPermission.trim().toUpperCase(Locale.ROOT);
            if (!ALLOWED_PERMISSIONS.contains(permission)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid access key permission.");
            }
            permissions.add(permission);
        }
        if (permissions.isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Access key requires at least one permission.");
        }
        return List.copyOf(permissions);
    }

    private void validateRequestedScope(List<AccessKeyBucketScope> bucketScopes, AuthenticatedUser user) {
        for (AccessKeyBucketScope bucketScope : bucketScopes) {
            for (String permission : bucketScope.permissions()) {
                if ("READ".equals(permission)) {
                    bucketService.assertCanRead(bucketScope.bucketName(), user);
                } else if ("WRITE".equals(permission)) {
                    bucketService.assertCanWrite(bucketScope.bucketName(), user);
                } else if ("DELETE".equals(permission)) {
                    bucketService.assertCanDeleteObject(bucketScope.bucketName(), user);
                } else if ("ADMIN".equals(permission)) {
                    bucketService.assertCanManage(user, bucketService.get(bucketScope.bucketName()));
                }
            }
        }
    }

    private List<AccessKeyBucketScope> bucketScopes(AccessKeyRecord accessKey) {
        if (accessKey.bucketScopes() != null && !accessKey.bucketScopes().isEmpty()) {
            return accessKey.bucketScopes();
        }
        return accessKey.allowedBuckets().stream()
                .map(bucketName -> new AccessKeyBucketScope(bucketName, accessKey.permissions()))
                .toList();
    }

    private List<String> allowedBuckets(List<AccessKeyBucketScope> bucketScopes) {
        return bucketScopes.stream()
                .map(AccessKeyBucketScope::bucketName)
                .distinct()
                .toList();
    }

    private List<String> permissions(List<AccessKeyBucketScope> bucketScopes) {
        LinkedHashSet<String> permissions = new LinkedHashSet<>();
        for (String permission : List.of("READ", "WRITE", "DELETE", "ADMIN")) {
            if (bucketScopes.stream().anyMatch(bucketScope -> bucketScope.permissions().contains(permission))) {
                permissions.add(permission);
            }
        }
        return List.copyOf(permissions);
    }

    private String secretHash(String secretKey) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(secretKey.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("Failed to hash access key secret.", exception);
        }
    }

    private String normalizePermission(String rawPermission) {
        String permission = rawPermission == null ? "" : rawPermission.trim().toUpperCase(Locale.ROOT);
        if (!ALLOWED_PERMISSIONS.contains(permission)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid access key permission.");
        }
        return permission;
    }

    private List<String> normalizeRequiredPermissions(String... rawPermissions) {
        if (rawPermissions == null || rawPermissions.length == 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "At least one access key permission is required.");
        }
        LinkedHashSet<String> permissions = new LinkedHashSet<>();
        for (String rawPermission : rawPermissions) {
            permissions.add(normalizePermission(rawPermission));
        }
        return List.copyOf(permissions);
    }

    private boolean isExpired(AccessKeyCredential credential) {
        return credential.expiresAt() != null && !credential.expiresAt().isAfter(OffsetDateTime.now());
    }

    private boolean isExpired(AccessKeyRecord accessKey) {
        return accessKey.expiresAt() != null && !accessKey.expiresAt().isAfter(OffsetDateTime.now());
    }

    private String decryptStoredSecret(String accessKey) {
        try {
            return accessKeyRepository.findCredentialByAccessKey(accessKey)
                    .map(AccessKeyCredential::secretKeyCiphertext)
                    .filter(ciphertext -> ciphertext != null && !ciphertext.isBlank())
                    .map(secretCipher::decrypt)
                    .filter(secret -> secret != null && !secret.isBlank())
                    .orElse(null);
        } catch (RuntimeException exception) {
            return null;
        }
    }

    private void rollbackSecretRotation(AccessKeyRecord accessKey, String oldSecretKey, RuntimeException originalException) {
        if (oldSecretKey == null || oldSecretKey.isBlank()) {
            return;
        }
        try {
            policyProvisioner.rotateSecret(accessKey, oldSecretKey);
        } catch (RuntimeException rollbackException) {
            originalException.addSuppressed(rollbackException);
        }
    }

    private void markUsed(AccessKeyCredential credential) {
        accessKeyRepository.markUsed(credential.id(), OffsetDateTime.now());
    }

    private void addSigningSecret(List<String> signingSecrets, String ciphertext) {
        String signingSecret = secretCipher.decrypt(ciphertext);
        if (signingSecret != null && !signingSecret.isBlank()) {
            signingSecrets.add(signingSecret);
        }
    }

    private boolean matchesActiveSecret(String secretKey, AccessKeyCredential credential) {
        if (secretMatches(secretKey, credential.secretKeyHash())) {
            return true;
        }
        return previousSecretGraceActive(credential) && secretMatches(secretKey, credential.previousSecretKeyHash());
    }

    private boolean previousSecretGraceActive(AccessKeyCredential credential) {
        return credential.previousSecretKeyExpiresAt() != null
                && credential.previousSecretKeyExpiresAt().isAfter(OffsetDateTime.now());
    }

    private boolean secretMatches(String secretKey, String expectedHash) {
        if (expectedHash == null || expectedHash.isBlank()) {
            return false;
        }
        return MessageDigest.isEqual(
                secretHash(secretKey).getBytes(StandardCharsets.UTF_8),
                expectedHash.getBytes(StandardCharsets.UTF_8)
        );
    }

    private boolean scopeAllows(List<AccessKeyBucketScope> bucketScopes, String bucketName, String requiredPermission) {
        if (bucketScopes == null || bucketScopes.isEmpty()) {
            return false;
        }
        return bucketScopes.stream().anyMatch(scope -> bucketMatches(scope.bucketName(), bucketName)
                && (scope.permissions().contains(requiredPermission) || scope.permissions().contains("ADMIN")));
    }

    private boolean bucketMatches(String scopedBucketName, String bucketName) {
        return "*".equals(scopedBucketName) || bucketName.equals(scopedBucketName);
    }

    private record AccessKeyScope(List<AccessKeyBucketScope> bucketScopes) {
    }

    private record BucketPermissionDecision(String bucketName, List<String> permissions) {
    }
}
