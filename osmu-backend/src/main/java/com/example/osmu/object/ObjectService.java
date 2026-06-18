package com.example.osmu.object;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.repository.InMemoryMultipartUploadPartChecksumRepository;
import com.example.osmu.object.repository.MultipartUploadPartChecksumRepository;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.object.repository.PresignedUploadSessionRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;
import java.util.UUID;
import java.util.regex.Pattern;
import java.util.zip.CRC32;
import java.util.zip.CRC32C;
import java.util.zip.Checksum;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class ObjectService {

    private static final int DEFAULT_LIST_LIMIT = 100;
    private static final int MAX_LIST_LIMIT = 1000;
    private static final int DEFAULT_PRESIGNED_EXPIRES_SECONDS = 900;
    private static final int MAX_TAG_COUNT = 10;
    private static final int MAX_TAG_KEY_LENGTH = 128;
    private static final int MAX_TAG_VALUE_LENGTH = 256;
    private static final long DEFAULT_MULTIPART_PART_SIZE_BYTES = 64L * 1024L * 1024L;
    private static final long MIN_MULTIPART_PART_SIZE_BYTES = 5L * 1024L * 1024L;
    private static final int MAX_MULTIPART_PART_COUNT = 10_000;
    private static final String UPLOAD_MODE_PRESIGNED_PUT = "PRESIGNED_PUT";
    private static final String UPLOAD_MODE_MULTIPART = "MULTIPART";
    private static final String AWS_CHECKSUM_SHA256_HEADER = "x-amz-checksum-sha256";
    private static final String AWS_CHECKSUM_SHA1_HEADER = "x-amz-checksum-sha1";
    private static final String AWS_CHECKSUM_CRC32_HEADER = "x-amz-checksum-crc32";
    private static final String AWS_CHECKSUM_CRC32C_HEADER = "x-amz-checksum-crc32c";
    private static final String AWS_CHECKSUM_CRC64NVME_HEADER = "x-amz-checksum-crc64nvme";
    private static final Pattern TAG_KEY_PATTERN = Pattern.compile("^[A-Za-z0-9_.:/@+-]+$");
    private final BucketService bucketService;
    private final ObjectStorageAdapter storageAdapter;
    private final ObjectMetadataRepository objectMetadataRepository;
    private final ObjectVersionRepository objectVersionRepository;
    private final PresignedUploadSessionRepository uploadSessionRepository;
    private final MultipartUploadPartChecksumRepository multipartPartChecksumRepository;

    public ObjectService(
            BucketService bucketService,
            ObjectStorageAdapter storageAdapter,
            ObjectMetadataRepository objectMetadataRepository,
            ObjectVersionRepository objectVersionRepository,
            PresignedUploadSessionRepository uploadSessionRepository
    ) {
        this(
                bucketService,
                storageAdapter,
                objectMetadataRepository,
                objectVersionRepository,
                uploadSessionRepository,
                new InMemoryMultipartUploadPartChecksumRepository()
        );
    }

    @Autowired
    public ObjectService(
            BucketService bucketService,
            ObjectStorageAdapter storageAdapter,
            ObjectMetadataRepository objectMetadataRepository,
            ObjectVersionRepository objectVersionRepository,
            PresignedUploadSessionRepository uploadSessionRepository,
            MultipartUploadPartChecksumRepository multipartPartChecksumRepository
    ) {
        this.bucketService = bucketService;
        this.storageAdapter = storageAdapter;
        this.objectMetadataRepository = objectMetadataRepository;
        this.objectVersionRepository = objectVersionRepository;
        this.uploadSessionRepository = uploadSessionRepository;
        this.multipartPartChecksumRepository = multipartPartChecksumRepository;
    }

    public StoredObjectPage list(
            String bucketName,
            String prefix,
            String delimiter,
            String search,
            String tag,
            String cursor,
            Integer limit,
            AuthenticatedUser user
    ) {
        bucketService.assertCanRead(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedPrefix = normalizeListPrefix(prefix);
        String normalizedDelimiter = normalizeDelimiter(delimiter);
        String normalizedSearch = normalizeSearch(search);
        Map<String, String> normalizedTagFilter = parseTags(tag);
        int normalizedLimit = normalizeLimit(limit);
        return objectMetadataRepository.listObjects(
                normalizedBucketName,
                normalizedPrefix,
                normalizedSearch.isBlank() && normalizedTagFilter.isEmpty() ? normalizedDelimiter : "",
                normalizedSearch,
                normalizedTagFilter,
                normalizeCursor(cursor, normalizedPrefix),
                normalizedLimit
        );
    }

    public StoredObjectPage listDeleted(
            String bucketName,
            String prefix,
            String search,
            String tag,
            String cursor,
            Integer limit,
            AuthenticatedUser user
    ) {
        bucketService.assertCanRead(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedPrefix = normalizeListPrefix(prefix);
        String normalizedSearch = normalizeSearch(search);
        Map<String, String> normalizedTagFilter = parseTags(tag);
        int normalizedLimit = normalizeLimit(limit);
        return objectMetadataRepository.listDeletedObjects(
                normalizedBucketName,
                normalizedPrefix,
                normalizedSearch,
                normalizedTagFilter,
                normalizeCursor(cursor, normalizedPrefix),
                normalizedLimit
        );
    }

    public synchronized StoredObjectRecord upload(
            String bucketName,
            String key,
            String tags,
            InputStream content,
            long sizeBytes,
            String contentType,
            AuthenticatedUser user
    ) {
        return upload(bucketName, key, tags, content, sizeBytes, contentType, user, Map.of());
    }

    public synchronized StoredObjectRecord upload(
            String bucketName,
            String key,
            String tags,
            InputStream content,
            long sizeBytes,
            String contentType,
            AuthenticatedUser user,
            Map<String, String> checksums
    ) {
        return upload(bucketName, key, tags, content, sizeBytes, contentType, user, checksums, Map.of());
    }

    public synchronized StoredObjectRecord upload(
            String bucketName,
            String key,
            String tags,
            InputStream content,
            long sizeBytes,
            String contentType,
            AuthenticatedUser user,
            Map<String, String> checksums,
            Map<String, String> userMetadata
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);

        StoredObjectRecord previous = storageAdapter.statObject(normalizedBucketName, normalizedKey)
                .map(actual -> indexedMetadataOrActual(normalizedBucketName, normalizedKey, actual))
                .orElse(null);
        ObjectVersionRecord snapshot = null;

        bucketService.assertObjectChangeAllowed(normalizedBucketName, sizeBytes, 1L);
        try {
            if (previous != null) {
                snapshot = snapshotActiveObject(normalizedBucketName, normalizedKey, previous);
            }
            StoredObjectRecord storedObject = storageAdapter.putObject(
                    normalizedBucketName,
                    normalizedKey,
                    content,
                    sizeBytes,
                    contentType,
                    parseTags(tags)
            );
            storedObject = storedObject.withChecksums(normalizeChecksums(checksums));
            storedObject = storedObject.withUserMetadata(normalizeUserMetadata(userMetadata));
            bucketService.applyObjectChange(normalizedBucketName, sizeBytes, 1L);
            objectMetadataRepository.save(normalizedBucketName, storedObject);
            return storedObject;
        } catch (RuntimeException exception) {
            rollbackSnapshot(normalizedBucketName, snapshot);
            throw exception;
        }
    }

    public StoredObjectData download(String bucketName, String key, AuthenticatedUser user) {
        bucketService.assertCanRead(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        assertObjectNotDeleted(normalizedBucketName, normalizedKey);
        StoredObjectData object = storageAdapter.getObject(normalizedBucketName, normalizedKey);
        return new StoredObjectData(
                indexedMetadataOrActual(normalizedBucketName, normalizedKey, object.metadata()),
                object.content()
        );
    }

    public StoredObjectStream downloadStream(String bucketName, String key, AuthenticatedUser user) {
        bucketService.assertCanRead(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        assertObjectNotDeleted(normalizedBucketName, normalizedKey);
        StoredObjectStream object = storageAdapter.openObject(normalizedBucketName, normalizedKey);
        return new StoredObjectStream(
                indexedMetadataOrActual(normalizedBucketName, normalizedKey, object.metadata()),
                object.content()
        );
    }

    public StoredObjectStream downloadShared(String bucketName, String key) {
        String normalizedBucketName = bucketService.get(bucketName).name();
        String normalizedKey = normalizeRequiredKey(key);
        assertObjectNotDeleted(normalizedBucketName, normalizedKey);
        StoredObjectStream object = storageAdapter.openObject(normalizedBucketName, normalizedKey);
        return new StoredObjectStream(
                indexedMetadataOrActual(normalizedBucketName, normalizedKey, object.metadata()),
                object.content()
        );
    }

    public StoredObjectStream downloadVersion(String bucketName, String key, String versionId, AuthenticatedUser user) {
        bucketService.assertCanRead(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        String normalizedVersionId = normalizeVersionId(versionId);
        ObjectVersionRecord version = objectVersionRepository.findByVersionId(
                        normalizedBucketName,
                        normalizedKey,
                        normalizedVersionId
                )
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object version not found."));
        StoredObjectStream stream = storageAdapter.openObject(normalizedBucketName, version.storageKey());
        StoredObjectRecord metadata = new StoredObjectRecord(
                version.key(),
                version.sizeBytes(),
                version.contentType(),
                version.objectLastModifiedAt(),
                version.tags(),
                null,
                "",
                Map.of(),
                version.userMetadata()
        );
        return new StoredObjectStream(metadata, stream.content());
    }

    public ObjectMetadataDetail metadata(String bucketName, String key, AuthenticatedUser user) {
        bucketService.assertCanRead(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        StoredObjectRecord indexed = objectMetadataRepository.findByKey(normalizedBucketName, normalizedKey)
                .orElseThrow(() -> new ApiException(
                        ApiErrorCode.NOT_FOUND,
                        "Object metadata not found. Run bucket sync if the object was written through S3."
                ));
        if (indexed.isDeleted()) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Object is deleted.");
        }
        StoredObjectRecord actual = storageAdapter.statObject(normalizedBucketName, normalizedKey).orElse(null);
        return ObjectMetadataDetail.of(indexed, actual, metadataSyncStatus(indexed, actual));
    }

    public Optional<StoredObjectRecord> activeMetadataForWrite(String bucketName, String key, AuthenticatedUser user) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        StoredObjectRecord actual = storageAdapter.statObject(normalizedBucketName, normalizedKey).orElse(null);
        if (actual == null) {
            return Optional.empty();
        }
        StoredObjectRecord indexed = objectMetadataRepository.findByKey(normalizedBucketName, normalizedKey).orElse(null);
        if (indexed != null && indexed.isDeleted()) {
            return Optional.empty();
        }
        return Optional.of(indexedMetadataOrActual(normalizedBucketName, normalizedKey, actual));
    }

    public List<ObjectVersionRecord> listVersions(String bucketName, String key, AuthenticatedUser user) {
        bucketService.assertCanRead(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        objectMetadataRepository.findByKey(normalizedBucketName, normalizedKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object metadata not found."));
        return objectVersionRepository.findByObjectKey(normalizedBucketName, normalizedKey);
    }

    public synchronized StoredObjectRecord restoreVersion(
            String bucketName,
            String key,
            String versionId,
            AuthenticatedUser user
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        String normalizedVersionId = normalizeVersionId(versionId);
        assertObjectNotDeleted(normalizedBucketName, normalizedKey);
        StoredObjectRecord current = storageAdapter.statObject(normalizedBucketName, normalizedKey)
                .map(actual -> indexedMetadataOrActual(normalizedBucketName, normalizedKey, actual))
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object not found."));
        ObjectVersionRecord version = objectVersionRepository.findByVersionId(
                        normalizedBucketName,
                        normalizedKey,
                        normalizedVersionId
                )
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object version not found."));

        bucketService.assertObjectChangeAllowed(normalizedBucketName, version.sizeBytes(), 1L);
        ObjectVersionRecord snapshot = null;
        try {
            snapshot = snapshotActiveObject(normalizedBucketName, normalizedKey, current);
            StoredObjectRecord restored = restoreVersionContent(normalizedBucketName, normalizedKey, version);
            bucketService.applyObjectChange(normalizedBucketName, version.sizeBytes(), 1L);
            objectMetadataRepository.save(normalizedBucketName, restored);
            return restored;
        } catch (RuntimeException exception) {
            rollbackSnapshot(normalizedBucketName, snapshot);
            throw exception;
        }
    }

    public synchronized void deleteVersion(String bucketName, String key, String versionId, AuthenticatedUser user) {
        bucketService.assertCanDeleteObject(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        String normalizedVersionId = normalizeVersionId(versionId);
        ObjectVersionRecord version = objectVersionRepository.findByVersionId(
                        normalizedBucketName,
                        normalizedKey,
                        normalizedVersionId
                )
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object version not found."));
        deleteVersionStorage(normalizedBucketName, version);
        objectVersionRepository.delete(normalizedBucketName, normalizedKey, normalizedVersionId);
        bucketService.applyObjectChange(normalizedBucketName, -version.sizeBytes(), -1L);
    }

    public synchronized StoredObjectRecord delete(String bucketName, String key, AuthenticatedUser user) {
        bucketService.assertCanDeleteObject(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        StoredObjectRecord indexed = objectMetadataRepository.findByKey(normalizedBucketName, normalizedKey).orElse(null);
        if (indexed != null && indexed.isDeleted()) {
            return indexed;
        }
        StoredObjectRecord current = indexed == null
                ? storageAdapter.statObject(normalizedBucketName, normalizedKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object not found."))
                : indexed;
        StoredObjectRecord deleted = current.withDeletedAt(OffsetDateTime.now());
        objectMetadataRepository.save(normalizedBucketName, deleted);
        return deleted;
    }

    public synchronized StoredObjectRecord restore(String bucketName, String key, AuthenticatedUser user) {
        bucketService.assertCanDeleteObject(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        StoredObjectRecord indexed = objectMetadataRepository.findByKey(normalizedBucketName, normalizedKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Deleted object not found."));
        if (!indexed.isDeleted()) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Object is not deleted.");
        }
        if (storageAdapter.statObject(normalizedBucketName, normalizedKey).isEmpty()) {
            objectMetadataRepository.delete(normalizedBucketName, normalizedKey);
            bucketService.applyObjectChange(normalizedBucketName, -indexed.sizeBytes(), -1L);
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Deleted object is missing in storage.");
        }
        StoredObjectRecord restored = indexed.withDeletedAt(null);
        objectMetadataRepository.save(normalizedBucketName, restored);
        return restored;
    }

    public synchronized void purge(String bucketName, String key, AuthenticatedUser user) {
        bucketService.assertCanDeleteObject(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        StoredObjectRecord indexed = objectMetadataRepository.findByKey(normalizedBucketName, normalizedKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Deleted object not found."));
        if (!indexed.isDeleted()) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Object must be deleted before purge.");
        }
        long purgedSizeBytes = indexed.sizeBytes();
        long purgedObjectCount = 1L;
        try {
            StoredObjectRecord removed = storageAdapter.deleteObject(normalizedBucketName, normalizedKey);
            purgedSizeBytes = removed.sizeBytes();
        } catch (ApiException exception) {
            if (exception.code() != ApiErrorCode.NOT_FOUND) {
                throw exception;
            }
        }
        List<ObjectVersionRecord> versions = objectVersionRepository.findByObjectKey(normalizedBucketName, normalizedKey);
        for (ObjectVersionRecord version : versions) {
            deleteVersionStorage(normalizedBucketName, version);
            purgedSizeBytes += version.sizeBytes();
            purgedObjectCount++;
        }
        objectVersionRepository.deleteByObjectKey(normalizedBucketName, normalizedKey);
        objectMetadataRepository.delete(normalizedBucketName, normalizedKey);
        bucketService.applyObjectChange(normalizedBucketName, -purgedSizeBytes, -purgedObjectCount);
    }

    public synchronized StoredObjectRecord updateTags(
            String bucketName,
            String key,
            String tags,
            AuthenticatedUser user
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        assertObjectNotDeleted(normalizedBucketName, normalizedKey);
        StoredObjectRecord indexed = objectMetadataRepository.findByKey(normalizedBucketName, normalizedKey).orElse(null);
        StoredObjectRecord updatedObject = storageAdapter.setObjectTags(normalizedBucketName, normalizedKey, parseTags(tags));
        if (indexed != null) {
            updatedObject = updatedObject.withChecksums(indexed.checksums());
            updatedObject = updatedObject.withUserMetadata(indexed.userMetadata());
        }
        objectMetadataRepository.save(normalizedBucketName, updatedObject);
        return updatedObject;
    }

    public PresignedObjectUrl createPresignedUploadUrl(
            String bucketName,
            PresignedObjectUrlRequest request,
            AuthenticatedUser user
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(request.key());
        StoredObjectRecord previous = storageAdapter.statObject(normalizedBucketName, normalizedKey).orElse(null);
        String tags = normalizeTags(request.tags());

        int expiresInSeconds = expiresInSeconds(request.expiresInSeconds());
        OffsetDateTime now = OffsetDateTime.now();
        String uploadId = UUID.randomUUID().toString();
        String storageKey = uploadStagingKey(uploadId, normalizedKey);
        uploadSessionRepository.save(new PresignedUploadSession(
                uploadId,
                user.id(),
                normalizedBucketName,
                normalizedKey,
                tags,
                UPLOAD_MODE_PRESIGNED_PUT,
                storageKey,
                0L,
                0L,
                0,
                "ACTIVE",
                previous == null ? 0L : previous.sizeBytes(),
                previous != null,
                now.plusSeconds(expiresInSeconds),
                now,
                null
        ));

        try {
            PresignedObjectUrl url = storageAdapter.createPresignedPutUrl(
                    normalizedBucketName,
                    storageKey,
                    request.contentType(),
                    expiresInSeconds
            );
            return new PresignedObjectUrl(url.url(), url.method(), url.expiresInSeconds(), uploadId);
        } catch (RuntimeException exception) {
            uploadSessionRepository.updateStatus(uploadId, "FAILED", OffsetDateTime.now());
            throw exception;
        }
    }

    public MultipartUploadCreateResponse createMultipartUpload(
            String bucketName,
            MultipartUploadCreateRequest request,
            AuthenticatedUser user
    ) {
        return createMultipartUpload(bucketName, request, user, true);
    }

    public MultipartUploadCreateResponse createS3MultipartUpload(
            String bucketName,
            MultipartUploadCreateRequest request,
            AuthenticatedUser user
    ) {
        return createMultipartUpload(bucketName, request, user, false);
    }

    private MultipartUploadCreateResponse createMultipartUpload(
            String bucketName,
            MultipartUploadCreateRequest request,
            AuthenticatedUser user,
            boolean requireExpectedSize
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(request.key());
        boolean hasExpectedSize = request.sizeBytes() != null;
        if (request.sizeBytes() != null && request.sizeBytes() <= 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "sizeBytes must be positive.");
        }
        if (requireExpectedSize && !hasExpectedSize) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "sizeBytes must be positive.");
        }
        if (!hasExpectedSize && request.partSizeBytes() != null && request.partSizeBytes() <= 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "partSizeBytes must be positive.");
        }
        long sizeBytes = hasExpectedSize ? normalizeMultipartSize(request.sizeBytes()) : 0L;
        long partSizeBytes = hasExpectedSize ? normalizeMultipartPartSize(request.partSizeBytes(), sizeBytes) : 0L;
        int partCount = hasExpectedSize ? multipartPartCount(sizeBytes, partSizeBytes) : 0;
        StoredObjectRecord previous = storageAdapter.statObject(normalizedBucketName, normalizedKey).orElse(null);
        String tags = normalizeTags(request.tags());
        String checksumAlgorithm = normalizeChecksumNegotiation(request.checksumAlgorithm());
        String checksumType = normalizeChecksumNegotiation(request.checksumType());
        validateMultipartChecksumNegotiationRequest(checksumAlgorithm, checksumType);

        if (hasExpectedSize) {
            bucketService.assertObjectChangeAllowed(normalizedBucketName, sizeBytes, 1L);
        }
        int expiresInSeconds = expiresInSeconds(request.expiresInSeconds());
        List<Integer> partNumbers = partNumbers(partCount);
        StorageMultipartUpload storageUpload = storageAdapter.createMultipartUpload(
                normalizedBucketName,
                normalizedKey,
                request.contentType(),
                expiresInSeconds,
                partNumbers
        );

        String uploadId = UUID.randomUUID().toString();
        OffsetDateTime now = OffsetDateTime.now();
        OffsetDateTime expiresAt = now.plusSeconds(expiresInSeconds);
        try {
            uploadSessionRepository.save(new PresignedUploadSession(
                    uploadId,
                    user.id(),
                    normalizedBucketName,
                    normalizedKey,
                    tags,
                    UPLOAD_MODE_MULTIPART,
                    storageUpload.storageUploadId(),
                    checksumAlgorithm,
                    checksumType,
                    sizeBytes,
                    partSizeBytes,
                    partCount,
                    "ACTIVE",
                    previous == null ? 0L : previous.sizeBytes(),
                    previous != null,
                    expiresAt,
                    now,
                    null
            ));
        } catch (RuntimeException exception) {
            storageAdapter.abortMultipartUpload(normalizedBucketName, normalizedKey, storageUpload.storageUploadId());
            throw exception;
        }

        return new MultipartUploadCreateResponse(
                uploadId,
                normalizedKey,
                sizeBytes,
                partSizeBytes,
                partCount,
                expiresInSeconds,
                expiresAt,
                withByteRanges(storageUpload.parts(), sizeBytes, partSizeBytes)
        );
    }

    public MultipartUploadCreateResponse refreshMultipartUpload(
            String bucketName,
            MultipartUploadRefreshRequest request,
            AuthenticatedUser user
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(request.key());
        PresignedUploadSession session = uploadSessionRepository.findByUploadId(request.uploadId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Upload session not found."));
        validateUploadSession(session, user, normalizedBucketName, normalizedKey);
        validateUploadMode(session, UPLOAD_MODE_MULTIPART);
        if (session.expectedSizeBytes() <= 0 || session.partSizeBytes() <= 0 || session.partCount() <= 0) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Multipart upload session part plan is missing.");
        }

        int expiresInSeconds = expiresInSeconds(request.expiresInSeconds());
        StorageMultipartUpload storageUpload = storageAdapter.refreshMultipartUploadParts(
                normalizedBucketName,
                normalizedKey,
                session.storageUploadId(),
                expiresInSeconds,
                partNumbers(session.partCount())
        );
        return new MultipartUploadCreateResponse(
                session.uploadId(),
                normalizedKey,
                session.expectedSizeBytes(),
                session.partSizeBytes(),
                session.partCount(),
                expiresInSeconds,
                session.expiresAt(),
                withByteRanges(storageUpload.parts(), session.expectedSizeBytes(), session.partSizeBytes())
        );
    }

    public MultipartUploadPartsResponse listMultipartUploadParts(
            String bucketName,
            MultipartUploadPartsRequest request,
            AuthenticatedUser user
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(request.key());
        PresignedUploadSession session = uploadSessionRepository.findByUploadId(request.uploadId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Upload session not found."));
        validateUploadSession(session, user, normalizedBucketName, normalizedKey);
        validateUploadMode(session, UPLOAD_MODE_MULTIPART);
        List<MultipartUploadUploadedPart> uploadedParts = storageAdapter.listMultipartUploadParts(
                normalizedBucketName,
                normalizedKey,
                session.storageUploadId()
        );
        Map<Integer, Map<String, String>> partChecksums =
                multipartPartChecksumRepository.findByUploadId(session.uploadId());
        List<MultipartUploadUploadedPart> uploadedPartsWithChecksums = uploadedParts.stream()
                .map(part -> part.withChecksums(partChecksums.getOrDefault(part.partNumber(), Map.of())))
                .toList();
        return new MultipartUploadPartsResponse(
                session.uploadId(),
                normalizedKey,
                session.expectedSizeBytes(),
                session.partSizeBytes(),
                session.partCount(),
                uploadedPartsWithChecksums
        );
    }

    public String multipartUploadPartChecksumHeader(
            String bucketName,
            String key,
            String uploadId,
            AuthenticatedUser user
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        PresignedUploadSession session = uploadSessionRepository.findByUploadId(uploadId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Upload session not found."));
        validateUploadSession(session, user, normalizedBucketName, normalizedKey);
        validateUploadMode(session, UPLOAD_MODE_MULTIPART);
        return checksumHeaderName(session.checksumAlgorithm());
    }

    public MultipartUploadUploadedPart uploadMultipartPart(
            String bucketName,
            String key,
            String uploadId,
            int partNumber,
            InputStream content,
            long sizeBytes,
            AuthenticatedUser user
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        PresignedUploadSession session = uploadSessionRepository.findByUploadId(uploadId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Upload session not found."));
        validateUploadSession(session, user, normalizedBucketName, normalizedKey);
        validateUploadMode(session, UPLOAD_MODE_MULTIPART);
        if (partNumber < 1 || partNumber > MAX_MULTIPART_PART_COUNT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "partNumber is outside the upload part plan.");
        }
        if (session.partCount() > 0 && partNumber > session.partCount()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "partNumber is outside the upload part plan.");
        }
        if (sizeBytes <= 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Content-Length is required for multipart part upload.");
        }
        return storageAdapter.uploadMultipartUploadPart(
                normalizedBucketName,
                normalizedKey,
                session.storageUploadId(),
                partNumber,
                content,
                sizeBytes
        );
    }

    public void recordMultipartUploadPartChecksums(
            String bucketName,
            String key,
            String uploadId,
            int partNumber,
            Map<String, String> checksums,
            AuthenticatedUser user
    ) {
        Map<String, String> normalizedChecksums = normalizeChecksums(checksums);
        if (normalizedChecksums.isEmpty()) {
            return;
        }
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(key);
        PresignedUploadSession session = uploadSessionRepository.findByUploadId(uploadId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Upload session not found."));
        validateUploadSession(session, user, normalizedBucketName, normalizedKey);
        validateUploadMode(session, UPLOAD_MODE_MULTIPART);
        if (partNumber < 1 || partNumber > MAX_MULTIPART_PART_COUNT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "partNumber is outside the upload part plan.");
        }
        if (session.partCount() > 0 && partNumber > session.partCount()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "partNumber is outside the upload part plan.");
        }
        validateChecksumMetadata(normalizedChecksums);
        validateChecksumAlgorithmMatchesInitiate(
                normalizeChecksumNegotiation(session.checksumAlgorithm()),
                normalizedChecksums.keySet().iterator().next()
        );
        multipartPartChecksumRepository.save(session.uploadId(), partNumber, normalizedChecksums);
    }

    public MultipartUploadListResponse listActiveMultipartUploads(
            String bucketName,
            String prefix,
            String keyMarker,
            String uploadIdMarker,
            int maxUploads,
            AuthenticatedUser user
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        int normalizedMaxUploads = Math.max(1, Math.min(maxUploads, 1000));
        List<PresignedUploadSession> sessions = uploadSessionRepository.findActiveMultipartUploads(
                normalizedBucketName,
                prefix == null ? "" : prefix,
                keyMarker == null ? "" : keyMarker,
                uploadIdMarker == null ? "" : uploadIdMarker,
                normalizedMaxUploads + 1
        );
        boolean truncated = sessions.size() > normalizedMaxUploads;
        List<PresignedUploadSession> page = truncated ? sessions.subList(0, normalizedMaxUploads) : sessions;
        String nextKeyMarker = truncated ? page.get(page.size() - 1).objectKey() : "";
        String nextUploadIdMarker = truncated ? page.get(page.size() - 1).uploadId() : "";
        return new MultipartUploadListResponse(
                normalizedBucketName,
                prefix == null ? "" : prefix,
                keyMarker == null ? "" : keyMarker,
                uploadIdMarker == null ? "" : uploadIdMarker,
                normalizedMaxUploads,
                truncated,
                nextKeyMarker,
                nextUploadIdMarker,
                page.stream()
                        .map(session -> new MultipartUploadListItem(
                                session.objectKey(),
                                session.uploadId(),
                                session.createdAt()
                        ))
                        .toList()
        );
    }

    public PresignedObjectUrl createPresignedDownloadUrl(
            String bucketName,
            PresignedObjectUrlRequest request,
            AuthenticatedUser user
    ) {
        bucketService.assertCanRead(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(request.key());
        assertObjectNotDeleted(normalizedBucketName, normalizedKey);
        return storageAdapter.createPresignedGetUrl(
                normalizedBucketName,
                normalizedKey,
                expiresInSeconds(request.expiresInSeconds())
        );
    }

    public synchronized StoredObjectRecord completePresignedUpload(
            String bucketName,
            PresignedUploadCompleteRequest request,
            AuthenticatedUser user
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(request.key());
        PresignedUploadSession session = uploadSessionRepository.findByUploadId(request.uploadId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Upload session not found."));
        validateUploadSession(session, user, normalizedBucketName, normalizedKey);
        validateUploadMode(session, UPLOAD_MODE_PRESIGNED_PUT);

        String storageKey = requireUploadStorageKey(session);
        StoredObjectRecord stagedObject = storageAdapter.statObject(normalizedBucketName, storageKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Uploaded object not found."));

        try {
            bucketService.assertObjectChangeAllowed(normalizedBucketName, stagedObject.sizeBytes(), 1L);
        } catch (ApiException exception) {
            deleteUploadStagingStorage(normalizedBucketName, storageKey);
            uploadSessionRepository.updateStatus(session.uploadId(), "FAILED", OffsetDateTime.now());
            throw exception;
        }

        Map<String, String> tags = parseTags(session.tags());
        ObjectVersionRecord snapshot = null;
        try {
            if (session.previousExists()) {
                StoredObjectRecord current = storageAdapter.statObject(normalizedBucketName, normalizedKey)
                        .map(actual -> indexedMetadataOrActual(normalizedBucketName, normalizedKey, actual))
                        .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Previous object not found."));
                snapshot = snapshotActiveObject(normalizedBucketName, normalizedKey, current);
            }
            StoredObjectRecord uploadedObject = putStagedUploadAsActive(
                    normalizedBucketName,
                    normalizedKey,
                    storageKey,
                    stagedObject,
                    tags
            );
            bucketService.applyObjectChange(normalizedBucketName, uploadedObject.sizeBytes(), 1L);
            objectMetadataRepository.save(normalizedBucketName, uploadedObject);
            uploadSessionRepository.updateStatus(session.uploadId(), "COMPLETED", OffsetDateTime.now());
            return uploadedObject;
        } catch (RuntimeException exception) {
            rollbackSnapshot(normalizedBucketName, snapshot);
            throw exception;
        }
    }

    public synchronized StoredObjectRecord completeMultipartUpload(
            String bucketName,
            MultipartUploadCompleteRequest request,
            AuthenticatedUser user
    ) {
        return completeMultipartUpload(bucketName, request, user, Map.of());
    }

    public synchronized StoredObjectRecord completeMultipartUpload(
            String bucketName,
            MultipartUploadCompleteRequest request,
            AuthenticatedUser user,
            Map<String, String> checksums
    ) {
        return completeMultipartUpload(bucketName, request, user, checksums, null);
    }

    public synchronized StoredObjectRecord completeMultipartUpload(
            String bucketName,
            MultipartUploadCompleteRequest request,
            AuthenticatedUser user,
            Map<String, String> checksums,
            Long expectedObjectSize
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(request.key());
        PresignedUploadSession session = uploadSessionRepository.findByUploadId(request.uploadId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Upload session not found."));
        validateUploadSession(session, user, normalizedBucketName, normalizedKey);
        validateUploadMode(session, UPLOAD_MODE_MULTIPART);
        List<CompletedMultipartUploadPart> completedParts =
                withStoredMultipartPartChecksums(session.uploadId(), normalizeCompletedParts(request.parts()));
        Map<String, String> requestedChecksums = normalizeChecksums(checksums);
        validateChecksumMetadata(requestedChecksums);
        validateMultipartChecksumNegotiation(session, requestedChecksums, completedParts);
        Map<String, String> metadataChecksums = requestedChecksums.isEmpty()
                ? compositeMultipartChecksums(completedParts)
                : requestedChecksums;
        validateCompletedPartsMatchUploaded(
                normalizedBucketName,
                normalizedKey,
                session.storageUploadId(),
                completedParts
        );

        if (session.expectedSizeBytes() > 0) {
            try {
                bucketService.assertObjectChangeAllowed(normalizedBucketName, session.expectedSizeBytes(), 1L);
            } catch (ApiException exception) {
                storageAdapter.abortMultipartUpload(normalizedBucketName, normalizedKey, session.storageUploadId());
                uploadSessionRepository.updateStatus(session.uploadId(), "FAILED", OffsetDateTime.now());
                throw exception;
            }
        }

        ObjectVersionRecord snapshot = null;
        try {
            if (session.previousExists()) {
                StoredObjectRecord current = storageAdapter.statObject(normalizedBucketName, normalizedKey)
                        .map(actual -> indexedMetadataOrActual(normalizedBucketName, normalizedKey, actual))
                        .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Previous object not found."));
                snapshot = snapshotActiveObject(normalizedBucketName, normalizedKey, current);
            }
            StoredObjectRecord uploadedObject = storageAdapter.completeMultipartUpload(
                    normalizedBucketName,
                    normalizedKey,
                    session.storageUploadId(),
                    completedParts
            );
            Map<String, String> tags = parseTags(session.tags());
            if (!tags.isEmpty()) {
                uploadedObject = storageAdapter.setObjectTags(normalizedBucketName, normalizedKey, tags);
            }
            try {
                validateMultipartObjectSize(uploadedObject, expectedObjectSize);
                validateStoredObjectChecksums(normalizedBucketName, normalizedKey, requestedChecksums);
                bucketService.assertObjectChangeAllowed(normalizedBucketName, uploadedObject.sizeBytes(), 1L);
            } catch (RuntimeException exception) {
                rollbackCompletedMultipartObject(normalizedBucketName, normalizedKey, snapshot);
                uploadSessionRepository.updateStatus(session.uploadId(), "FAILED", OffsetDateTime.now());
                throw exception;
            }
            uploadedObject = uploadedObject.withChecksums(metadataChecksums);
            bucketService.applyObjectChange(normalizedBucketName, uploadedObject.sizeBytes(), 1L);
            objectMetadataRepository.save(normalizedBucketName, uploadedObject);
            uploadSessionRepository.updateStatus(session.uploadId(), "COMPLETED", OffsetDateTime.now());
            deleteMultipartPartChecksums(session.uploadId());
            return uploadedObject;
        } catch (RuntimeException exception) {
            rollbackSnapshot(normalizedBucketName, snapshot);
            throw exception;
        }
    }

    private void rollbackCompletedMultipartObject(String bucketName, String objectKey, ObjectVersionRecord snapshot) {
        try {
            if (snapshot == null) {
                storageAdapter.deleteObject(bucketName, objectKey);
                return;
            }
            restoreVersionContent(bucketName, objectKey, snapshot);
        } catch (RuntimeException ignored) {
            // Best effort cleanup. Original checksum error must stay visible to caller.
        }
    }

    public synchronized void abortMultipartUpload(
            String bucketName,
            MultipartUploadAbortRequest request,
            AuthenticatedUser user
    ) {
        bucketService.assertCanWrite(bucketName, user);
        String normalizedBucketName = bucketService.get(bucketName, user).name();
        String normalizedKey = normalizeRequiredKey(request.key());
        PresignedUploadSession session = uploadSessionRepository.findByUploadId(request.uploadId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Upload session not found."));
        validateUploadSession(session, user, normalizedBucketName, normalizedKey);
        validateUploadMode(session, UPLOAD_MODE_MULTIPART);
        storageAdapter.abortMultipartUpload(normalizedBucketName, normalizedKey, session.storageUploadId());
        uploadSessionRepository.updateStatus(session.uploadId(), "ABORTED", OffsetDateTime.now());
        deleteMultipartPartChecksums(session.uploadId());
    }

    private String normalizeKey(String key) {
        if (key == null) {
            return "";
        }
        return key.startsWith("/") ? key.substring(1) : key.trim();
    }

    private String normalizeRequiredKey(String key) {
        String normalizedKey = normalizeKey(key);
        if (normalizedKey.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Object key is required.");
        }
        if (ObjectVersionStorageKeys.isInternalStorageKey(normalizedKey)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Object key prefix is reserved.");
        }
        return normalizedKey;
    }

    private String normalizeVersionId(String versionId) {
        String normalizedVersionId = versionId == null ? "" : versionId.trim();
        if (normalizedVersionId.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "versionId is required.");
        }
        return normalizedVersionId;
    }

    private String normalizeListPrefix(String prefix) {
        return prefix == null ? "" : prefix.trim();
    }

    private String normalizeDelimiter(String delimiter) {
        if (delimiter == null || delimiter.isBlank()) {
            return "";
        }
        if (!"/".equals(delimiter)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "delimiter must be '/'.");
        }
        return delimiter;
    }

    private String normalizeSearch(String search) {
        return search == null ? "" : search.trim();
    }

    private String normalizeTags(String tags) {
        if (tags == null || tags.isBlank()) {
            return "";
        }
        parseTags(tags);
        return tags.trim();
    }

    private Map<String, String> parseTags(String tags) {
        if (tags == null || tags.isBlank()) {
            return Map.of();
        }
        Map<String, String> parsedTags = new LinkedHashMap<>();
        for (String rawPair : tags.split(",")) {
            String pair = rawPair.trim();
            if (pair.isBlank()) {
                continue;
            }
            int separatorIndex = pair.indexOf('=');
            if (separatorIndex <= 0 || separatorIndex == pair.length() - 1) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tags must use key=value pairs.");
            }
            String key = pair.substring(0, separatorIndex).trim();
            String value = pair.substring(separatorIndex + 1).trim();
            if (key.isBlank() || value.isBlank()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tags must use key=value pairs.");
            }
            validateTagKey(key);
            validateTagValue(value);
            parsedTags.put(key, value);
        }
        if (parsedTags.size() > MAX_TAG_COUNT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tags can contain at most 10 pairs.");
        }
        return Map.copyOf(parsedTags);
    }

    private Map<String, String> normalizeChecksums(Map<String, String> checksums) {
        if (checksums == null || checksums.isEmpty()) {
            return Map.of();
        }
        Map<String, String> normalizedChecksums = new LinkedHashMap<>();
        for (Map.Entry<String, String> entry : checksums.entrySet()) {
            if (entry.getKey() == null || entry.getValue() == null || entry.getValue().isBlank()) {
                continue;
            }
            normalizedChecksums.put(entry.getKey().trim().toLowerCase(java.util.Locale.ROOT), entry.getValue().trim());
        }
        return Map.copyOf(normalizedChecksums);
    }

    private Map<String, String> normalizeUserMetadata(Map<String, String> userMetadata) {
        if (userMetadata == null || userMetadata.isEmpty()) {
            return Map.of();
        }
        Map<String, String> normalizedMetadata = new LinkedHashMap<>();
        for (Map.Entry<String, String> entry : userMetadata.entrySet()) {
            if (entry.getKey() == null || entry.getKey().isBlank()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "x-amz-meta-* metadata name is required.");
            }
            normalizedMetadata.put(
                    entry.getKey().trim().toLowerCase(java.util.Locale.ROOT),
                    entry.getValue() == null ? "" : entry.getValue()
            );
        }
        return Map.copyOf(normalizedMetadata);
    }

    private void validateChecksumMetadata(Map<String, String> checksums) {
        if (checksums.isEmpty()) {
            return;
        }
        if (checksums.size() > 1) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, "Only one x-amz-checksum-* header is supported.");
        }
        Map.Entry<String, String> checksum = checksums.entrySet().iterator().next();
        decodeChecksum(checksum.getKey(), checksum.getValue(), expectedChecksumLength(checksum.getKey()));
    }

    private void validateStoredObjectChecksums(String bucketName, String objectKey, Map<String, String> checksums) {
        if (checksums.isEmpty()) {
            return;
        }
        Map.Entry<String, String> checksum = checksums.entrySet().iterator().next();
        byte[] expected = decodeChecksum(checksum.getKey(), checksum.getValue(), expectedChecksumLength(checksum.getKey()));
        byte[] actual;
        try (InputStream content = storageAdapter.openObject(bucketName, objectKey).content()) {
            actual = objectChecksum(checksum.getKey(), content);
        } catch (IOException exception) {
            throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Completed multipart checksum validation failed: " + exception.getMessage());
        }
        if (!MessageDigest.isEqual(expected, actual)) {
            throw new ApiException(ApiErrorCode.BAD_DIGEST, checksum.getKey() + " does not match completed multipart object body.");
        }
    }

    private String normalizeChecksumNegotiation(String value) {
        return value == null ? "" : value.trim().toUpperCase(java.util.Locale.ROOT);
    }

    private void validateMultipartChecksumNegotiationRequest(String checksumAlgorithm, String checksumType) {
        if (!checksumAlgorithm.isBlank()
                && !"SHA256".equals(checksumAlgorithm)
                && !"SHA1".equals(checksumAlgorithm)
                && !"CRC32".equals(checksumAlgorithm)
                && !"CRC32C".equals(checksumAlgorithm)
                && !"CRC64NVME".equals(checksumAlgorithm)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "checksumAlgorithm is not supported.");
        }
        if (!checksumType.isBlank()
                && !"COMPOSITE".equals(checksumType)
                && !"FULL_OBJECT".equals(checksumType)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "checksumType must be COMPOSITE or FULL_OBJECT.");
        }
        if ("COMPOSITE".equals(checksumType) && "CRC64NVME".equals(checksumAlgorithm)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "checksumType COMPOSITE is not supported for CRC64NVME.");
        }
        if ("FULL_OBJECT".equals(checksumType)
                && ("SHA1".equals(checksumAlgorithm) || "SHA256".equals(checksumAlgorithm))) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "checksumType FULL_OBJECT requires a CRC checksum algorithm.");
        }
    }

    private void validateMultipartChecksumNegotiation(
            PresignedUploadSession session,
            Map<String, String> requestedChecksums,
            List<CompletedMultipartUploadPart> completedParts
    ) {
        String checksumAlgorithm = normalizeChecksumNegotiation(session.checksumAlgorithm());
        String checksumType = normalizeChecksumNegotiation(session.checksumType());
        if (checksumAlgorithm.isBlank() && checksumType.isBlank()) {
            return;
        }
        if ("FULL_OBJECT".equals(checksumType)) {
            if (requestedChecksums.isEmpty()) {
                throw new ApiException(ApiErrorCode.BAD_DIGEST, "Complete multipart upload must include the initiated full-object checksum.");
            }
            validateChecksumAlgorithmMatchesInitiate(
                    checksumAlgorithm,
                    requestedChecksums.keySet().iterator().next()
            );
            return;
        }
        if ("COMPOSITE".equals(checksumType)) {
            if (!requestedChecksums.isEmpty()) {
                throw new ApiException(ApiErrorCode.BAD_DIGEST, "Complete multipart upload checksum type does not match initiated checksum type.");
            }
            validateCompositeChecksumMatchesInitiate(checksumAlgorithm, completedParts, true);
            return;
        }
        if (!requestedChecksums.isEmpty()) {
            validateChecksumAlgorithmMatchesInitiate(
                    checksumAlgorithm,
                    requestedChecksums.keySet().iterator().next()
            );
        }
        validateCompositeChecksumMatchesInitiate(checksumAlgorithm, completedParts, false);
    }

    private void validateCompositeChecksumMatchesInitiate(
            String checksumAlgorithm,
            List<CompletedMultipartUploadPart> completedParts,
            boolean required
    ) {
        String headerName = null;
        boolean hasChecksum = false;
        boolean requireEveryPart = required || completedParts.stream().anyMatch(part -> !part.checksums().isEmpty());
        for (CompletedMultipartUploadPart part : completedParts) {
            if (part.checksums().isEmpty()) {
                if (requireEveryPart) {
                    throw new ApiException(ApiErrorCode.BAD_DIGEST, "Complete multipart upload must include per-part checksums.");
                }
                continue;
            }
            hasChecksum = true;
            if (part.checksums().size() != 1) {
                throw new ApiException(ApiErrorCode.BAD_DIGEST, "Complete multipart upload part checksum count does not match initiated checksum.");
            }
            String partHeaderName = part.checksums().keySet().iterator().next();
            if (compositeChecksumAccumulator(partHeaderName) == null) {
                throw new ApiException(ApiErrorCode.BAD_DIGEST, "Complete multipart upload checksum algorithm does not support composite checksums.");
            }
            validateChecksumAlgorithmMatchesInitiate(checksumAlgorithm, partHeaderName);
            if (headerName == null) {
                headerName = partHeaderName;
            } else if (!headerName.equals(partHeaderName)) {
                throw new ApiException(ApiErrorCode.BAD_DIGEST, "Complete multipart upload part checksum algorithm must be consistent.");
            }
        }
        if (required && !hasChecksum) {
            throw new ApiException(ApiErrorCode.BAD_DIGEST, "Complete multipart upload must include per-part checksums.");
        }
    }

    private void validateChecksumAlgorithmMatchesInitiate(String checksumAlgorithm, String headerName) {
        if (checksumAlgorithm.isBlank()) {
            return;
        }
        if (!checksumAlgorithm.equals(checksumAlgorithm(headerName))) {
            throw new ApiException(ApiErrorCode.BAD_DIGEST, "Complete multipart upload checksum algorithm does not match initiated checksum algorithm.");
        }
    }

    private String checksumHeaderName(String checksumAlgorithm) {
        return switch (normalizeChecksumNegotiation(checksumAlgorithm)) {
            case "SHA256" -> AWS_CHECKSUM_SHA256_HEADER;
            case "SHA1" -> AWS_CHECKSUM_SHA1_HEADER;
            case "CRC32" -> AWS_CHECKSUM_CRC32_HEADER;
            case "CRC32C" -> AWS_CHECKSUM_CRC32C_HEADER;
            case "CRC64NVME" -> AWS_CHECKSUM_CRC64NVME_HEADER;
            default -> "";
        };
    }

    private String checksumAlgorithm(String headerName) {
        return switch (headerName == null ? "" : headerName.toLowerCase(java.util.Locale.ROOT)) {
            case AWS_CHECKSUM_SHA256_HEADER -> "SHA256";
            case AWS_CHECKSUM_SHA1_HEADER -> "SHA1";
            case AWS_CHECKSUM_CRC32_HEADER -> "CRC32";
            case AWS_CHECKSUM_CRC32C_HEADER -> "CRC32C";
            case AWS_CHECKSUM_CRC64NVME_HEADER -> "CRC64NVME";
            default -> "";
        };
    }

    private void validateMultipartObjectSize(StoredObjectRecord uploadedObject, Long expectedObjectSize) {
        if (expectedObjectSize == null) {
            return;
        }
        if (expectedObjectSize <= 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "x-amz-mp-object-size must be positive.");
        }
        if (uploadedObject.sizeBytes() != expectedObjectSize) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "x-amz-mp-object-size does not match completed object size.");
        }
    }

    private Map<String, String> compositeMultipartChecksums(List<CompletedMultipartUploadPart> completedParts) {
        String headerName = null;
        CompositeChecksumAccumulator accumulator = null;
        for (CompletedMultipartUploadPart part : completedParts) {
            if (part.checksums().size() != 1) {
                return Map.of();
            }
            Map.Entry<String, String> checksum = part.checksums().entrySet().iterator().next();
            if (headerName == null) {
                headerName = checksum.getKey();
                accumulator = compositeChecksumAccumulator(headerName);
                if (accumulator == null) {
                    return Map.of();
                }
            } else if (!headerName.equals(checksum.getKey())) {
                return Map.of();
            }
            accumulator.update(decodeChecksum(headerName, checksum.getValue(), expectedChecksumLength(headerName)));
        }
        if (headerName == null || accumulator == null) {
            return Map.of();
        }
        return Map.of(headerName, Base64.getEncoder().encodeToString(accumulator.digest()));
    }

    private CompositeChecksumAccumulator compositeChecksumAccumulator(String headerName) {
        return switch (headerName) {
            case AWS_CHECKSUM_SHA256_HEADER -> digestAccumulator("SHA-256");
            case AWS_CHECKSUM_SHA1_HEADER -> digestAccumulator("SHA-1");
            case AWS_CHECKSUM_CRC32_HEADER -> crcAccumulator(new CRC32());
            case AWS_CHECKSUM_CRC32C_HEADER -> crcAccumulator(new CRC32C());
            default -> null;
        };
    }

    private CompositeChecksumAccumulator digestAccumulator(String algorithm) {
        MessageDigest digest = messageDigest(algorithm);
        return new CompositeChecksumAccumulator() {
            @Override
            public void update(byte[] value) {
                digest.update(value);
            }

            @Override
            public byte[] digest() {
                return digest.digest();
            }
        };
    }

    private CompositeChecksumAccumulator crcAccumulator(Checksum checksum) {
        return new CompositeChecksumAccumulator() {
            @Override
            public void update(byte[] value) {
                checksum.update(value, 0, value.length);
            }

            @Override
            public byte[] digest() {
                return intDigest(checksum.getValue());
            }
        };
    }

    private byte[] objectChecksum(String headerName, InputStream content) throws IOException {
        return switch (headerName) {
            case AWS_CHECKSUM_SHA256_HEADER -> digestObject("SHA-256", content);
            case AWS_CHECKSUM_SHA1_HEADER -> digestObject("SHA-1", content);
            case AWS_CHECKSUM_CRC32_HEADER -> crcObject(new CRC32(), content);
            case AWS_CHECKSUM_CRC32C_HEADER -> crcObject(new CRC32C(), content);
            case AWS_CHECKSUM_CRC64NVME_HEADER -> crcObject(
                    new Crc64NvmeChecksum(),
                    Crc64NvmeChecksum.DIGEST_LENGTH_BYTES,
                    content
            );
            default -> throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " is not supported.");
        };
    }

    private int expectedChecksumLength(String headerName) {
        return switch (headerName) {
            case AWS_CHECKSUM_SHA256_HEADER -> 32;
            case AWS_CHECKSUM_SHA1_HEADER -> 20;
            case AWS_CHECKSUM_CRC32_HEADER, AWS_CHECKSUM_CRC32C_HEADER -> 4;
            case AWS_CHECKSUM_CRC64NVME_HEADER -> Crc64NvmeChecksum.DIGEST_LENGTH_BYTES;
            default -> throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " is not supported.");
        };
    }

    private byte[] digestObject(String algorithm, InputStream content) throws IOException {
        MessageDigest digest = messageDigest(algorithm);
        byte[] buffer = new byte[8192];
        int count;
        while ((count = content.read(buffer)) >= 0) {
            digest.update(buffer, 0, count);
        }
        return digest.digest();
    }

    private byte[] crcObject(Checksum checksum, InputStream content) throws IOException {
        return crcObject(checksum, 4, content);
    }

    private byte[] crcObject(Checksum checksum, int digestLength, InputStream content) throws IOException {
        byte[] buffer = new byte[8192];
        int count;
        while ((count = content.read(buffer)) >= 0) {
            checksum.update(buffer, 0, count);
        }
        return digestLength == Crc64NvmeChecksum.DIGEST_LENGTH_BYTES
                ? longDigest(checksum.getValue())
                : intDigest(checksum.getValue());
    }

    private byte[] decodeChecksum(String headerName, String rawChecksum, int expectedLength) {
        byte[] decoded;
        try {
            decoded = Base64.getDecoder().decode(rawChecksum.trim());
        } catch (IllegalArgumentException exception) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " must be a valid base64 checksum.");
        }
        if (decoded.length != expectedLength) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " has invalid checksum length.");
        }
        return decoded;
    }

    private byte[] intDigest(long value) {
        long normalized = value & 0xffffffffL;
        return new byte[]{
                (byte) (normalized >>> 24),
                (byte) (normalized >>> 16),
                (byte) (normalized >>> 8),
                (byte) normalized
        };
    }

    private byte[] longDigest(long value) {
        return new byte[]{
                (byte) (value >>> 56),
                (byte) (value >>> 48),
                (byte) (value >>> 40),
                (byte) (value >>> 32),
                (byte) (value >>> 24),
                (byte) (value >>> 16),
                (byte) (value >>> 8),
                (byte) value
        };
    }

    private MessageDigest messageDigest(String algorithm) {
        try {
            return MessageDigest.getInstance(algorithm);
        } catch (NoSuchAlgorithmException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, algorithm + " digest is unavailable.");
        }
    }

    private void validateTagKey(String key) {
        if (key.length() > MAX_TAG_KEY_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tag keys can be at most 128 characters.");
        }
        if (!TAG_KEY_PATTERN.matcher(key).matches()) {
            throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    "tag keys can contain letters, digits, '.', '_', ':', '/', '@', '+', '-'."
            );
        }
    }

    private void validateTagValue(String value) {
        if (value.length() > MAX_TAG_VALUE_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tag values can be at most 256 characters.");
        }
        if (value.chars().anyMatch(Character::isISOControl)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "tag values cannot contain control characters.");
        }
    }

    private String normalizeCursor(String cursor, String prefix) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        String normalizedCursor = normalizeKey(cursor);
        if (!prefix.isBlank() && !normalizedCursor.startsWith(prefix)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "cursor must match prefix.");
        }
        return normalizedCursor;
    }

    private int normalizeLimit(Integer limit) {
        if (limit == null) {
            return DEFAULT_LIST_LIMIT;
        }
        if (limit < 1 || limit > MAX_LIST_LIMIT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "limit must be between 1 and 1000.");
        }
        return limit;
    }

    private int expiresInSeconds(Integer requestedExpiresInSeconds) {
        return requestedExpiresInSeconds == null ? DEFAULT_PRESIGNED_EXPIRES_SECONDS : requestedExpiresInSeconds;
    }

    private long normalizeMultipartSize(Long sizeBytes) {
        if (sizeBytes == null || sizeBytes <= 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "sizeBytes must be positive.");
        }
        return sizeBytes;
    }

    private long normalizeMultipartPartSize(Long requestedPartSizeBytes, long sizeBytes) {
        long partSizeBytes = requestedPartSizeBytes == null
                ? Math.min(DEFAULT_MULTIPART_PART_SIZE_BYTES, sizeBytes)
                : requestedPartSizeBytes;
        if (partSizeBytes <= 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "partSizeBytes must be positive.");
        }
        if (sizeBytes > MIN_MULTIPART_PART_SIZE_BYTES && partSizeBytes < MIN_MULTIPART_PART_SIZE_BYTES) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "partSizeBytes must be at least 5 MiB for multipart uploads.");
        }
        return partSizeBytes;
    }

    private int multipartPartCount(long sizeBytes, long partSizeBytes) {
        long count = (sizeBytes + partSizeBytes - 1) / partSizeBytes;
        if (count > MAX_MULTIPART_PART_COUNT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "multipart upload can contain at most 10000 parts.");
        }
        return (int) count;
    }

    private List<Integer> partNumbers(int partCount) {
        List<Integer> numbers = new ArrayList<>();
        for (int partNumber = 1; partNumber <= partCount; partNumber++) {
            numbers.add(partNumber);
        }
        return numbers;
    }

    private List<MultipartUploadPartUrl> withByteRanges(
            List<MultipartUploadPartUrl> parts,
            long sizeBytes,
            long partSizeBytes
    ) {
        return parts.stream()
                .sorted(Comparator.comparingInt(MultipartUploadPartUrl::partNumber))
                .map(part -> {
                    long startByte = (long) (part.partNumber() - 1) * partSizeBytes;
                    long endByte = Math.min(sizeBytes - 1, startByte + partSizeBytes - 1);
                    return new MultipartUploadPartUrl(
                            part.partNumber(),
                            part.url(),
                            part.method(),
                            part.expiresInSeconds(),
                            startByte,
                            endByte
                    );
                })
                .toList();
    }

    private String metadataSyncStatus(StoredObjectRecord indexed, StoredObjectRecord actual) {
        if (indexed.isDeleted()) {
            return "DELETED";
        }
        if (actual == null) {
            return "MISSING_IN_STORAGE";
        }
        if (indexed.sizeBytes() == actual.sizeBytes()
                && indexed.contentType().equals(actual.contentType())
                && indexed.tags().equals(actual.tags())) {
            return "SYNCED";
        }
        return "STALE";
    }

    private StoredObjectRecord indexedMetadataOrActual(String bucketName, String objectKey, StoredObjectRecord actual) {
        return objectMetadataRepository.findByKey(bucketName, objectKey)
                .filter(indexed -> !indexed.isDeleted())
                .map(indexed -> new StoredObjectRecord(
                        actual.key(),
                        actual.sizeBytes(),
                        actual.contentType(),
                        actual.lastModifiedAt(),
                        actual.tags(),
                        actual.deletedAt(),
                        actual.etag(),
                        indexed.checksums(),
                        indexed.userMetadata()
                ))
                .orElse(actual);
    }

    private void assertObjectNotDeleted(String bucketName, String objectKey) {
        objectMetadataRepository.findByKey(bucketName, objectKey)
                .filter(StoredObjectRecord::isDeleted)
                .ifPresent(object -> {
                    throw new ApiException(ApiErrorCode.NOT_FOUND, "Object is deleted.");
                });
    }

    private ObjectVersionRecord snapshotActiveObject(
            String bucketName,
            String objectKey,
            StoredObjectRecord current
    ) {
        String versionId = UUID.randomUUID().toString();
        String storageKey = ObjectVersionStorageKeys.PREFIX + keyHash(objectKey) + "/" + versionId;
        StoredObjectStream stream = storageAdapter.openObject(bucketName, objectKey);
        try (InputStream content = stream.content()) {
            storageAdapter.putObject(
                    bucketName,
                    storageKey,
                    content,
                    current.sizeBytes(),
                    current.contentType(),
                    current.tags()
            );
        } catch (java.io.IOException exception) {
            throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Object version snapshot failed: " + exception.getMessage());
        }
        return objectVersionRepository.save(bucketName, new ObjectVersionRecord(
                versionId,
                objectKey,
                storageKey,
                current.sizeBytes(),
                current.contentType(),
                current.lastModifiedAt(),
                OffsetDateTime.now(),
                current.tags(),
                current.userMetadata()
        ));
    }

    private void rollbackSnapshot(String bucketName, ObjectVersionRecord snapshot) {
        if (snapshot == null) {
            return;
        }
        deleteVersionStorage(bucketName, snapshot);
        objectVersionRepository.delete(bucketName, snapshot.key(), snapshot.versionId());
    }

    private StoredObjectRecord restoreVersionContent(
            String bucketName,
            String objectKey,
            ObjectVersionRecord version
    ) {
        StoredObjectStream versionStream = storageAdapter.openObject(bucketName, version.storageKey());
        try (InputStream content = versionStream.content()) {
            return storageAdapter.putObject(
                    bucketName,
                    objectKey,
                    content,
                    version.sizeBytes(),
                    version.contentType(),
                    version.tags()
            ).withUserMetadata(version.userMetadata());
        } catch (java.io.IOException exception) {
            throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Object version restore failed: " + exception.getMessage());
        }
    }

    private StoredObjectRecord putStagedUploadAsActive(
            String bucketName,
            String objectKey,
            String storageKey,
            StoredObjectRecord stagedObject,
            Map<String, String> tags
    ) {
        Map<String, String> appliedTags = tags.isEmpty() ? stagedObject.tags() : tags;
        StoredObjectStream stagedStream = storageAdapter.openObject(bucketName, storageKey);
        try (InputStream content = stagedStream.content()) {
            StoredObjectRecord storedObject = storageAdapter.putObject(
                    bucketName,
                    objectKey,
                    content,
                    stagedObject.sizeBytes(),
                    stagedObject.contentType(),
                    appliedTags
            );
            deleteUploadStagingStorage(bucketName, storageKey);
            return storedObject.withUserMetadata(stagedObject.userMetadata());
        } catch (java.io.IOException exception) {
            throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Presigned upload staging copy failed: " + exception.getMessage());
        }
    }

    private boolean deleteVersionStorage(String bucketName, ObjectVersionRecord version) {
        try {
            storageAdapter.deleteObject(bucketName, version.storageKey());
            return true;
        } catch (ApiException exception) {
            if (exception.code() == ApiErrorCode.NOT_FOUND) {
                return false;
            }
            throw exception;
        }
    }

    private boolean deleteUploadStagingStorage(String bucketName, String storageKey) {
        try {
            storageAdapter.deleteObject(bucketName, storageKey);
            return true;
        } catch (ApiException exception) {
            if (exception.code() == ApiErrorCode.NOT_FOUND) {
                return false;
            }
            throw exception;
        }
    }

    private String requireUploadStorageKey(PresignedUploadSession session) {
        String storageKey = session.storageUploadId() == null ? "" : session.storageUploadId().trim();
        if (storageKey.isBlank()) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Upload session storage key is missing.");
        }
        return storageKey;
    }

    private String uploadStagingKey(String uploadId, String objectKey) {
        return ObjectVersionStorageKeys.UPLOAD_STAGING_PREFIX + keyHash(objectKey) + "/" + uploadId;
    }

    private String keyHash(String objectKey) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(objectKey.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "SHA-256 is not available.");
        }
    }

    private List<CompletedMultipartUploadPart> normalizeCompletedParts(List<CompletedMultipartUploadPart> parts) {
        if (parts == null || parts.isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "parts are required.");
        }
        if (parts.size() > MAX_MULTIPART_PART_COUNT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "multipart upload can contain at most 10000 parts.");
        }
        Map<Integer, CompletedMultipartUploadPart> uniqueParts = new TreeMap<>();
        for (CompletedMultipartUploadPart part : parts) {
            if (part == null) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "multipart part is required.");
            }
            if (part.partNumber() < 1 || part.partNumber() > MAX_MULTIPART_PART_COUNT) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "partNumber must be between 1 and 10000.");
            }
            if (part.etag() == null || part.etag().isBlank()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "multipart part ETag is required.");
            }
            validateChecksumMetadata(part.checksums());
            if (uniqueParts.put(part.partNumber(), part) != null) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "duplicate partNumber is not allowed.");
            }
        }
        return List.copyOf(uniqueParts.values());
    }

    private void validateCompletedPartsMatchUploaded(
            String bucketName,
            String objectKey,
            String storageUploadId,
            List<CompletedMultipartUploadPart> completedParts
    ) {
        List<MultipartUploadUploadedPart> uploadedParts =
                storageAdapter.listMultipartUploadParts(bucketName, objectKey, storageUploadId);
        Map<Integer, MultipartUploadUploadedPart> uploadedByPartNumber = new TreeMap<>();
        for (MultipartUploadUploadedPart uploadedPart : uploadedParts) {
            uploadedByPartNumber.put(uploadedPart.partNumber(), uploadedPart);
        }
        for (CompletedMultipartUploadPart completedPart : completedParts) {
            MultipartUploadUploadedPart uploadedPart = uploadedByPartNumber.get(completedPart.partNumber());
            if (uploadedPart == null) {
                throw new ApiException(
                        ApiErrorCode.VALIDATION_ERROR,
                        "Multipart upload part " + completedPart.partNumber() + " has not been uploaded."
                );
            }
            if (!normalizeEtag(uploadedPart.etag()).equals(normalizeEtag(completedPart.etag()))) {
                throw new ApiException(
                        ApiErrorCode.VALIDATION_ERROR,
                        "Multipart upload part " + completedPart.partNumber() + " ETag does not match uploaded part."
                );
            }
        }
    }

    private List<CompletedMultipartUploadPart> withStoredMultipartPartChecksums(
            String uploadId,
            List<CompletedMultipartUploadPart> completedParts
    ) {
        Map<Integer, Map<String, String>> storedChecksums = multipartPartChecksumRepository.findByUploadId(uploadId);
        if (storedChecksums.isEmpty()) {
            return completedParts;
        }
        return completedParts.stream()
                .map(part -> {
                    if (!part.checksums().isEmpty()) {
                        return part;
                    }
                    Map<String, String> partChecksums = storedChecksums.getOrDefault(part.partNumber(), Map.of());
                    return partChecksums.isEmpty()
                            ? part
                            : new CompletedMultipartUploadPart(part.partNumber(), part.etag(), partChecksums);
                })
                .toList();
    }

    private void deleteMultipartPartChecksums(String uploadId) {
        try {
            multipartPartChecksumRepository.deleteByUploadId(uploadId);
        } catch (RuntimeException ignored) {
            // Best effort cleanup only; object commit/abort result must stay authoritative.
        }
    }

    private String normalizeEtag(String etag) {
        if (etag == null) {
            return "";
        }
        String normalized = etag.trim();
        if (normalized.length() >= 2 && normalized.startsWith("\"") && normalized.endsWith("\"")) {
            return normalized.substring(1, normalized.length() - 1);
        }
        return normalized;
    }

    private void validateUploadMode(PresignedUploadSession session, String expectedMode) {
        if (!expectedMode.equals(session.uploadMode())) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Upload session mode mismatch.");
        }
        if (UPLOAD_MODE_MULTIPART.equals(expectedMode)
                && (session.storageUploadId() == null || session.storageUploadId().isBlank())) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Multipart upload session is missing storage upload id.");
        }
    }

    private void validateUploadSession(
            PresignedUploadSession session,
            AuthenticatedUser user,
            String bucketName,
            String objectKey
    ) {
        if (session.userId() != user.id()
                || !session.bucketName().equals(bucketName)
                || !session.objectKey().equals(objectKey)) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Upload session access denied.");
        }
        if (!"ACTIVE".equals(session.status())) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Upload session is not active.");
        }
        if (session.expiresAt().isBefore(OffsetDateTime.now())) {
            uploadSessionRepository.updateStatus(session.uploadId(), "EXPIRED", OffsetDateTime.now());
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Upload session expired.");
        }
    }

    private interface CompositeChecksumAccumulator {
        void update(byte[] value);

        byte[] digest();
    }
}
