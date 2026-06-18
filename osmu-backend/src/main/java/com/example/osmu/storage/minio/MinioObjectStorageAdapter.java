package com.example.osmu.storage.minio;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.CompletedMultipartUploadPart;
import com.example.osmu.object.MultipartUploadPartUrl;
import com.example.osmu.object.MultipartUploadUploadedPart;
import com.example.osmu.object.PresignedObjectUrl;
import com.example.osmu.object.StoredObjectData;
import com.example.osmu.object.StoredObjectPage;
import com.example.osmu.object.StoredObjectRecord;
import com.example.osmu.object.StoredObjectStream;
import com.example.osmu.object.StorageMultipartUpload;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.google.common.collect.HashMultimap;
import com.google.common.collect.Multimap;
import io.minio.DeleteObjectTagsArgs;
import io.minio.BucketExistsArgs;
import io.minio.CreateMultipartUploadResponse;
import io.minio.GetObjectArgs;
import io.minio.GetObjectResponse;
import io.minio.GetObjectTagsArgs;
import io.minio.GetPresignedObjectUrlArgs;
import io.minio.ListObjectsArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioAsyncClient;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveBucketArgs;
import io.minio.RemoveObjectArgs;
import io.minio.Result;
import io.minio.SetObjectTagsArgs;
import io.minio.StatObjectArgs;
import io.minio.StatObjectResponse;
import io.minio.UploadPartResponse;
import io.minio.errors.ErrorResponseException;
import io.minio.http.Method;
import io.minio.messages.Item;
import io.minio.messages.Part;
import io.minio.messages.Tags;
import java.io.InputStream;
import java.time.OffsetDateTime;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.storage", name = "mode", havingValue = "minio")
public class MinioObjectStorageAdapter implements ObjectStorageAdapter {

    private final MinioClient minioClient;
    private final MinioClient presignedMinioClient;
    private final MinioAsyncClient minioAsyncClient;
    private final MinioBucketCorsProvisioner corsProvisioner;
    private final String region;

    public MinioObjectStorageAdapter(
            @Value("${osmu.storage.endpoint}") String endpoint,
            @Value("${osmu.storage.presigned-endpoint:${osmu.storage.endpoint}}") String presignedEndpoint,
            @Value("${osmu.storage.access-key}") String accessKey,
            @Value("${osmu.storage.secret-key}") String secretKey,
            @Value("${osmu.storage.region:us-east-1}") String region,
            MinioBucketCorsProvisioner corsProvisioner
    ) {
        this.region = region;
        this.corsProvisioner = corsProvisioner;
        String effectivePresignedEndpoint = presignedEndpoint == null || presignedEndpoint.isBlank()
                ? endpoint
                : presignedEndpoint;
        this.minioClient = MinioClient.builder()
                .endpoint(endpoint)
                .credentials(accessKey, secretKey)
                .build();
        this.presignedMinioClient = MinioClient.builder()
                .endpoint(effectivePresignedEndpoint)
                .credentials(accessKey, secretKey)
                .build();
        this.minioAsyncClient = MinioAsyncClient.builder()
                .endpoint(endpoint)
                .credentials(accessKey, secretKey)
                .build();
    }

    @Override
    public boolean isHealthy() {
        try {
            minioClient.listBuckets();
            return true;
        } catch (Exception exception) {
            return false;
        }
    }

