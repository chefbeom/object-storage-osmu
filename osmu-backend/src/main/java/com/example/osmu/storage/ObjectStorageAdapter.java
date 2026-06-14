package com.example.osmu.storage;

import com.example.osmu.object.PresignedObjectUrl;
import com.example.osmu.object.CompletedMultipartUploadPart;
import com.example.osmu.object.MultipartUploadUploadedPart;
import com.example.osmu.object.StoredObjectData;
import com.example.osmu.object.StoredObjectPage;
import com.example.osmu.object.StoredObjectRecord;
import com.example.osmu.object.StoredObjectStream;
import com.example.osmu.object.StorageMultipartUpload;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public interface ObjectStorageAdapter {

    boolean isHealthy();

    void createBucket(String bucketName);

    void deleteBucket(String bucketName);

    List<StoredObjectRecord> listObjects(String bucketName, String prefix);

    StoredObjectPage listObjects(
            String bucketName,
            String prefix,
            String delimiter,
            String search,
            Map<String, String> tagFilter,
            String cursor,
            int limit
    );

    Optional<StoredObjectRecord> statObject(String bucketName, String objectKey);

    StoredObjectData getObject(String bucketName, String objectKey);

    StoredObjectStream openObject(String bucketName, String objectKey);

    default StoredObjectRecord putObject(String bucketName, String objectKey, byte[] content, String contentType) {
        return putObject(bucketName, objectKey, content, contentType, Map.of());
    }

    default StoredObjectRecord putObject(
            String bucketName,
            String objectKey,
            byte[] content,
            String contentType,
            Map<String, String> tags
    ) {
        return putObject(
                bucketName,
                objectKey,
                new ByteArrayInputStream(content),
                content.length,
                contentType,
                tags
        );
    }

    StoredObjectRecord putObject(
            String bucketName,
            String objectKey,
            InputStream content,
            long sizeBytes,
            String contentType,
            Map<String, String> tags
    );

    StoredObjectRecord setObjectTags(String bucketName, String objectKey, Map<String, String> tags);

    StoredObjectRecord deleteObject(String bucketName, String objectKey);

    PresignedObjectUrl createPresignedPutUrl(
            String bucketName,
            String objectKey,
            String contentType,
            int expiresInSeconds
    );

    PresignedObjectUrl createPresignedGetUrl(String bucketName, String objectKey, int expiresInSeconds);

    StorageMultipartUpload createMultipartUpload(
            String bucketName,
            String objectKey,
            String contentType,
            int expiresInSeconds,
            List<Integer> partNumbers
    );

    StorageMultipartUpload refreshMultipartUploadParts(
            String bucketName,
            String objectKey,
            String storageUploadId,
            int expiresInSeconds,
            List<Integer> partNumbers
    );

    List<MultipartUploadUploadedPart> listMultipartUploadParts(
            String bucketName,
            String objectKey,
            String storageUploadId
    );

    MultipartUploadUploadedPart uploadMultipartUploadPart(
            String bucketName,
            String objectKey,
            String storageUploadId,
            int partNumber,
            InputStream content,
            long sizeBytes
    );

    StoredObjectRecord completeMultipartUpload(
            String bucketName,
            String objectKey,
            String storageUploadId,
            List<CompletedMultipartUploadPart> parts
    );

    void abortMultipartUpload(String bucketName, String objectKey, String storageUploadId);
}
