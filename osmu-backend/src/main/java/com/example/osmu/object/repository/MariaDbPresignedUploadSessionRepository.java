package com.example.osmu.object.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.PresignedUploadSession;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbPresignedUploadSessionRepository implements PresignedUploadSessionRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbPresignedUploadSessionRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public Optional<PresignedUploadSession> findByUploadId(String uploadId) {
        ensureSchema();
        String sql = """
                SELECT upload_id, user_id, bucket_name, object_key, tags, upload_mode, storage_upload_id,
                       checksum_algorithm, checksum_type,
                       expected_size_bytes, part_size_bytes, part_count, status, previous_size_bytes,
                       previous_exists, expires_at, created_at, completed_at
                FROM presigned_upload_sessions
                WHERE upload_id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, uploadId);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    return Optional.of(mapRow(resultSet));
                }
                return Optional.empty();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<PresignedUploadSession> findActiveMultipartUploads(
            String bucketName,
            String prefix,
            String keyMarker,
            String uploadIdMarker,
            int limit
    ) {
        ensureSchema();
        String sql = """
                SELECT upload_id, user_id, bucket_name, object_key, tags, upload_mode, storage_upload_id,
                       checksum_algorithm, checksum_type,
                       expected_size_bytes, part_size_bytes, part_count, status, previous_size_bytes,
                       previous_exists, expires_at, created_at, completed_at
                FROM presigned_upload_sessions
                WHERE bucket_name = ?
                  AND status = 'ACTIVE'
                  AND upload_mode = 'MULTIPART'
                  AND storage_upload_id IS NOT NULL
                  AND storage_upload_id <> ''
                  AND object_key LIKE ? ESCAPE '\\\\'
                  AND (? = '' OR object_key > ? OR (object_key = ? AND ? <> '' AND upload_id > ?))
                ORDER BY object_key ASC, upload_id ASC
                LIMIT ?
                """;
        String normalizedKeyMarker = keyMarker == null ? "" : keyMarker;
        String normalizedUploadIdMarker = uploadIdMarker == null ? "" : uploadIdMarker;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            statement.setString(2, escapeLike(prefix == null ? "" : prefix) + "%");
            statement.setString(3, normalizedKeyMarker);
            statement.setString(4, normalizedKeyMarker);
            statement.setString(5, normalizedKeyMarker);
            statement.setString(6, normalizedUploadIdMarker);
            statement.setString(7, normalizedUploadIdMarker);
            statement.setInt(8, Math.max(0, limit));
            try (ResultSet resultSet = statement.executeQuery()) {
                List<PresignedUploadSession> sessions = new ArrayList<>();
                while (resultSet.next()) {
                    sessions.add(mapRow(resultSet));
                }
                return sessions;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public PresignedUploadSession save(PresignedUploadSession session) {
        ensureSchema();
        String sql = """
                INSERT INTO presigned_upload_sessions
                    (upload_id, user_id, bucket_name, object_key, tags, upload_mode, storage_upload_id,
                     checksum_algorithm, checksum_type,
                     expected_size_bytes, part_size_bytes, part_count, status, previous_size_bytes,
                     previous_exists, expires_at, created_at, completed_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, session.uploadId());
            statement.setLong(2, session.userId());
            statement.setString(3, session.bucketName());
            statement.setString(4, session.objectKey());
            statement.setString(5, session.tags());
            statement.setString(6, session.uploadMode());
            statement.setString(7, session.storageUploadId());
            statement.setString(8, session.checksumAlgorithm());
            statement.setString(9, session.checksumType());
            statement.setLong(10, session.expectedSizeBytes());
            statement.setLong(11, session.partSizeBytes());
            statement.setInt(12, session.partCount());
            statement.setString(13, session.status());
            statement.setLong(14, session.previousSizeBytes());
            statement.setBoolean(15, session.previousExists());
            statement.setTimestamp(16, Timestamp.from(session.expiresAt().toInstant()));
            statement.setTimestamp(17, Timestamp.from(session.createdAt().toInstant()));
            statement.setTimestamp(18, timestampOrNull(session.completedAt()));
            statement.executeUpdate();
            return session;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void updateStatus(String uploadId, String status, OffsetDateTime completedAt) {
        ensureSchema();
        String sql = """
                UPDATE presigned_upload_sessions
                SET status = ?, completed_at = ?
                WHERE upload_id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);
            statement.setTimestamp(2, timestampOrNull(completedAt));
            statement.setString(3, uploadId);
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public boolean updateStatusIfCurrent(
            String uploadId,
            String currentStatus,
            String status,
            OffsetDateTime completedAt
    ) {
        ensureSchema();
        String sql = """
                UPDATE presigned_upload_sessions
                SET status = ?, completed_at = ?
                WHERE upload_id = ? AND status = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);
            statement.setTimestamp(2, timestampOrNull(completedAt));
            statement.setString(3, uploadId);
            statement.setString(4, currentStatus);
            return statement.executeUpdate() > 0;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<PresignedUploadSession> findExpiredActiveMultipartUploads(OffsetDateTime now, int limit) {
        ensureSchema();
        String sql = """
                SELECT upload_id, user_id, bucket_name, object_key, tags, upload_mode, storage_upload_id,
                       checksum_algorithm, checksum_type,
                       expected_size_bytes, part_size_bytes, part_count, status, previous_size_bytes,
                       previous_exists, expires_at, created_at, completed_at
                FROM presigned_upload_sessions
                WHERE status = 'ACTIVE'
                  AND upload_mode = 'MULTIPART'
                  AND storage_upload_id IS NOT NULL
                  AND storage_upload_id <> ''
                  AND expires_at <= ?
                ORDER BY expires_at ASC
                LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setTimestamp(1, Timestamp.from(now.toInstant()));
            statement.setInt(2, Math.max(0, limit));
            try (ResultSet resultSet = statement.executeQuery()) {
                List<PresignedUploadSession> sessions = new ArrayList<>();
                while (resultSet.next()) {
                    sessions.add(mapRow(resultSet));
                }
                return sessions;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public boolean isHealthy() {
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement("SELECT 1");
             ResultSet resultSet = statement.executeQuery()) {
            return resultSet.next();
        } catch (SQLException exception) {
            return false;
        }
    }

    private synchronized void ensureSchema() {
        if (schemaReady) {
            return;
        }

        String sql = """
                CREATE TABLE IF NOT EXISTS presigned_upload_sessions (
                    upload_id VARCHAR(64) NOT NULL PRIMARY KEY,
                    user_id BIGINT NOT NULL,
                    bucket_name VARCHAR(63) NOT NULL,
                    object_key VARCHAR(1024) NOT NULL,
                    tags TEXT NULL,
                    upload_mode VARCHAR(32) NOT NULL DEFAULT 'PRESIGNED_PUT',
                    storage_upload_id TEXT NULL,
                    checksum_algorithm VARCHAR(32) NOT NULL DEFAULT '',
                    checksum_type VARCHAR(32) NOT NULL DEFAULT '',
                    expected_size_bytes BIGINT NOT NULL DEFAULT 0,
                    part_size_bytes BIGINT NOT NULL DEFAULT 0,
                    part_count INT NOT NULL DEFAULT 0,
                    status VARCHAR(32) NOT NULL,
                    previous_size_bytes BIGINT NOT NULL,
                    previous_exists BOOLEAN NOT NULL,
                    expires_at TIMESTAMP NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    completed_at TIMESTAMP NULL,
                    INDEX idx_presigned_upload_sessions_user_id (user_id),
                    INDEX idx_presigned_upload_sessions_status (status),
                    INDEX idx_presigned_upload_sessions_expires_at (expires_at)
                )
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
            executeUpdate(connection, "ALTER TABLE presigned_upload_sessions ADD COLUMN IF NOT EXISTS checksum_algorithm VARCHAR(32) NOT NULL DEFAULT '' AFTER storage_upload_id");
            executeUpdate(connection, "ALTER TABLE presigned_upload_sessions ADD COLUMN IF NOT EXISTS checksum_type VARCHAR(32) NOT NULL DEFAULT '' AFTER checksum_algorithm");
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private void executeUpdate(Connection connection, String sql) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
        }
    }

    private PresignedUploadSession mapRow(ResultSet resultSet) throws SQLException {
        return new PresignedUploadSession(
                resultSet.getString("upload_id"),
                resultSet.getLong("user_id"),
                resultSet.getString("bucket_name"),
                resultSet.getString("object_key"),
                resultSet.getString("tags"),
                resultSet.getString("upload_mode"),
                resultSet.getString("storage_upload_id"),
                resultSet.getString("checksum_algorithm"),
                resultSet.getString("checksum_type"),
                resultSet.getLong("expected_size_bytes"),
                resultSet.getLong("part_size_bytes"),
                resultSet.getInt("part_count"),
                resultSet.getString("status"),
                resultSet.getLong("previous_size_bytes"),
                resultSet.getBoolean("previous_exists"),
                resultSet.getTimestamp("expires_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                offsetDateTimeOrNull(resultSet.getTimestamp("completed_at"))
        );
    }

    private Timestamp timestampOrNull(OffsetDateTime value) {
        return value == null ? null : Timestamp.from(value.toInstant());
    }

    private OffsetDateTime offsetDateTimeOrNull(Timestamp value) {
        return value == null ? null : value.toInstant().atOffset(ZoneOffset.UTC);
    }

    private String escapeLike(String value) {
        return value
                .replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_");
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
