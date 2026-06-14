package com.example.osmu.object.repository;

import com.example.osmu.object.PresignedUploadSession;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface PresignedUploadSessionRepository {

    Optional<PresignedUploadSession> findByUploadId(String uploadId);

    PresignedUploadSession save(PresignedUploadSession session);

    void updateStatus(String uploadId, String status, OffsetDateTime completedAt);

    boolean updateStatusIfCurrent(String uploadId, String currentStatus, String status, OffsetDateTime completedAt);

    List<PresignedUploadSession> findExpiredActiveMultipartUploads(OffsetDateTime now, int limit);

    List<PresignedUploadSession> findActiveMultipartUploads(
            String bucketName,
            String prefix,
            String keyMarker,
            String uploadIdMarker,
            int limit
    );

    boolean isHealthy();
}
