package com.example.osmu.storage.memory;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.CompletedMultipartUploadPart;
import com.example.osmu.object.MultipartUploadUploadedPart;
import com.example.osmu.object.PresignedObjectUrl;
import com.example.osmu.object.StoredObjectData;
import com.example.osmu.object.StoredObjectPage;
import com.example.osmu.object.StoredObjectRecord;
import com.example.osmu.object.StoredObjectStream;
import com.example.osmu.object.StorageMultipartUpload;
import com.example.osmu.storage.ObjectStorageAdapter;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.storage", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryObjectStorageAdapter implements ObjectStorageAdapter {

    private final ConcurrentMap<String, ConcurrentMap<String, StoredObjectData>> objectsByBucket =
            new ConcurrentHashMap<>();

    @Override
    public boolean isHealthy() {
        return true;
    }

    @Override
    public void createBucket(String bucketName) {
        bucketObjects(bucketName);
    }

    @Override
    public void deleteBucket(String bucketName) {
        ConcurrentMap<String, StoredObjectData> bucketObjects = objectsByBucket.get(bucketName);
        if (bucketObjects != null && !bucketObjects.isEmpty()) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Bucket is not empty.");
        }
        objectsByBucket.remove(bucketName);
    }

    @Override
    public List<StoredObjectRecord> listObjects(String bucketName, String prefix) {
        String normalizedPrefix = prefix == null ? "" : prefix;
        return bucketObjects(bucketName)
                .values()
                .stream()
                .map(StoredObjectData::metadata)
                .filter(object -> object.key().startsWith(normalizedPrefix))
                .sorted(Comparator.comparing(StoredObjectRecord::key))
                .toList();
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
        String normalizedCursor = cursor == null ? "" : cursor;
        if (normalizedDelimiter.isBlank() || !normalizedSearch.isBlank() || !normalizedTagFilter.isEmpty()) {
            List<StoredObjectRecord> objects = bucketObjects(bucketName)
                    .values()
                    .stream()
                    .map(StoredObjectData::metadata)
                    .filter(object -> object.key().startsWith(normalizedPrefix))
                    .filter(object -> normalizedSearch.isBlank()
                            || object.key().toLowerCase().contains(normalizedSearch))
                    .filter(object -> matchesTags(object, normalizedTagFilter))
                    .filter(object -> normalizedCursor.isBlank() || object.key().compareTo(normalizedCursor) > 0)
                    .sorted(Comparator.comparing(StoredObjectRecord::key))
                    .limit((long) limit + 1)
                    .toList();
            return toPage(objects, limit);
        }

        Map<String, ListedObjectEntry> entries = new TreeMap<>();
        bucketObjects(bucketName).values().stream()
                .map(StoredObjectData::metadata)
                .filter(object -> object.key().startsWith(normalizedPrefix))
                .forEach(object -> addDelimitedEntry(entries, object, normalizedPrefix, normalizedDelimiter));

        List<ListedObjectEntry> pageEntries = entries.values().stream()
                .filter(entry -> normalizedCursor.isBlank() || entry.key().compareTo(normalizedCursor) > 0)
                .limit((long) limit + 1)
                .toList();
        return toDelimitedPage(pageEntries, limit);
    }

    @Override
    public Optional<StoredObjectRecord> statObject(String bucketName, String objectKey) {
        return Optional.ofNullable(bucketObjects(bucketName).get(objectKey))
                .map(StoredObjectData::metadata);
    }

    @Override
    public StoredObjectData getObject(String bucketName, String objectKey) {
        StoredObjectData data = bucketObjects(bucketName).get(objectKey);
        if (data == null) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Object not found.");
        }
        return data;
    }

    @Override
    public StoredObjectStream openObject(String bucketName, String objectKey) {
        StoredObjectData data = getObject(bucketName, objectKey);
        return new StoredObjectStream(data.metadata(), new ByteArrayInputStream(data.content()));
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
        byte[] storedContent;
        try {
            storedContent = content.readAllBytes();
        } catch (IOException exception) {
            throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Object stream read failed: " + exception.getMessage());
        }
        StoredObjectRecord metadata = new StoredObjectRecord(
                objectKey,
                storedContent.length,
                contentType == null || contentType.isBlank() ? "application/octet-stream" : contentType,
                OffsetDateTime.now(),
                tags,
                null,
                md5Hex(storedContent)
        );
        bucketObjects(bucketName).put(objectKey, new StoredObjectData(metadata, storedContent));
        return metadata;
    }

    @Override
    public StoredObjectRecord deleteObject(String bucketName, String objectKey) {
        StoredObjectData removed = bucketObjects(bucketName).remove(objectKey);
        if (removed == null) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Object not found.");
        }
        return removed.metadata();
    }

    @Override
    public StoredObjectRecord setObjectTags(String bucketName, String objectKey, Map<String, String> tags) {
        ConcurrentMap<String, StoredObjectData> bucketObjects = bucketObjects(bucketName);
        StoredObjectData current = bucketObjects.get(objectKey);
        if (current == null) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Object not found.");
        }
        StoredObjectRecord currentMetadata = current.metadata();
        StoredObjectRecord updatedMetadata = new StoredObjectRecord(
                currentMetadata.key(),
                currentMetadata.sizeBytes(),
                currentMetadata.contentType(),
                currentMetadata.lastModifiedAt(),
                tags,
                null,
                currentMetadata.etag(),
                currentMetadata.checksums(),
                currentMetadata.userMetadata()
        );
        bucketObjects.put(objectKey, new StoredObjectData(updatedMetadata, current.content()));
        return updatedMetadata;
    }

    @Override
    public PresignedObjectUrl createPresignedPutUrl(
            String bucketName,
            String objectKey,
            String contentType,
            int expiresInSeconds
    ) {
        throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Presigned URLs require MinIO storage mode.");
    }

    @Override
    public PresignedObjectUrl createPresignedGetUrl(String bucketName, String objectKey, int expiresInSeconds) {
        throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Presigned URLs require MinIO storage mode.");
    }

    @Override
    public StorageMultipartUpload createMultipartUpload(
            String bucketName,
            String objectKey,
            String contentType,
            int expiresInSeconds,
            List<Integer> partNumbers
    ) {
        throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Multipart upload requires MinIO storage mode.");
    }

    @Override
    public StoredObjectRecord completeMultipartUpload(
            String bucketName,
            String objectKey,
            String storageUploadId,
            List<CompletedMultipartUploadPart> parts
    ) {
        throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Multipart upload requires MinIO storage mode.");
    }

    @Override
    public StorageMultipartUpload refreshMultipartUploadParts(
            String bucketName,
            String objectKey,
            String storageUploadId,
            int expiresInSeconds,
            List<Integer> partNumbers
    ) {
        throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Multipart upload requires MinIO storage mode.");
    }

    @Override
    public void abortMultipartUpload(String bucketName, String objectKey, String storageUploadId) {
        throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Multipart upload requires MinIO storage mode.");
    }

    @Override
    public List<MultipartUploadUploadedPart> listMultipartUploadParts(
            String bucketName,
            String objectKey,
            String storageUploadId
    ) {
        throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Multipart upload requires MinIO storage mode.");
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
        throw new ApiException(ApiErrorCode.STORAGE_ERROR, "Multipart upload requires MinIO storage mode.");
    }

    private ConcurrentMap<String, StoredObjectData> bucketObjects(String bucketName) {
        return objectsByBucket.computeIfAbsent(bucketName, ignored -> new ConcurrentHashMap<>());
    }

    private String md5Hex(byte[] content) {
        try {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            return HexFormat.of().formatHex(digest.digest(content));
        } catch (NoSuchAlgorithmException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "MD5 digest is unavailable.");
        }
    }

    private StoredObjectPage toPage(List<StoredObjectRecord> objects, int limit) {
        if (objects.size() <= limit) {
            return StoredObjectPage.recursive(objects, null);
        }
        List<StoredObjectRecord> pageItems = List.copyOf(objects.subList(0, limit));
        return StoredObjectPage.recursive(pageItems, pageItems.get(pageItems.size() - 1).key());
    }

    private void addDelimitedEntry(
            Map<String, ListedObjectEntry> entries,
            StoredObjectRecord object,
            String prefix,
            String delimiter
    ) {
        String remainingKey = object.key().substring(prefix.length());
        int delimiterIndex = remainingKey.indexOf(delimiter);
        if (delimiterIndex >= 0) {
            String commonPrefix = prefix + remainingKey.substring(0, delimiterIndex + delimiter.length());
            entries.putIfAbsent(commonPrefix, new ListedObjectEntry(commonPrefix, null));
            return;
        }
        entries.putIfAbsent(object.key(), new ListedObjectEntry(object.key(), object));
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

    private boolean matchesTags(StoredObjectRecord object, Map<String, String> tagFilter) {
        if (tagFilter.isEmpty()) {
            return true;
        }
        return tagFilter.entrySet().stream()
                .allMatch(entry -> entry.getValue().equals(object.tags().get(entry.getKey())));
    }

    private record ListedObjectEntry(String key, StoredObjectRecord object) {
        private boolean isPrefix() {
            return object == null;
        }
    }
}
