package com.example.osmu.bucket;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.repository.BucketPermissionRepository;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.bucket.repository.BucketTagRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.object.StoredObjectRecord;
import com.example.osmu.object.ObjectVersionStorageKeys;
import com.example.osmu.organization.OrganizationRecord;
import com.example.osmu.organization.TeamRecord;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.organization.repository.TeamRepository;
import com.example.osmu.quota.repository.QuotaPolicyRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.example.osmu.storageprofile.repository.StorageProfileAssignmentRepository;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.UserRepository;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.stereotype.Service;

@Service
public class BucketService {

    private static final long DEFAULT_QUOTA_BYTES = 100L * 1024L * 1024L * 1024L;
    private static final Pattern BUCKET_NAME_PATTERN = Pattern.compile("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$");
    private static final Set<String> ALLOWED_PERMISSIONS = Set.of("READ", "WRITE", "DELETE", "ADMIN");

    private final BucketRepository bucketRepository;
    private final BucketPermissionRepository bucketPermissionRepository;
    private final BucketTagRepository bucketTagRepository;
    private final ObjectStorageAdapter storageAdapter;
    private final ObjectMetadataRepository objectMetadataRepository;
    private final ObjectVersionRepository objectVersionRepository;
    private final UserRepository userRepository;
    private final OrganizationRepository organizationRepository;
    private final TeamRepository teamRepository;
    private final QuotaPolicyRepository quotaPolicyRepository;
    private final StorageProfileAssignmentRepository storageProfileAssignmentRepository;

    public BucketService(
            BucketRepository bucketRepository,
            BucketPermissionRepository bucketPermissionRepository,
            BucketTagRepository bucketTagRepository,
            ObjectStorageAdapter storageAdapter,
            ObjectMetadataRepository objectMetadataRepository,
            ObjectVersionRepository objectVersionRepository,
            UserRepository userRepository,
            OrganizationRepository organizationRepository,
            TeamRepository teamRepository,
            QuotaPolicyRepository quotaPolicyRepository,
            StorageProfileAssignmentRepository storageProfileAssignmentRepository
    ) {
        this.bucketRepository = bucketRepository;
        this.bucketPermissionRepository = bucketPermissionRepository;
        this.bucketTagRepository = bucketTagRepository;
        this.storageAdapter = storageAdapter;
        this.objectMetadataRepository = objectMetadataRepository;
        this.objectVersionRepository = objectVersionRepository;
        this.userRepository = userRepository;
        this.organizationRepository = organizationRepository;
        this.teamRepository = teamRepository;
        this.quotaPolicyRepository = quotaPolicyRepository;
        this.storageProfileAssignmentRepository = storageProfileAssignmentRepository;
    }

    public List<BucketRecord> list() {
        return bucketRepository.findAll();
    }

    public List<BucketRecord> list(AuthenticatedUser user) {
        if (user.isAdmin()) {
            return list();
        }
        return bucketRepository.findAll().stream()
                .filter(bucket -> canAccess(user, bucket) || hasAnyExplicitPermission(user, bucket))
                .toList();
    }

    public synchronized BucketRecord create(CreateBucketRequest request, AuthenticatedUser user) {
        String bucketName = normalizeName(request.name());
        validateBucketName(bucketName);
        if (bucketRepository.existsByName(bucketName)) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Bucket already exists.");
        }

