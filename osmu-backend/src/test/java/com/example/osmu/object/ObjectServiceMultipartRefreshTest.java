package com.example.osmu.object;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.repository.InMemoryPresignedUploadSessionRepository;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class ObjectServiceMultipartRefreshTest {

    private final BucketService bucketService = mock(BucketService.class);
    private final ObjectStorageAdapter storageAdapter = mock(ObjectStorageAdapter.class);
    private final ObjectMetadataRepository objectMetadataRepository = mock(ObjectMetadataRepository.class);
    private final ObjectVersionRepository objectVersionRepository = mock(ObjectVersionRepository.class);
    private final InMemoryPresignedUploadSessionRepository uploadSessionRepository =
            new InMemoryPresignedUploadSessionRepository();
    private final ObjectService objectService = new ObjectService(
            bucketService,
            storageAdapter,
            objectMetadataRepository,
            objectVersionRepository,
            uploadSessionRepository
    );
    private final AuthenticatedUser user = new AuthenticatedUser(1L, "admin", "ADMIN", null);

    @Test
    void presignedOverwriteUploadsToStagingKeyAndSnapshotsOnComplete() {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 10L, 1L, OffsetDateTime.now());
        StoredObjectRecord previous = new StoredObjectRecord(
                "docs/sample.txt",
                10L,
                "text/plain",
                OffsetDateTime.now().minusMinutes(5),
                Map.of("version", "one")
        );
        StoredObjectRecord staged = new StoredObjectRecord(
                ".osmu/uploads/staged",
                11L,
                "text/plain",
                OffsetDateTime.now(),
                Map.of()
        );
        StoredObjectRecord completed = new StoredObjectRecord(
                "docs/sample.txt",
                11L,
                "text/plain",
                OffsetDateTime.now(),
                Map.of("version", "two")
        );
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "docs/sample.txt")).thenReturn(Optional.of(previous));
        when(storageAdapter.createPresignedPutUrl(
                eq("bucket"),
                argThat(key -> key.startsWith(ObjectVersionStorageKeys.UPLOAD_STAGING_PREFIX)),
                eq("text/plain"),
                eq(900)
        )).thenReturn(new PresignedObjectUrl("https://storage/staged", "PUT", 900, null));
        when(objectVersionRepository.save(eq("bucket"), any(ObjectVersionRecord.class)))
                .thenAnswer(invocation -> invocation.getArgument(1));

        PresignedObjectUrl url = objectService.createPresignedUploadUrl(
                "bucket",
                new PresignedObjectUrlRequest("docs/sample.txt", "text/plain", 900, "version=two"),
                user
        );
        PresignedUploadSession session = uploadSessionRepository.findByUploadId(url.uploadId()).orElseThrow();
        String stagingKey = session.storageUploadId();

        when(storageAdapter.statObject("bucket", stagingKey)).thenReturn(Optional.of(staged));
        when(storageAdapter.openObject("bucket", "docs/sample.txt"))
                .thenReturn(new StoredObjectStream(previous, new ByteArrayInputStream("hello osmu".getBytes())));
        when(storageAdapter.openObject("bucket", stagingKey))
                .thenReturn(new StoredObjectStream(staged, new ByteArrayInputStream("hello osmu2".getBytes())));
        when(storageAdapter.putObject(
                eq("bucket"),
                argThat(key -> key.startsWith(ObjectVersionStorageKeys.PREFIX)),
                any(InputStream.class),
                eq(10L),
                eq("text/plain"),
                eq(Map.of("version", "one"))
        )).thenReturn(new StoredObjectRecord(
                ObjectVersionStorageKeys.PREFIX + "snapshot",
                10L,
                "text/plain",
                OffsetDateTime.now(),
                Map.of("version", "one")
        ));
        when(storageAdapter.putObject(
                eq("bucket"),
                eq("docs/sample.txt"),
                any(InputStream.class),
                eq(11L),
                eq("text/plain"),
                eq(Map.of("version", "two"))
        )).thenReturn(completed);
        when(storageAdapter.deleteObject("bucket", stagingKey)).thenReturn(staged);

        StoredObjectRecord result = objectService.completePresignedUpload(
                "bucket",
                new PresignedUploadCompleteRequest(url.uploadId(), "docs/sample.txt"),
                user
        );

        assertThat(session.previousExists()).isTrue();
        assertThat(session.previousSizeBytes()).isEqualTo(10L);
        assertThat(stagingKey).startsWith(ObjectVersionStorageKeys.UPLOAD_STAGING_PREFIX);
        assertThat(result).isEqualTo(completed);
        verify(bucketService).applyObjectChange("bucket", 11L, 1L);
        verify(objectVersionRepository).save(eq("bucket"), any(ObjectVersionRecord.class));
        verify(objectMetadataRepository).save("bucket", completed);
    }

    @Test
    void multipartOverwriteSnapshotsPreviousObjectBeforeComplete() {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 10L, 1L, OffsetDateTime.now());
        StoredObjectRecord previous = new StoredObjectRecord(
                "videos/input.mp4",
                10L,
                "video/mp4",
                OffsetDateTime.now().minusMinutes(5),
                Map.of("version", "one")
        );
        StoredObjectRecord uploaded = new StoredObjectRecord(
                "videos/input.mp4",
                5L * 1024L * 1024L,
                "video/mp4",
                OffsetDateTime.now(),
                Map.of("version", "two")
        );
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/input.mp4")).thenReturn(Optional.of(previous));
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("video/mp4"),
                eq(900),
                anyList()
        )).thenAnswer(invocation -> storageUpload("storage-upload-1", invocation.getArgument(4), 900, "create"));
        when(storageAdapter.openObject("bucket", "videos/input.mp4"))
                .thenReturn(new StoredObjectStream(previous, new ByteArrayInputStream("hello osmu".getBytes())));
        when(objectVersionRepository.save(eq("bucket"), any(ObjectVersionRecord.class)))
                .thenAnswer(invocation -> invocation.getArgument(1));
        when(storageAdapter.putObject(
                eq("bucket"),
                argThat(key -> key.startsWith(ObjectVersionStorageKeys.PREFIX)),
                any(InputStream.class),
                eq(10L),
                eq("video/mp4"),
                eq(Map.of("version", "one"))
        )).thenReturn(new StoredObjectRecord(
                ObjectVersionStorageKeys.PREFIX + "snapshot",
                10L,
                "video/mp4",
                OffsetDateTime.now(),
                Map.of("version", "one")
        ));
        when(storageAdapter.completeMultipartUpload(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("storage-upload-1"),
                anyList()
        )).thenReturn(uploaded);
        givenUploadedParts(
                "bucket",
                "videos/input.mp4",
                "storage-upload-1",
                new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L * 1024L * 1024L)
        );
        when(storageAdapter.setObjectTags("bucket", "videos/input.mp4", Map.of("version", "two")))
                .thenReturn(uploaded);

        MultipartUploadCreateResponse created = objectService.createMultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/input.mp4",
                        "video/mp4",
                        5L * 1024L * 1024L,
                        5L * 1024L * 1024L,
                        900,
                        "version=two"
                ),
                user
        );
        PresignedUploadSession session = uploadSessionRepository.findByUploadId(created.uploadId()).orElseThrow();
        StoredObjectRecord result = objectService.completeMultipartUpload(
                "bucket",
                new MultipartUploadCompleteRequest(
                        created.uploadId(),
                        "videos/input.mp4",
                        List.of(new CompletedMultipartUploadPart(1, "\"etag-1\""))
                ),
                user
        );

        assertThat(session.previousExists()).isTrue();
        assertThat(session.previousSizeBytes()).isEqualTo(10L);
        assertThat(result).isEqualTo(uploaded);
        verify(objectVersionRepository).save(eq("bucket"), any(ObjectVersionRecord.class));
        verify(bucketService).applyObjectChange("bucket", 5L * 1024L * 1024L, 1L);
        verify(objectMetadataRepository).save("bucket", uploaded);
    }

    @Test
    void completeMultipartUploadStoresValidatedChecksumMetadata() throws Exception {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        StoredObjectRecord uploaded = new StoredObjectRecord(
                "videos/checksum.mp4",
                5L,
                "video/mp4",
                OffsetDateTime.now(),
                Map.of()
        );
        String checksum = checksumBase64("SHA-256", "hello");
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/checksum.mp4")).thenReturn(Optional.empty());
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/checksum.mp4"),
                eq("video/mp4"),
                eq(900),
                anyList()
        )).thenAnswer(invocation -> storageUpload("storage-upload-checksum", invocation.getArgument(4), 900, "create"));
        when(storageAdapter.completeMultipartUpload(
                eq("bucket"),
                eq("videos/checksum.mp4"),
                eq("storage-upload-checksum"),
                anyList()
        )).thenReturn(uploaded);
        givenUploadedParts(
                "bucket",
                "videos/checksum.mp4",
                "storage-upload-checksum",
                new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L)
        );
        when(storageAdapter.openObject("bucket", "videos/checksum.mp4"))
                .thenReturn(new StoredObjectStream(uploaded, new ByteArrayInputStream("hello".getBytes(StandardCharsets.UTF_8))));

        MultipartUploadCreateResponse created = objectService.createMultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/checksum.mp4",
                        "video/mp4",
                        5L,
                        5L,
                        900,
                        ""
                ),
                user
        );
        StoredObjectRecord result = objectService.completeMultipartUpload(
                "bucket",
                new MultipartUploadCompleteRequest(
                        created.uploadId(),
                        "videos/checksum.mp4",
                        List.of(new CompletedMultipartUploadPart(1, "\"etag-1\""))
                ),
                user,
                Map.of("x-amz-checksum-sha256", checksum)
        );

        assertThat(result.checksums()).containsEntry("x-amz-checksum-sha256", checksum);
        verify(objectMetadataRepository).save(
                eq("bucket"),
                argThat(object -> checksum.equals(object.checksums().get("x-amz-checksum-sha256")))
        );
    }

    @Test
    void completeMultipartUploadStoresValidatedCrc64NvmeChecksumMetadata() throws Exception {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        StoredObjectRecord uploaded = new StoredObjectRecord(
                "videos/crc64nvme.mp4",
                9L,
                "video/mp4",
                OffsetDateTime.now(),
                Map.of()
        );
        String checksum = "rosUhgp5mIg=";
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/crc64nvme.mp4")).thenReturn(Optional.empty());
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/crc64nvme.mp4"),
                eq("video/mp4"),
                eq(900),
                anyList()
        )).thenAnswer(invocation -> storageUpload("storage-upload-crc64nvme", invocation.getArgument(4), 900, "create"));
        when(storageAdapter.completeMultipartUpload(
                eq("bucket"),
                eq("videos/crc64nvme.mp4"),
                eq("storage-upload-crc64nvme"),
                anyList()
        )).thenReturn(uploaded);
        givenUploadedParts(
                "bucket",
                "videos/crc64nvme.mp4",
                "storage-upload-crc64nvme",
                new MultipartUploadUploadedPart(1, "\"etag-1\"", 9L)
        );
        when(storageAdapter.openObject("bucket", "videos/crc64nvme.mp4"))
                .thenReturn(new StoredObjectStream(uploaded, new ByteArrayInputStream("123456789".getBytes(StandardCharsets.UTF_8))));

        MultipartUploadCreateResponse created = objectService.createMultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/crc64nvme.mp4",
                        "video/mp4",
                        9L,
                        5L,
                        900,
                        ""
                ),
                user
        );
        StoredObjectRecord result = objectService.completeMultipartUpload(
                "bucket",
                new MultipartUploadCompleteRequest(
                        created.uploadId(),
                        "videos/crc64nvme.mp4",
                        List.of(new CompletedMultipartUploadPart(1, "\"etag-1\""))
                ),
                user,
                Map.of("x-amz-checksum-crc64nvme", checksum)
        );

        assertThat(result.checksums()).containsEntry("x-amz-checksum-crc64nvme", checksum);
        verify(objectMetadataRepository).save(
                eq("bucket"),
                argThat(object -> checksum.equals(object.checksums().get("x-amz-checksum-crc64nvme")))
        );
    }

    @Test
    void completeMultipartUploadRejectsMismatchedChecksumBeforeMetadataCommit() throws Exception {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        StoredObjectRecord uploaded = new StoredObjectRecord(
                "videos/checksum-fail.mp4",
                5L,
                "video/mp4",
                OffsetDateTime.now(),
                Map.of()
        );
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/checksum-fail.mp4")).thenReturn(Optional.empty());
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/checksum-fail.mp4"),
                eq("video/mp4"),
                eq(900),
                anyList()
        )).thenAnswer(invocation -> storageUpload("storage-upload-checksum-fail", invocation.getArgument(4), 900, "create"));
        when(storageAdapter.completeMultipartUpload(
                eq("bucket"),
                eq("videos/checksum-fail.mp4"),
                eq("storage-upload-checksum-fail"),
                anyList()
        )).thenReturn(uploaded);
        givenUploadedParts(
                "bucket",
                "videos/checksum-fail.mp4",
                "storage-upload-checksum-fail",
                new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L)
        );
        when(storageAdapter.openObject("bucket", "videos/checksum-fail.mp4"))
                .thenReturn(new StoredObjectStream(uploaded, new ByteArrayInputStream("hello".getBytes(StandardCharsets.UTF_8))));

        MultipartUploadCreateResponse created = objectService.createMultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/checksum-fail.mp4",
                        "video/mp4",
                        5L,
                        5L,
                        900,
                        ""
                ),
                user
        );

        assertThatThrownBy(() -> objectService.completeMultipartUpload(
                "bucket",
                new MultipartUploadCompleteRequest(
                        created.uploadId(),
                        "videos/checksum-fail.mp4",
                        List.of(new CompletedMultipartUploadPart(1, "\"etag-1\""))
                ),
                user,
                Map.of("x-amz-checksum-sha256", checksumBase64("SHA-256", "other"))
        )).isInstanceOfSatisfying(ApiException.class, exception ->
                assertThat(exception.code()).isEqualTo(ApiErrorCode.BAD_DIGEST));

        PresignedUploadSession failedSession = uploadSessionRepository.findByUploadId(created.uploadId()).orElseThrow();
        assertThat(failedSession.status()).isEqualTo("FAILED");
        verify(storageAdapter).deleteObject("bucket", "videos/checksum-fail.mp4");
        verify(objectMetadataRepository, never()).save(eq("bucket"), any(StoredObjectRecord.class));
        verify(bucketService, never()).applyObjectChange(eq("bucket"), anyLong(), anyLong());
    }

    @Test
    void completeMultipartUploadRejectsInvalidPartChecksumBeforeStorageComplete() {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/part-checksum.mp4")).thenReturn(Optional.empty());
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/part-checksum.mp4"),
                eq("video/mp4"),
                eq(900),
                anyList()
        )).thenAnswer(invocation -> storageUpload("storage-upload-part-checksum", invocation.getArgument(4), 900, "create"));

        MultipartUploadCreateResponse created = objectService.createMultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/part-checksum.mp4",
                        "video/mp4",
                        5L,
                        5L,
                        900,
                        ""
                ),
                user
        );

        assertThatThrownBy(() -> objectService.completeMultipartUpload(
                "bucket",
                new MultipartUploadCompleteRequest(
                        created.uploadId(),
                        "videos/part-checksum.mp4",
                        List.of(new CompletedMultipartUploadPart(
                                1,
                                "\"etag-1\"",
                                Map.of("x-amz-checksum-sha256", "not-valid-base64")
                        ))
                ),
                user
        )).isInstanceOfSatisfying(ApiException.class, exception ->
                assertThat(exception.code()).isEqualTo(ApiErrorCode.INVALID_DIGEST));

        verify(storageAdapter, never()).completeMultipartUpload(
                eq("bucket"),
                eq("videos/part-checksum.mp4"),
                eq("storage-upload-part-checksum"),
                anyList()
        );
    }

    @Test
    void completeMultipartUploadRejectsMissingOrMismatchedUploadedPartBeforeStorageComplete() {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/missing-part.mp4")).thenReturn(Optional.empty());
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/missing-part.mp4"),
                eq("video/mp4"),
                eq(900),
                anyList()
        )).thenAnswer(invocation -> storageUpload("storage-upload-missing-part", invocation.getArgument(4), 900, "create"));

        MultipartUploadCreateResponse created = objectService.createMultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/missing-part.mp4",
                        "video/mp4",
                        10L,
                        5L,
                        900,
                        ""
                ),
                user
        );
        givenUploadedParts(
                "bucket",
                "videos/missing-part.mp4",
                "storage-upload-missing-part",
                new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L)
        );

        assertThatThrownBy(() -> objectService.completeMultipartUpload(
                "bucket",
                new MultipartUploadCompleteRequest(
                        created.uploadId(),
                        "videos/missing-part.mp4",
                        List.of(
                                new CompletedMultipartUploadPart(1, "\"etag-1\""),
                                new CompletedMultipartUploadPart(2, "\"etag-2\"")
                        )
                ),
                user
        )).isInstanceOfSatisfying(ApiException.class, exception -> {
            assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR);
            assertThat(exception.getMessage()).contains("part 2 has not been uploaded");
        });

        assertThatThrownBy(() -> objectService.completeMultipartUpload(
                "bucket",
                new MultipartUploadCompleteRequest(
                        created.uploadId(),
                        "videos/missing-part.mp4",
                        List.of(new CompletedMultipartUploadPart(1, "\"other-etag\""))
                ),
                user
        )).isInstanceOfSatisfying(ApiException.class, exception -> {
            assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR);
            assertThat(exception.getMessage()).contains("ETag does not match");
        });

        PresignedUploadSession session = uploadSessionRepository.findByUploadId(created.uploadId()).orElseThrow();
        assertThat(session.status()).isEqualTo("ACTIVE");
        verify(storageAdapter, never()).completeMultipartUpload(
                eq("bucket"),
                eq("videos/missing-part.mp4"),
                eq("storage-upload-missing-part"),
                anyList()
        );
        verify(bucketService, never()).applyObjectChange(eq("bucket"), anyLong(), anyLong());
    }

    @Test
    void refreshMultipartUploadReturnsFreshPartUrlsFromStoredPartPlan() {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/input.mp4")).thenReturn(Optional.empty());
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("video/mp4"),
                eq(900),
                anyList()
        )).thenAnswer(invocation -> storageUpload("storage-upload-1", invocation.getArgument(4), 900, "create"));
        when(storageAdapter.refreshMultipartUploadParts(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("storage-upload-1"),
                eq(300),
                anyList()
        )).thenAnswer(invocation -> storageUpload("storage-upload-1", invocation.getArgument(4), 300, "refresh"));

        MultipartUploadCreateResponse created = objectService.createMultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/input.mp4",
                        "video/mp4",
                        13L * 1024L * 1024L,
                        5L * 1024L * 1024L,
                        900,
                        "project=osmu"
                ),
                user
        );
        MultipartUploadCreateResponse refreshed = objectService.refreshMultipartUpload(
                "bucket",
                new MultipartUploadRefreshRequest(created.uploadId(), "videos/input.mp4", 300),
                user
        );

        PresignedUploadSession session = uploadSessionRepository.findByUploadId(created.uploadId()).orElseThrow();
        assertThat(session.partSizeBytes()).isEqualTo(5L * 1024L * 1024L);
        assertThat(session.partCount()).isEqualTo(3);
        assertThat(refreshed.uploadId()).isEqualTo(created.uploadId());
        assertThat(refreshed.partSizeBytes()).isEqualTo(5L * 1024L * 1024L);
        assertThat(refreshed.partCount()).isEqualTo(3);
        assertThat(refreshed.expiresInSeconds()).isEqualTo(300);
        assertThat(refreshed.expiresAt()).isEqualTo(created.expiresAt());
        assertThat(refreshed.parts()).extracting(MultipartUploadPartUrl::url)
                .containsExactly("https://storage/refresh/1", "https://storage/refresh/2", "https://storage/refresh/3");
        assertThat(refreshed.parts().get(0).startByte()).isZero();
        assertThat(refreshed.parts().get(0).endByte()).isEqualTo(5242879L);
        assertThat(refreshed.parts().get(2).startByte()).isEqualTo(10485760L);
        assertThat(refreshed.parts().get(2).endByte()).isEqualTo(13631487L);
        verify(storageAdapter).refreshMultipartUploadParts(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("storage-upload-1"),
                eq(300),
                eq(List.of(1, 2, 3))
        );
    }

    @Test
    void listMultipartUploadPartsReturnsStorageUploadedParts() {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/input.mp4")).thenReturn(Optional.empty());
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("video/mp4"),
                eq(900),
                anyList()
        )).thenAnswer(invocation -> storageUpload("storage-upload-1", invocation.getArgument(4), 900, "create"));
        when(storageAdapter.listMultipartUploadParts("bucket", "videos/input.mp4", "storage-upload-1"))
                .thenReturn(List.of(
                        new MultipartUploadUploadedPart(1, "\"etag-1\"", 5242880L),
                        new MultipartUploadUploadedPart(2, "\"etag-2\"", 5242880L)
                ));

        MultipartUploadCreateResponse created = objectService.createMultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/input.mp4",
                        "video/mp4",
                        13L * 1024L * 1024L,
                        5L * 1024L * 1024L,
                        900,
                        "project=osmu"
                ),
                user
        );
        MultipartUploadPartsResponse response = objectService.listMultipartUploadParts(
                "bucket",
                new MultipartUploadPartsRequest(created.uploadId(), "videos/input.mp4"),
                user
        );

        assertThat(response.uploadId()).isEqualTo(created.uploadId());
        assertThat(response.partCount()).isEqualTo(3);
        assertThat(response.parts()).extracting(MultipartUploadUploadedPart::partNumber)
                .containsExactly(1, 2);
        assertThat(response.parts()).extracting(MultipartUploadUploadedPart::etag)
                .containsExactly("\"etag-1\"", "\"etag-2\"");
        verify(storageAdapter).listMultipartUploadParts("bucket", "videos/input.mp4", "storage-upload-1");
    }

    @Test
    void s3MultipartUploadCanStartWithoutExpectedSizeAndCompleteWithActualSize() {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        StoredObjectRecord uploaded = new StoredObjectRecord(
                "videos/unknown.mp4",
                5L,
                "video/mp4",
                OffsetDateTime.now(),
                Map.of()
        );
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/unknown.mp4")).thenReturn(Optional.empty());
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/unknown.mp4"),
                eq("video/mp4"),
                eq(900),
                eq(List.of())
        )).thenReturn(storageUpload("storage-upload-unknown", List.of(), 900, "create"));
        when(storageAdapter.uploadMultipartUploadPart(
                eq("bucket"),
                eq("videos/unknown.mp4"),
                eq("storage-upload-unknown"),
                eq(1),
                any(InputStream.class),
                eq(5L)
        )).thenReturn(new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L));
        givenUploadedParts(
                "bucket",
                "videos/unknown.mp4",
                "storage-upload-unknown",
                new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L)
        );
        when(storageAdapter.completeMultipartUpload(
                eq("bucket"),
                eq("videos/unknown.mp4"),
                eq("storage-upload-unknown"),
                anyList()
        )).thenReturn(uploaded);

        MultipartUploadCreateResponse created = objectService.createS3MultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/unknown.mp4",
                        "video/mp4",
                        null,
                        null,
                        900,
                        ""
                ),
                user
        );
        MultipartUploadUploadedPart part = objectService.uploadMultipartPart(
                "bucket",
                "videos/unknown.mp4",
                created.uploadId(),
                1,
                new ByteArrayInputStream("hello".getBytes(StandardCharsets.UTF_8)),
                5L,
                user
        );
        MultipartUploadPartsResponse parts = objectService.listMultipartUploadParts(
                "bucket",
                new MultipartUploadPartsRequest(created.uploadId(), "videos/unknown.mp4"),
                user
        );
        StoredObjectRecord result = objectService.completeMultipartUpload(
                "bucket",
                new MultipartUploadCompleteRequest(
                        created.uploadId(),
                        "videos/unknown.mp4",
                        List.of(new CompletedMultipartUploadPart(1, "\"etag-1\""))
                ),
                user
        );

        PresignedUploadSession session = uploadSessionRepository.findByUploadId(created.uploadId()).orElseThrow();
        assertThat(created.sizeBytes()).isZero();
        assertThat(created.partSizeBytes()).isZero();
        assertThat(created.partCount()).isZero();
        assertThat(created.parts()).isEmpty();
        assertThat(session.expectedSizeBytes()).isZero();
        assertThat(session.partCount()).isZero();
        assertThat(part.etag()).isEqualTo("\"etag-1\"");
        assertThat(parts.parts()).extracting(MultipartUploadUploadedPart::partNumber).containsExactly(1);
        assertThat(result).isEqualTo(uploaded);
        verify(bucketService).assertObjectChangeAllowed("bucket", 5L, 1L);
        verify(bucketService).applyObjectChange("bucket", 5L, 1L);
        verify(objectMetadataRepository).save("bucket", uploaded);
    }

    @Test
    void s3MultipartUnknownSizeCompleteRollsBackCompletedObjectOnQuotaFailure() {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        StoredObjectRecord uploaded = new StoredObjectRecord(
                "videos/quota.mp4",
                7L,
                "video/mp4",
                OffsetDateTime.now(),
                Map.of()
        );
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/quota.mp4")).thenReturn(Optional.empty());
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/quota.mp4"),
                eq("video/mp4"),
                eq(900),
                eq(List.of())
        )).thenReturn(storageUpload("storage-upload-quota", List.of(), 900, "create"));
        givenUploadedParts(
                "bucket",
                "videos/quota.mp4",
                "storage-upload-quota",
                new MultipartUploadUploadedPart(1, "\"etag-1\"", 7L)
        );
        when(storageAdapter.completeMultipartUpload(
                eq("bucket"),
                eq("videos/quota.mp4"),
                eq("storage-upload-quota"),
                anyList()
        )).thenReturn(uploaded);
        when(storageAdapter.deleteObject("bucket", "videos/quota.mp4")).thenReturn(uploaded);
        doThrow(new ApiException(ApiErrorCode.QUOTA_EXCEEDED, "Bucket quota exceeded."))
                .when(bucketService).assertObjectChangeAllowed("bucket", 7L, 1L);

        MultipartUploadCreateResponse created = objectService.createS3MultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/quota.mp4",
                        "video/mp4",
                        null,
                        null,
                        900,
                        ""
                ),
                user
        );

        assertThatThrownBy(() -> objectService.completeMultipartUpload(
                "bucket",
                new MultipartUploadCompleteRequest(
                        created.uploadId(),
                        "videos/quota.mp4",
                        List.of(new CompletedMultipartUploadPart(1, "\"etag-1\""))
                ),
                user
        )).isInstanceOfSatisfying(ApiException.class, exception ->
                assertThat(exception.code()).isEqualTo(ApiErrorCode.QUOTA_EXCEEDED));

        PresignedUploadSession failedSession = uploadSessionRepository.findByUploadId(created.uploadId()).orElseThrow();
        assertThat(failedSession.status()).isEqualTo("FAILED");
        verify(storageAdapter).deleteObject("bucket", "videos/quota.mp4");
        verify(objectMetadataRepository, never()).save(eq("bucket"), any(StoredObjectRecord.class));
        verify(bucketService, never()).applyObjectChange(eq("bucket"), anyLong(), anyLong());
    }

    @Test
    void uploadMultipartPartValidatesSessionAndDelegatesToStorage() {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        when(storageAdapter.statObject("bucket", "videos/input.mp4")).thenReturn(Optional.empty());
        when(storageAdapter.createMultipartUpload(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("video/mp4"),
                eq(900),
                anyList()
        )).thenAnswer(invocation -> storageUpload("storage-upload-1", invocation.getArgument(4), 900, "create"));
        when(storageAdapter.uploadMultipartUploadPart(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("storage-upload-1"),
                eq(1),
                any(InputStream.class),
                eq(5L)
        )).thenReturn(new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L));

        MultipartUploadCreateResponse created = objectService.createMultipartUpload(
                "bucket",
                new MultipartUploadCreateRequest(
                        "videos/input.mp4",
                        "video/mp4",
                        5L * 1024L * 1024L,
                        5L * 1024L * 1024L,
                        900,
                        "project=osmu"
                ),
                user
        );
        MultipartUploadUploadedPart part = objectService.uploadMultipartPart(
                "bucket",
                "videos/input.mp4",
                created.uploadId(),
                1,
                new ByteArrayInputStream("hello".getBytes()),
                5L,
                user
        );

        assertThat(part.etag()).isEqualTo("\"etag-1\"");
        verify(storageAdapter).uploadMultipartUploadPart(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("storage-upload-1"),
                eq(1),
                any(InputStream.class),
                eq(5L)
        );
    }

    @Test
    void listActiveMultipartUploadsReturnsTruncatedPage() {
        BucketRecord bucket = new BucketRecord(1L, "bucket", "USER", 1L, 1000000000L, 0L, 0L, OffsetDateTime.now());
        OffsetDateTime now = OffsetDateTime.now();
        when(bucketService.get("bucket", user)).thenReturn(bucket);
        uploadSessionRepository.save(session("upload-a", "docs/a.txt", now));
        uploadSessionRepository.save(session("upload-b", "docs/b.txt", now.plusSeconds(1)));

        MultipartUploadListResponse response = objectService.listActiveMultipartUploads(
                "bucket",
                "docs/",
                "",
                "",
                1,
                user
        );

        assertThat(response.truncated()).isTrue();
        assertThat(response.uploads()).extracting(MultipartUploadListItem::uploadId)
                .containsExactly("upload-a");
        assertThat(response.nextKeyMarker()).isEqualTo("docs/a.txt");
        assertThat(response.nextUploadIdMarker()).isEqualTo("upload-a");
    }

    private StorageMultipartUpload storageUpload(
            String storageUploadId,
            List<Integer> partNumbers,
            int expiresInSeconds,
            String marker
    ) {
        return new StorageMultipartUpload(
                storageUploadId,
                partNumbers.stream()
                        .map(partNumber -> new MultipartUploadPartUrl(
                                partNumber,
                                "https://storage/" + marker + "/" + partNumber,
                                "PUT",
                                expiresInSeconds,
                                0L,
                                0L
                        ))
                        .toList()
        );
    }

    private void givenUploadedParts(
            String bucketName,
            String objectKey,
            String storageUploadId,
            MultipartUploadUploadedPart... parts
    ) {
        when(storageAdapter.listMultipartUploadParts(bucketName, objectKey, storageUploadId))
                .thenReturn(List.of(parts));
    }

    private PresignedUploadSession session(String uploadId, String key, OffsetDateTime createdAt) {
        return new PresignedUploadSession(
                uploadId,
                1L,
                "bucket",
                key,
                "project=osmu",
                "MULTIPART",
                "storage-" + uploadId,
                10485760L,
                5242880L,
                2,
                "ACTIVE",
                0L,
                false,
                createdAt.plusMinutes(15),
                createdAt,
                null
        );
    }

    private String checksumBase64(String algorithm, String value) throws Exception {
        return Base64.getEncoder().encodeToString(MessageDigest.getInstance(algorithm).digest(value.getBytes(StandardCharsets.UTF_8)));
    }
}
