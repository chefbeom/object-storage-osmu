package com.example.osmu.object.repository;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.object.PresignedUploadSession;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class InMemoryPresignedUploadSessionRepositoryTest {

    private final InMemoryPresignedUploadSessionRepository repository = new InMemoryPresignedUploadSessionRepository();

    @Test
    void updateStatusPreservesTags() {
        OffsetDateTime now = OffsetDateTime.now();
        PresignedUploadSession session = new PresignedUploadSession(
                "upload-1",
                1L,
                "bucket",
                "videos/input.mp4",
                "project=osmu,stage=raw",
                "MULTIPART",
                "storage-upload-1",
                10485760L,
                5242880L,
                2,
                "ACTIVE",
                0L,
                false,
                now.plusMinutes(15),
                now,
                null
        );

        repository.save(session);
        repository.updateStatus("upload-1", "COMPLETED", now.plusMinutes(1));

        PresignedUploadSession saved = repository.findByUploadId("upload-1").orElseThrow();
        assertThat(saved.tags()).isEqualTo("project=osmu,stage=raw");
        assertThat(saved.uploadMode()).isEqualTo("MULTIPART");
        assertThat(saved.storageUploadId()).isEqualTo("storage-upload-1");
        assertThat(saved.expectedSizeBytes()).isEqualTo(10485760L);
        assertThat(saved.partSizeBytes()).isEqualTo(5242880L);
        assertThat(saved.partCount()).isEqualTo(2);
        assertThat(saved.status()).isEqualTo("COMPLETED");

        repository.updateStatus("upload-1", "ABORTED", now.plusMinutes(2));
        PresignedUploadSession aborted = repository.findByUploadId("upload-1").orElseThrow();
        assertThat(aborted.tags()).isEqualTo("project=osmu,stage=raw");
        assertThat(aborted.uploadMode()).isEqualTo("MULTIPART");
        assertThat(aborted.storageUploadId()).isEqualTo("storage-upload-1");
        assertThat(aborted.expectedSizeBytes()).isEqualTo(10485760L);
        assertThat(aborted.partSizeBytes()).isEqualTo(5242880L);
        assertThat(aborted.partCount()).isEqualTo(2);
        assertThat(aborted.status()).isEqualTo("ABORTED");
    }

    @Test
    void findExpiredActiveMultipartUploadsOnlyReturnsCleanupTargets() {
        OffsetDateTime now = OffsetDateTime.now();
        PresignedUploadSession expiredActiveMultipart = session(
                "expired-active-multipart",
                "MULTIPART",
                "storage-upload-1",
                "ACTIVE",
                now.minusSeconds(1)
        );
        repository.save(expiredActiveMultipart);
        repository.save(session("future-active-multipart", "MULTIPART", "storage-upload-2", "ACTIVE", now.plusMinutes(1)));
        repository.save(session("expired-completed-multipart", "MULTIPART", "storage-upload-3", "COMPLETED", now.minusSeconds(1)));
        repository.save(session("expired-active-presigned", "PRESIGNED_PUT", null, "ACTIVE", now.minusSeconds(1)));
        repository.save(session("expired-active-multipart-without-storage-id", "MULTIPART", "", "ACTIVE", now.minusSeconds(1)));

        assertThat(repository.findExpiredActiveMultipartUploads(now, 100))
                .extracting(PresignedUploadSession::uploadId)
                .containsExactly("expired-active-multipart");
    }

    @Test
    void updateStatusIfCurrentDoesNotOverwriteDifferentStatus() {
        OffsetDateTime now = OffsetDateTime.now();
        repository.save(session("upload-2", "MULTIPART", "storage-upload-1", "COMPLETED", now.minusSeconds(1)));

        boolean updated = repository.updateStatusIfCurrent("upload-2", "ACTIVE", "EXPIRED", now);

        assertThat(updated).isFalse();
        assertThat(repository.findByUploadId("upload-2").orElseThrow().status()).isEqualTo("COMPLETED");
    }

    @Test
    void findActiveMultipartUploadsFiltersByBucketPrefixAndMarker() {
        OffsetDateTime now = OffsetDateTime.now();
        repository.save(session("upload-a", "bucket", "docs/a.txt", "MULTIPART", "storage-a", "ACTIVE", now.plusMinutes(10)));
        repository.save(session("upload-b", "bucket", "docs/b.txt", "MULTIPART", "storage-b", "ACTIVE", now.plusMinutes(10)));
        repository.save(session("upload-c", "bucket", "images/c.txt", "MULTIPART", "storage-c", "ACTIVE", now.plusMinutes(10)));
        repository.save(session("upload-d", "other", "docs/d.txt", "MULTIPART", "storage-d", "ACTIVE", now.plusMinutes(10)));
        repository.save(session("upload-e", "bucket", "docs/e.txt", "PRESIGNED_PUT", "storage-e", "ACTIVE", now.plusMinutes(10)));
        repository.save(session("upload-f", "bucket", "docs/f.txt", "MULTIPART", "storage-f", "COMPLETED", now.plusMinutes(10)));

        assertThat(repository.findActiveMultipartUploads("bucket", "docs/", "", "", 10))
                .extracting(PresignedUploadSession::uploadId)
                .containsExactly("upload-a", "upload-b");

        assertThat(repository.findActiveMultipartUploads("bucket", "docs/", "docs/a.txt", "upload-a", 10))
                .extracting(PresignedUploadSession::uploadId)
                .containsExactly("upload-b");
    }

    private PresignedUploadSession session(
            String uploadId,
            String uploadMode,
            String storageUploadId,
            String status,
            OffsetDateTime expiresAt
    ) {
        OffsetDateTime createdAt = expiresAt.minusMinutes(15);
        return new PresignedUploadSession(
                uploadId,
                1L,
                "bucket",
                "videos/input.mp4",
                "project=osmu,stage=raw",
                uploadMode,
                storageUploadId,
                10485760L,
                5242880L,
                2,
                status,
                0L,
                false,
                expiresAt,
                createdAt,
                null
        );
    }

    private PresignedUploadSession session(
            String uploadId,
            String bucketName,
            String objectKey,
            String uploadMode,
            String storageUploadId,
            String status,
            OffsetDateTime expiresAt
    ) {
        OffsetDateTime createdAt = expiresAt.minusMinutes(15);
        return new PresignedUploadSession(
                uploadId,
                1L,
                bucketName,
                objectKey,
                "project=osmu,stage=raw",
                uploadMode,
                storageUploadId,
                10485760L,
                5242880L,
                2,
                status,
                0L,
                false,
                expiresAt,
                createdAt,
                null
        );
    }
}