        long quotaBytes = request.quotaBytes() == null ? DEFAULT_QUOTA_BYTES : request.quotaBytes();
        BucketOwner owner = resolveOwner(request, user);
        BucketRecord bucket = new BucketRecord(
                bucketRepository.nextId(),
                bucketName,
                owner.ownerType(),
                owner.ownerId(),
                quotaBytes,
                0L,
                0L,
                OffsetDateTime.now()
        );
        storageAdapter.createBucket(bucketName);
        try {
            return bucketRepository.save(bucket);
        } catch (RuntimeException exception) {
            storageAdapter.deleteBucket(bucketName);
            throw exception;
        }
    }

    public BucketRecord get(String bucketName) {
        return bucketRepository.findByName(normalizeName(bucketName))
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Bucket not found."));
    }

    public BucketRecord get(String bucketName, AuthenticatedUser user) {
        BucketRecord bucket = get(bucketName);
        assertCanAccess(user, bucket);
        return bucket;
    }

    public synchronized void delete(String bucketName, AuthenticatedUser user) {
        BucketRecord bucket = get(bucketName, user);
        assertCanManage(user, bucket);
        if (bucket.objectCount() > 0) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Bucket is not empty.");
        }
        if (objectVersionRepository.existsByBucketName(bucket.name())) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Bucket is not empty.");
        }
        storageAdapter.deleteBucket(bucket.name());
        objectMetadataRepository.deleteByBucketName(bucket.name());
        objectVersionRepository.deleteByBucketName(bucket.name());
        bucketPermissionRepository.deleteByBucketId(bucket.id());
        bucketTagRepository.delete(bucket.name());
        storageProfileAssignmentRepository.deleteByBucketName(bucket.name());
        bucketRepository.deleteByName(bucket.name());
    }

    public synchronized BucketSyncResponse syncUsage(String bucketName, AuthenticatedUser user) {
        BucketRecord current = get(bucketName, user);
        assertCanManage(user, current);
        List<StoredObjectRecord> indexedObjects = objectMetadataRepository.findAllByBucketName(current.name());
        Map<String, StoredObjectRecord> indexedByKey = new LinkedHashMap<>();
        for (StoredObjectRecord object : indexedObjects) {
            indexedByKey.put(object.key(), object);
        }
        List<StoredObjectRecord> storageObjects = storageAdapter.listObjects(current.name(), "");
        List<StoredObjectRecord> visibleObjects = new ArrayList<>();
        Set<String> visibleKeys = new LinkedHashSet<>();
        long metadataAddedCount = 0L;
        long metadataUpdatedCount = 0L;
        for (StoredObjectRecord object : storageObjects) {
            if (ObjectVersionStorageKeys.isInternalStorageKey(object.key())) {
                continue;
            }
            StoredObjectRecord existing = indexedByKey.get(object.key());
            StoredObjectRecord synced = existing == null ? object : reconcileSyncedObject(object, existing);
            if (existing == null) {
                metadataAddedCount++;
            } else if (!sameSyncedMetadata(existing, synced)) {
                metadataUpdatedCount++;
            }
            visibleObjects.add(synced);
            visibleKeys.add(synced.key());
        }
        long metadataRemovedCount = indexedObjects.stream()
                .filter(object -> !visibleKeys.contains(object.key()))
                .count();
        long usedBytes = storageObjects.stream()
                .filter(object -> !ObjectVersionStorageKeys.isUploadStagingStorageKey(object.key()))
                .mapToLong(StoredObjectRecord::sizeBytes)
                .sum();
        long objectCount = storageObjects.stream()
                .filter(object -> !ObjectVersionStorageKeys.isUploadStagingStorageKey(object.key()))
                .count();
        objectMetadataRepository.replaceBucketObjects(current.name(), visibleObjects);
        BucketRecord synced = bucketRepository.save(new BucketRecord(
                current.id(),
                current.name(),
                current.ownerType(),
                current.ownerId(),
                current.quotaBytes(),
                usedBytes,
                objectCount,
                current.createdAt()
        ));
        long internalStorageObjectCount = storageObjects.stream()
                .filter(object -> ObjectVersionStorageKeys.isInternalStorageKey(object.key()))
                .count();
        long stagingStorageObjectCount = storageObjects.stream()
                .filter(object -> ObjectVersionStorageKeys.isUploadStagingStorageKey(object.key()))
                .count();
        long deletedObjectMetadataRetainedCount = visibleObjects.stream()
                .filter(StoredObjectRecord::isDeleted)
                .count();
        return BucketSyncResponse.of(
                current,
                synced,
                storageObjects.size(),
                visibleObjects.size(),
                internalStorageObjectCount,
                stagingStorageObjectCount,
                indexedObjects.size(),
                visibleObjects.size(),
                metadataAddedCount,
                metadataUpdatedCount,
                metadataRemovedCount,
                deletedObjectMetadataRetainedCount
        );
    }

    private StoredObjectRecord reconcileSyncedObject(StoredObjectRecord actual, StoredObjectRecord existing) {
        StoredObjectRecord synced = existing.isDeleted() ? actual.withDeletedAt(existing.deletedAt()) : actual;
        if (actual.etag().isBlank() || !sameEtag(actual.etag(), existing.etag())) {
            return synced;
        }
        if (actual.checksums().isEmpty() && !existing.checksums().isEmpty()) {
            synced = synced.withChecksums(existing.checksums());
        }
        if (actual.userMetadata().isEmpty() && !existing.userMetadata().isEmpty()) {
            synced = synced.withUserMetadata(existing.userMetadata());
        }
        return synced;
    }

    private boolean sameEtag(String first, String second) {
        String normalizedFirst = normalizeEtag(first);
        String normalizedSecond = normalizeEtag(second);
        return !normalizedFirst.isBlank() && normalizedFirst.equals(normalizedSecond);
    }

    private boolean sameSyncedMetadata(StoredObjectRecord existing, StoredObjectRecord synced) {
        return existing.sizeBytes() == synced.sizeBytes()
                && Objects.equals(normalizeContentType(existing.contentType()), normalizeContentType(synced.contentType()))
                && Objects.equals(existing.tags(), synced.tags())
                && Objects.equals(existing.deletedAt(), synced.deletedAt())
                && Objects.equals(normalizeEtag(existing.etag()), normalizeEtag(synced.etag()))
                && Objects.equals(existing.checksums(), synced.checksums())
                && Objects.equals(existing.userMetadata(), synced.userMetadata());
    }

    private String normalizeEtag(String value) {
        String normalized = value == null ? "" : value.trim();
        if (normalized.length() >= 2 && normalized.startsWith("\"") && normalized.endsWith("\"")) {
            return normalized.substring(1, normalized.length() - 1);
        }
        return normalized;
    }

    private String normalizeContentType(String value) {
        return value == null ? "" : value.trim();
    }

    public synchronized void applyObjectChange(String bucketName, long sizeDelta, long objectCountDelta) {
        BucketRecord current = get(bucketName);
        validateObjectChange(current, sizeDelta, objectCountDelta);

        bucketRepository.save(new BucketRecord(
                current.id(),
                current.name(),
                current.ownerType(),
                current.ownerId(),
                current.quotaBytes(),
                current.usedBytes() + sizeDelta,
                current.objectCount() + objectCountDelta,
                current.createdAt()
        ));
    }

    public void assertObjectChangeAllowed(String bucketName, long sizeDelta, long objectCountDelta) {
        validateObjectChange(get(bucketName), sizeDelta, objectCountDelta);
    }

    public void assertCanAccess(AuthenticatedUser user, BucketRecord bucket) {
        if (!canAccess(user, bucket) && !hasAnyExplicitPermission(user, bucket)) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Bucket access denied.");
        }
    }

    public void assertCanRead(String bucketName, AuthenticatedUser user) {
        BucketRecord bucket = get(bucketName);
        if (!canAccess(user, bucket) && !hasExplicitPermission(user, bucket, "READ")) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Bucket read denied.");
        }
    }

    public void assertCanWrite(String bucketName, AuthenticatedUser user) {
        BucketRecord bucket = get(bucketName);
        if (!canAccess(user, bucket) && !hasExplicitPermission(user, bucket, "WRITE")) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Bucket write denied.");
        }
    }

    public void assertCanDeleteObject(String bucketName, AuthenticatedUser user) {
        BucketRecord bucket = get(bucketName);
        if (!canAccess(user, bucket) && !hasExplicitPermission(user, bucket, "DELETE")) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Bucket delete denied.");
        }
    }

    public List<BucketPermissionRecord> listPermissions(String bucketName, AuthenticatedUser user) {
        BucketRecord bucket = get(bucketName, user);
        assertCanManage(user, bucket);
        return bucketPermissionRepository.findByBucketId(bucket.id());
    }

    public synchronized List<BucketPermissionRecord> grantPermissions(
            String bucketName,
            GrantBucketPermissionRequest request,
            AuthenticatedUser user
    ) {
        BucketRecord bucket = get(bucketName, user);
        assertCanManage(user, bucket);

        String subjectType = normalizeSubjectType(request.subjectType());
        long subjectId = request.subjectId();
        validateSubject(subjectType, subjectId, user);

        List<String> permissions = normalizePermissions(request.permissions());
        OffsetDateTime now = OffsetDateTime.now();
        for (String permission : permissions) {
            if (bucketPermissionRepository.exists(bucket.id(), subjectType, subjectId, permission)) {
                continue;
            }
            bucketPermissionRepository.save(new BucketPermissionRecord(
                    bucketPermissionRepository.nextId(),
                    bucket.id(),
                    subjectType,
                    subjectId,
                    permission,
                    now,
                    now
            ));
        }
        return bucketPermissionRepository.findByBucketId(bucket.id());
    }

    public synchronized BucketPermissionRecord revokePermission(String bucketName, long permissionId, AuthenticatedUser user) {
        BucketRecord bucket = get(bucketName, user);
        assertCanManage(user, bucket);
        BucketPermissionRecord permission = bucketPermissionRepository.findById(permissionId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Bucket permission not found."));
        if (permission.bucketId() != bucket.id()) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Bucket permission not found.");
        }
        validateSubject(permission.subjectType(), permission.subjectId(), user);
        bucketPermissionRepository.deleteById(permission.id());
        return permission;
    }

    public void assertCanManage(AuthenticatedUser user, BucketRecord bucket) {
        if (!canManage(user, bucket)) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Bucket management denied.");
        }
    }

    private boolean canAccess(AuthenticatedUser user, BucketRecord bucket) {
        return user.isAdmin()
                || ("USER".equals(bucket.ownerType()) && bucket.ownerId() == user.id())
                || ("ORG".equals(bucket.ownerType()) && user.organizationId() != null && bucket.ownerId() == user.organizationId());
    }

    private boolean canManage(AuthenticatedUser user, BucketRecord bucket) {
        return user.isAdmin()
                || ("USER".equals(bucket.ownerType()) && bucket.ownerId() == user.id())
                || ("ORG".equals(bucket.ownerType()) && user.isOrgAdmin() && user.organizationId() != null && bucket.ownerId() == user.organizationId())
                || hasExplicitPermission(user, bucket, "ADMIN");
    }

    private boolean hasAnyExplicitPermission(AuthenticatedUser user, BucketRecord bucket) {
        return bucketPermissionRepository.findByBucketId(bucket.id()).stream()
                .anyMatch(permission -> appliesTo(user, permission));
    }

    private boolean hasExplicitPermission(AuthenticatedUser user, BucketRecord bucket, String requiredPermission) {
        return bucketPermissionRepository.findByBucketId(bucket.id()).stream()
                .filter(permission -> "ADMIN".equals(permission.permission()) || requiredPermission.equals(permission.permission()))
                .anyMatch(permission -> appliesTo(user, permission));
    }

    private boolean appliesTo(AuthenticatedUser user, BucketPermissionRecord permission) {
        if ("USER".equals(permission.subjectType())) {
            return permission.subjectId() == user.id();
        }
        if ("TEAM".equals(permission.subjectType())) {
            return teamRepository.hasMember(permission.subjectId(), user.id());
        }
        return "ORGANIZATION".equals(permission.subjectType())
                && user.organizationId() != null
                && permission.subjectId() == user.organizationId();
    }

    private BucketOwner resolveOwner(CreateBucketRequest request, AuthenticatedUser user) {
        String ownerType = request.ownerType() == null || request.ownerType().isBlank()
                ? "USER"
                : request.ownerType().trim().toUpperCase(Locale.ROOT);

        if ("USER".equals(ownerType)) {
            long ownerId = request.ownerId() == null ? user.id() : request.ownerId();
            if (!user.isAdmin() && ownerId != user.id()) {
                throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "User bucket owner denied.");
            }
            validateUserOwner(ownerId);
            return new BucketOwner("USER", ownerId);
        }

        if ("ORG".equals(ownerType)) {
            Long ownerId = request.ownerId() == null ? user.organizationId() : request.ownerId();
            if (ownerId == null) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Organization owner is required.");
            }
            if (!user.isAdmin()) {
                if (!user.isOrgAdmin() || user.organizationId() == null || ownerId.longValue() != user.organizationId()) {
                    throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Organization bucket owner denied.");
                }
            }
            validateOrganizationOwner(ownerId);
            return new BucketOwner("ORG", ownerId);
        }

        throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid bucket owner type.");
    }

    private void validateUserOwner(long ownerId) {
        if (userRepository.findById(ownerId).isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket user owner not found.");
        }
    }

    private void validateOrganizationOwner(long ownerId) {
        if (organizationRepository.findById(ownerId).isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket organization owner not found.");
        }
    }

    private String normalizeSubjectType(String rawSubjectType) {
        String subjectType = rawSubjectType == null ? "" : rawSubjectType.trim().toUpperCase(Locale.ROOT);
        if (!Set.of("USER", "ORGANIZATION", "TEAM").contains(subjectType)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid bucket permission subject type.");
        }
        return subjectType;
    }

    private List<String> normalizePermissions(List<String> rawPermissions) {
        if (rawPermissions == null || rawPermissions.isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket permission is required.");
        }
        LinkedHashSet<String> permissions = new LinkedHashSet<>();
        for (String rawPermission : rawPermissions) {
            String permission = rawPermission == null ? "" : rawPermission.trim().toUpperCase(Locale.ROOT);
            if (!ALLOWED_PERMISSIONS.contains(permission)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid bucket permission.");
            }
            permissions.add(permission);
        }
        if (permissions.isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket permission is required.");
        }
        return List.copyOf(permissions);
    }

    private void validateSubject(String subjectType, long subjectId, AuthenticatedUser actor) {
        if ("USER".equals(subjectType)) {
            UserAccount subject = userRepository.findById(subjectId)
                    .orElseThrow(() -> new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket permission user not found."));
            if (actor.isOrgAdmin() && (actor.organizationId() == null || !actor.organizationId().equals(subject.organizationId()))) {
                throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Bucket permission subject denied.");
            }
            return;
        }

        if ("TEAM".equals(subjectType)) {
            TeamRecord team = teamRepository.findById(subjectId)
                    .orElseThrow(() -> new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket permission team not found."));
            if (actor.isOrgAdmin() && (actor.organizationId() == null || actor.organizationId() != team.organizationId())) {
                throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Bucket permission subject denied.");
            }
            return;
        }

        organizationRepository.findById(subjectId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.VALIDATION_ERROR, "Bucket permission organization not found."));
        if (actor.isOrgAdmin() && (actor.organizationId() == null || actor.organizationId() != subjectId)) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Bucket permission subject denied.");
        }
    }

    private void validateObjectChange(BucketRecord current, long sizeDelta, long objectCountDelta) {
        long nextUsedBytes = current.usedBytes() + sizeDelta;
        long nextObjectCount = current.objectCount() + objectCountDelta;

        if (nextUsedBytes < 0 || nextObjectCount < 0) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Invalid bucket usage state.");
        }
        if (nextUsedBytes > effectiveBucketQuotaBytes(current)) {
            throw new ApiException(ApiErrorCode.QUOTA_EXCEEDED, "Bucket quota exceeded.");
        }
        validateOwnerQuota(current, sizeDelta);
    }

    private long effectiveBucketQuotaBytes(BucketRecord current) {
        return quotaPolicyRepository.findByTarget("BUCKET", current.id())
                .map(policy -> policy.quotaBytes())
                .orElse(current.quotaBytes());
    }

    private void validateOwnerQuota(BucketRecord current, long sizeDelta) {
        if (sizeDelta <= 0) {
            return;
        }
        if ("USER".equals(current.ownerType())) {
            validateUserQuota(current, sizeDelta);
            return;
        }
        validateOrganizationQuota(current, sizeDelta);
    }

    private void validateUserQuota(BucketRecord current, long sizeDelta) {
        long quotaBytes = quotaPolicyRepository.findByTarget("USER", current.ownerId())
                .map(policy -> policy.quotaBytes())
                .orElse(0L);
        if (quotaBytes <= 0) {
            return;
        }
        long userUsedBytes = bucketRepository.findAll().stream()
                .filter(bucket -> "USER".equals(bucket.ownerType()) && bucket.ownerId() == current.ownerId())
                .mapToLong(BucketRecord::usedBytes)
                .sum();
        if (userUsedBytes + sizeDelta > quotaBytes) {
            throw new ApiException(ApiErrorCode.QUOTA_EXCEEDED, "User quota exceeded.");
        }
    }

    private void validateOrganizationQuota(BucketRecord current, long sizeDelta) {
        if (!"ORG".equals(current.ownerType())) {
            return;
        }
        OrganizationRecord organization = organizationRepository.findById(current.ownerId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.INTERNAL_ERROR, "Bucket organization owner is invalid."));
        long quotaBytes = quotaPolicyRepository.findByTarget("ORGANIZATION", current.ownerId())
                .map(policy -> policy.quotaBytes())
                .orElse(organization.defaultQuotaBytes());
        long organizationUsedBytes = bucketRepository.findAll().stream()
                .filter(bucket -> "ORG".equals(bucket.ownerType()) && bucket.ownerId() == current.ownerId())
                .mapToLong(BucketRecord::usedBytes)
                .sum();
        if (organizationUsedBytes + sizeDelta > quotaBytes) {
            throw new ApiException(ApiErrorCode.QUOTA_EXCEEDED, "Organization quota exceeded.");
        }
    }

    public long totalUsedBytes() {
        return bucketRepository.findAll().stream().mapToLong(BucketRecord::usedBytes).sum();
    }

    public long totalQuotaBytes() {
        return bucketRepository.findAll().stream().mapToLong(BucketRecord::quotaBytes).sum();
    }

    public long totalObjectCount() {
        return bucketRepository.findAll().stream().mapToLong(BucketRecord::objectCount).sum();
    }

    public String normalizeName(String bucketName) {
        return bucketName == null ? "" : bucketName.trim().toLowerCase(Locale.ROOT);
    }

    private void validateBucketName(String bucketName) {
        if (!BUCKET_NAME_PATTERN.matcher(bucketName).matches()
                || bucketName.contains("..")
                || bucketName.contains(".-")
                || bucketName.contains("-.")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid S3 bucket name.");
        }
    }

    private record BucketOwner(String ownerType, long ownerId) {
    }
}
