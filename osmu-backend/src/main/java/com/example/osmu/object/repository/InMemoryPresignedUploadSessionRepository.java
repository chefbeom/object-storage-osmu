package com.example.osmu.object.repository;

import com.example.osmu.object.PresignedUploadSession;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryPresignedUploadSessionRepository implements PresignedUploadSessionRepository {

    private final ConcurrentMap<String, PresignedUploadSession> sessions = new ConcurrentHashMap<>();

    @Override
    public Optional<PresignedUploadSession> findByUploadId(String uploadId) {
        return Optional.ofNullable(sessions.get(uploadId));
    }

    @Override
    public PresignedUploadSession save(PresignedUploadSession session) {
        sessions.put(session.uploadId(), session);
        return session;
    }

    @Override
    public void updateStatus(String uploadId, String status, OffsetDateTime completedAt) {
        sessions.computeIfPresent(uploadId, (key, session) -> new PresignedUploadSession(
                session.uploadId(),
                session.userId(),
                session.bucketName(),
                session.objectKey(),
                session.tags(),
                session.uploadMode(),
                session.storageUploadId(),
                session.expectedSizeBytes(),
                session.partSizeBytes(),
                session.partCount(),
                status,
                session.previousSizeBytes(),
                session.previousExists(),
                session.expiresAt(),
                session.createdAt(),
                completedAt
        ));
    }

    @Override
    public boolean updateStatusIfCurrent(
            String uploadId,
            String currentStatus,
            String status,
            OffsetDateTime completedAt
    ) {
        AtomicBoolean updated = new AtomicBoolean(false);
        sessions.computeIfPresent(uploadId, (key, session) -> {
            if (!currentStatus.equals(session.status())) {
                return session;
            }
            updated.set(true);
            return new PresignedUploadSession(
                    session.uploadId(),
                    session.userId(),
                    session.bucketName(),
                    session.objectKey(),
                    session.tags(),
                    session.uploadMode(),
                    session.storageUploadId(),
                    session.expectedSizeBytes(),
                    session.partSizeBytes(),
                    session.partCount(),
                    status,
                    session.previousSizeBytes(),
                    session.previousExists(),
                    session.expiresAt(),
                    session.createdAt(),
                    completedAt
            );
        });
        return updated.get();
    }

    @Override
    public List<PresignedUploadSession> findExpiredActiveMultipartUploads(OffsetDateTime now, int limit) {
        return sessions.values().stream()
                .filter(session -> "ACTIVE".equals(session.status()))
                .filter(session -> "MULTIPART".equals(session.uploadMode()))
                .filter(session -> !isBlank(session.storageUploadId()))
                .filter(session -> !session.expiresAt().isAfter(now))
                .sorted(Comparator.comparing(PresignedUploadSession::expiresAt))
                .limit(Math.max(0, limit))
                .toList();
    }

    @Override
    public List<PresignedUploadSession> findActiveMultipartUploads(
            String bucketName,
            String prefix,
            String keyMarker,
            String uploadIdMarker,
            int limit
    ) {
        String normalizedPrefix = prefix == null ? "" : prefix;
        String normalizedKeyMarker = keyMarker == null ? "" : keyMarker;
        String normalizedUploadIdMarker = uploadIdMarker == null ? "" : uploadIdMarker;
        return sessions.values().stream()
                .filter(session -> bucketName.equals(session.bucketName()))
                .filter(session -> "ACTIVE".equals(session.status()))
                .filter(session -> "MULTIPART".equals(session.uploadMode()))
                .filter(session -> !isBlank(session.storageUploadId()))
                .filter(session -> session.objectKey().startsWith(normalizedPrefix))
                .filter(session -> afterMarker(session, normalizedKeyMarker, normalizedUploadIdMarker))
                .sorted(Comparator.comparing(PresignedUploadSession::objectKey)
                        .thenComparing(PresignedUploadSession::uploadId))
                .limit(Math.max(0, limit))
                .toList();
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private boolean afterMarker(PresignedUploadSession session, String keyMarker, String uploadIdMarker) {
        if (keyMarker.isBlank()) {
            return true;
        }
        int keyComparison = session.objectKey().compareTo(keyMarker);
        if (keyComparison > 0) {
            return true;
        }
        return keyComparison == 0 && !uploadIdMarker.isBlank() && session.uploadId().compareTo(uploadIdMarker) > 0;
    }
}