    @Override
    public StoredObjectPage listObjects(
            String bucketName,
            String prefix,
            String delimiter,
            String search,
            Map<String, String> tagFilter,
            String cursor,
            int limit
    ) {
        String normalizedPrefix = prefix == null ? "" : prefix;
        String normalizedDelimiter = delimiter == null ? "" : delimiter;
        String normalizedSearch = search == null ? "" : search.trim().toLowerCase();
        Map<String, String> normalizedTagFilter = tagFilter == null ? Map.of() : tagFilter;
        boolean recursiveScan = normalizedDelimiter.isBlank()
                || !normalizedSearch.isBlank()
                || !normalizedTagFilter.isEmpty();
        String normalizedCursor = cursor == null ? "" : cursor;
        try {
            ListObjectsArgs.Builder builder = ListObjectsArgs.builder()
                    .bucket(bucketName)
                    .prefix(normalizedPrefix);
            if (recursiveScan) {
                builder.recursive(true);
            } else {
                builder.recursive(false).delimiter(normalizedDelimiter).maxKeys(limit + 1);
            }
            if (normalizedSearch.isBlank() && normalizedTagFilter.isEmpty()) {
                builder.maxKeys(limit + 1);
            }
            if (!normalizedCursor.isBlank()) {
                builder.startAfter(normalizedCursor);
            }

            Iterable<Result<Item>> results = minioClient.listObjects(builder.build());
            List<ListedObjectEntry> entries = new ArrayList<>();
            for (Result<Item> result : results) {
                Item item = result.get();
                if (!normalizedSearch.isBlank()
                        && !item.objectName().toLowerCase().contains(normalizedSearch)) {
                    continue;
                }
                if (item.isDir()) {
                    entries.add(new ListedObjectEntry(item.objectName(), null));
                } else {
                    StoredObjectRecord object = mapListItem(bucketName, item);
                    if (!matchesTags(object, normalizedTagFilter)) {
                        continue;
                    }
                    entries.add(new ListedObjectEntry(item.objectName(), object));
                }
                if (entries.size() > limit) {
                    break;
                }
            }
            return recursiveScan ? toPage(objectsFrom(entries), limit) : toDelimitedPage(entries, limit);
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    @Override
    public MultipartUploadUploadedPart uploadMultipartUploadPart(
            String bucketName,
            String objectKey,
            String storageUploadId,
            int partNumber,
            InputStream content,
            long sizeBytes
    ) {
        try {
            UploadPartResponse response = minioAsyncClient.uploadPartAsync(
                    bucketName,
                    region,
                    objectKey,
                    content,
                    sizeBytes,
                    storageUploadId,
                    partNumber,
                    emptyMultimap(),
                    emptyMultimap()
            ).get();
            return new MultipartUploadUploadedPart(response.partNumber(), quotedEtag(response.etag()), sizeBytes);
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    @Override
    public StoredObjectStream openObject(String bucketName, String objectKey) {
        StoredObjectRecord metadata = statObject(bucketName, objectKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object not found."));

        try {
            GetObjectResponse response = minioClient.getObject(GetObjectArgs.builder()
                    .bucket(bucketName)
                    .object(objectKey)
                    .build());
            return new StoredObjectStream(metadata, response);
        } catch (Exception exception) {
            if (isMissingObject(exception)) {
                throw new ApiException(ApiErrorCode.NOT_FOUND, "Object not found.");
            }
            throw storageException(exception);
        }
    }

    @Override
    public void createBucket(String bucketName) {
        try {
            boolean exists = minioClient.bucketExists(BucketExistsArgs.builder()
                    .bucket(bucketName)
                    .build());
            if (!exists) {
                minioClient.makeBucket(MakeBucketArgs.builder()
                        .bucket(bucketName)
                        .build());
            }
            corsProvisioner.apply(bucketName);
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    @Override
    public void deleteBucket(String bucketName) {
        try {
            minioClient.removeBucket(RemoveBucketArgs.builder()
                    .bucket(bucketName)
                    .build());
        } catch (Exception exception) {
            if (isMissingBucket(exception)) {
                return;
            }
            throw storageException(exception);
        }
    }

    @Override
    public List<StoredObjectRecord> listObjects(String bucketName, String prefix) {
        String normalizedPrefix = prefix == null ? "" : prefix;
        try {
            Iterable<Result<Item>> results = minioClient.listObjects(ListObjectsArgs.builder()
                    .bucket(bucketName)
                    .prefix(normalizedPrefix)
                    .recursive(true)
                    .build());

            List<StoredObjectRecord> objects = new ArrayList<>();
            for (Result<Item> result : results) {
                Item item = result.get();
                objects.add(mapListItem(bucketName, item));
            }
            return objects;
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    @Override
    public Optional<StoredObjectRecord> statObject(String bucketName, String objectKey) {
        try {
            StatObjectResponse response = minioClient.statObject(StatObjectArgs.builder()
                    .bucket(bucketName)
                    .object(objectKey)
                    .build());
            return Optional.of(mapStat(bucketName, objectKey, response));
        } catch (Exception exception) {
            if (isMissingObject(exception)) {
                return Optional.empty();
            }
            throw storageException(exception);
        }
    }

    @Override
    public StoredObjectData getObject(String bucketName, String objectKey) {
        StoredObjectRecord metadata = statObject(bucketName, objectKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object not found."));

        try (GetObjectResponse response = minioClient.getObject(GetObjectArgs.builder()
                .bucket(bucketName)
                .object(objectKey)
                .build())) {
            return new StoredObjectData(metadata, response.readAllBytes());
        } catch (Exception exception) {
            if (isMissingObject(exception)) {
                throw new ApiException(ApiErrorCode.NOT_FOUND, "Object not found.");
            }
            throw storageException(exception);
        }
    }

    @Override
    public StoredObjectRecord putObject(
            String bucketName,
            String objectKey,
            InputStream content,
            long sizeBytes,
            String contentType,
            Map<String, String> tags
    ) {
        createBucket(bucketName);
        String safeContentType = contentType == null || contentType.isBlank()
                ? "application/octet-stream"
                : contentType;

        try {
            minioClient.putObject(PutObjectArgs.builder()
                    .bucket(bucketName)
                    .object(objectKey)
                    .stream(content, sizeBytes, -1)
                    .contentType(safeContentType)
                    .build());
            applyObjectTags(bucketName, objectKey, tags);
            return statObject(bucketName, objectKey)
                    .orElse(new StoredObjectRecord(
                            objectKey,
                            sizeBytes,
                            safeContentType,
                            OffsetDateTime.now(),
                            tags
                    ));
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    @Override
    public StoredObjectRecord deleteObject(String bucketName, String objectKey) {
        StoredObjectRecord metadata = statObject(bucketName, objectKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object not found."));

        try {
            minioClient.removeObject(RemoveObjectArgs.builder()
                    .bucket(bucketName)
                    .object(objectKey)
                    .build());
            return metadata;
        } catch (Exception exception) {
            if (isMissingObject(exception)) {
                throw new ApiException(ApiErrorCode.NOT_FOUND, "Object not found.");
            }
            throw storageException(exception);
        }
    }

    @Override
    public StoredObjectRecord setObjectTags(String bucketName, String objectKey, Map<String, String> tags) {
        statObject(bucketName, objectKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object not found."));
        try {
            if (tags == null || tags.isEmpty()) {
                minioClient.deleteObjectTags(DeleteObjectTagsArgs.builder()
                        .bucket(bucketName)
                        .object(objectKey)
                        .build());
            } else {
                applyObjectTags(bucketName, objectKey, tags);
            }
            return statObject(bucketName, objectKey)
                    .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object not found."));
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    @Override
    public PresignedObjectUrl createPresignedPutUrl(
            String bucketName,
            String objectKey,
            String contentType,
            int expiresInSeconds
    ) {
        createBucket(bucketName);
        return presignedUrl(Method.PUT, bucketName, objectKey, expiresInSeconds);
    }

    @Override
    public PresignedObjectUrl createPresignedGetUrl(String bucketName, String objectKey, int expiresInSeconds) {
        statObject(bucketName, objectKey)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Object not found."));
        return presignedUrl(Method.GET, bucketName, objectKey, expiresInSeconds);
    }

    @Override
    public StorageMultipartUpload createMultipartUpload(
            String bucketName,
            String objectKey,
            String contentType,
            int expiresInSeconds,
            List<Integer> partNumbers
    ) {
        createBucket(bucketName);
        String safeContentType = contentType == null || contentType.isBlank()
                ? "application/octet-stream"
                : contentType;
        Multimap<String, String> headers = HashMultimap.create();
        headers.put("Content-Type", safeContentType);
        try {
            CreateMultipartUploadResponse response = minioAsyncClient.createMultipartUploadAsync(
                    bucketName,
                    region,
                    objectKey,
                    headers,
                    emptyMultimap()
            ).get();
            String storageUploadId = response.result().uploadId();
            List<MultipartUploadPartUrl> parts = partNumbers.stream()
                    .map(partNumber -> partUrl(bucketName, objectKey, storageUploadId, partNumber, expiresInSeconds))
                    .toList();
            return new StorageMultipartUpload(storageUploadId, parts);
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    @Override
    public StoredObjectRecord completeMultipartUpload(
            String bucketName,
            String objectKey,
            String storageUploadId,
            List<CompletedMultipartUploadPart> parts
    ) {
        try {
            Part[] minioParts = parts.stream()
                    .map(part -> new Part(part.partNumber(), cleanEtag(part.etag())))
                    .toArray(Part[]::new);
            minioAsyncClient.completeMultipartUploadAsync(
                    bucketName,
                    region,
                    objectKey,
                    storageUploadId,
                    minioParts,
                    emptyMultimap(),
                    emptyMultimap()
            ).get();
            return statObject(bucketName, objectKey)
                    .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Uploaded object not found."));
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    @Override
    public StorageMultipartUpload refreshMultipartUploadParts(
            String bucketName,
            String objectKey,
            String storageUploadId,
            int expiresInSeconds,
            List<Integer> partNumbers
    ) {
        createBucket(bucketName);
        List<MultipartUploadPartUrl> parts = partNumbers.stream()
                .map(partNumber -> partUrl(bucketName, objectKey, storageUploadId, partNumber, expiresInSeconds))
                .toList();
        return new StorageMultipartUpload(storageUploadId, parts);
    }

    @Override
    public void abortMultipartUpload(String bucketName, String objectKey, String storageUploadId) {
        try {
            minioAsyncClient.abortMultipartUploadAsync(
                    bucketName,
                    region,
                    objectKey,
                    storageUploadId,
                    emptyMultimap(),
                    emptyMultimap()
            ).get();
        } catch (Exception exception) {
            if (!isMissingObject(exception) && !isErrorCode(exception, "NoSuchUpload")) {
                throw storageException(exception);
            }
        }
    }

    @Override
    public List<MultipartUploadUploadedPart> listMultipartUploadParts(
            String bucketName,
            String objectKey,
            String storageUploadId
    ) {
        try {
            List<MultipartUploadUploadedPart> uploadedParts = new ArrayList<>();
            Integer partNumberMarker = null;
            boolean truncated;
            do {
                var response = minioAsyncClient.listPartsAsync(
                        bucketName,
                        region,
                        objectKey,
                        1000,
                        partNumberMarker,
                        storageUploadId,
                        emptyMultimap(),
                        emptyMultimap()
                ).get();
                var result = response.result();
                for (Part part : result.partList()) {
                    uploadedParts.add(new MultipartUploadUploadedPart(
                            part.partNumber(),
                            part.etag(),
                            part.partSize()
                    ));
                }
                truncated = result.isTruncated();
                partNumberMarker = result.nextPartNumberMarker();
            } while (truncated);
            return uploadedParts;
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    private PresignedObjectUrl presignedUrl(
            Method method,
            String bucketName,
            String objectKey,
            int expiresInSeconds
    ) {
        try {
            String url = presignedMinioClient.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                    .method(method)
                    .bucket(bucketName)
                    .region(region)
                    .object(objectKey)
                    .expiry(expiresInSeconds, TimeUnit.SECONDS)
                    .build());
            return new PresignedObjectUrl(url, method.name(), expiresInSeconds, null);
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    private MultipartUploadPartUrl partUrl(
            String bucketName,
            String objectKey,
            String storageUploadId,
            int partNumber,
            int expiresInSeconds
    ) {
        try {
            Map<String, String> queryParams = Map.of(
                    "partNumber", String.valueOf(partNumber),
                    "uploadId", storageUploadId
            );
            String url = presignedMinioClient.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                    .method(Method.PUT)
                    .bucket(bucketName)
                    .region(region)
                    .object(objectKey)
                    .expiry(expiresInSeconds, TimeUnit.SECONDS)
                    .extraQueryParams(queryParams)
                    .build());
            return new MultipartUploadPartUrl(partNumber, url, Method.PUT.name(), expiresInSeconds, 0, 0);
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    private Multimap<String, String> emptyMultimap() {
        return HashMultimap.create();
    }

    private String cleanEtag(String etag) {
        String cleaned = etag == null ? "" : etag.trim();
        if (cleaned.length() >= 2 && cleaned.startsWith("\"") && cleaned.endsWith("\"")) {
            return cleaned.substring(1, cleaned.length() - 1);
        }
        return cleaned;
    }

    private String quotedEtag(String etag) {
        String cleaned = cleanEtag(etag);
        return cleaned.isBlank() ? "" : "\"" + cleaned + "\"";
    }

    private StoredObjectRecord mapStat(String bucketName, String objectKey, StatObjectResponse response) {
        return new StoredObjectRecord(
                objectKey,
                response.size(),
                response.contentType() == null ? "application/octet-stream" : response.contentType(),
                modifiedAt(response.lastModified()),
                objectTags(bucketName, objectKey),
                null,
                response.etag()
        );
    }

    private StoredObjectRecord mapListItem(String bucketName, Item item) {
        return new StoredObjectRecord(
                item.objectName(),
                item.size(),
                "application/octet-stream",
                modifiedAt(item.lastModified()),
                objectTags(bucketName, item.objectName()),
                null,
                item.etag()
        );
    }

    private void applyObjectTags(String bucketName, String objectKey, Map<String, String> tags) throws Exception {
        if (tags == null || tags.isEmpty()) {
            return;
        }
        minioClient.setObjectTags(SetObjectTagsArgs.builder()
                .bucket(bucketName)
                .object(objectKey)
                .tags(Tags.newObjectTags(tags))
                .build());
    }

    private Map<String, String> objectTags(String bucketName, String objectKey) {
        try {
            Tags tags = minioClient.getObjectTags(GetObjectTagsArgs.builder()
                    .bucket(bucketName)
                    .object(objectKey)
                    .build());
            return tags == null ? Map.of() : tags.get();
        } catch (Exception exception) {
            if (isMissingObject(exception) || isErrorCode(exception, "NoSuchTagSet")) {
                return Map.of();
            }
            throw storageException(exception);
        }
    }

    private boolean matchesTags(StoredObjectRecord object, Map<String, String> tagFilter) {
        if (tagFilter.isEmpty()) {
            return true;
        }
        return tagFilter.entrySet().stream()
                .allMatch(entry -> entry.getValue().equals(object.tags().get(entry.getKey())));
    }

    private OffsetDateTime modifiedAt(ZonedDateTime zonedDateTime) {
        return zonedDateTime == null ? OffsetDateTime.now() : zonedDateTime.toOffsetDateTime();
    }

    private StoredObjectPage toPage(List<StoredObjectRecord> objects, int limit) {
        if (objects.size() <= limit) {
            return StoredObjectPage.recursive(objects, null);
        }
        List<StoredObjectRecord> pageItems = List.copyOf(objects.subList(0, limit));
        return StoredObjectPage.recursive(pageItems, pageItems.get(pageItems.size() - 1).key());
    }

    private List<StoredObjectRecord> objectsFrom(List<ListedObjectEntry> entries) {
        return entries.stream()
                .map(ListedObjectEntry::object)
                .toList();
    }

    private StoredObjectPage toDelimitedPage(List<ListedObjectEntry> entries, int limit) {
        boolean hasNext = entries.size() > limit;
        List<ListedObjectEntry> pageEntries = hasNext ? entries.subList(0, limit) : entries;
        List<StoredObjectRecord> objects = new ArrayList<>();
        List<String> prefixes = new ArrayList<>();
        for (ListedObjectEntry entry : pageEntries) {
            if (entry.isPrefix()) {
                prefixes.add(entry.key());
            } else {
                objects.add(entry.object());
            }
        }
        String nextCursor = hasNext ? pageEntries.get(pageEntries.size() - 1).key() : null;
        return new StoredObjectPage(objects, prefixes, nextCursor);
    }

    private record ListedObjectEntry(String key, StoredObjectRecord object) {
        private boolean isPrefix() {
            return object == null;
        }
    }

    private boolean isMissingObject(Exception exception) {
        return isErrorCode(exception, "NoSuchKey", "NoSuchObject", "NoSuchBucket");
    }

    private boolean isMissingBucket(Exception exception) {
        return isErrorCode(exception, "NoSuchBucket");
    }

    private boolean isErrorCode(Exception exception, String... codes) {
        if (!(exception instanceof ErrorResponseException errorResponseException)) {
            return false;
        }
        String actualCode = errorResponseException.errorResponse().code();
        for (String code : codes) {
            if (code.equals(actualCode)) {
                return true;
            }
        }
        return false;
    }

    private ApiException storageException(Exception exception) {
        Throwable current = exception;
        while (current != null) {
            if (current instanceof ApiException apiException) {
                return apiException;
            }
            current = current.getCause();
        }
        return new ApiException(ApiErrorCode.STORAGE_ERROR, "Object storage operation failed: " + exception.getMessage());
    }
}
