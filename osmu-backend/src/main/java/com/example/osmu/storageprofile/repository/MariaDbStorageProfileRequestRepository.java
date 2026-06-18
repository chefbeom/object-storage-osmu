package com.example.osmu.storageprofile.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storageprofile.StorageProfileRequestRecord;
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
public class MariaDbStorageProfileRequestRepository implements StorageProfileRequestRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbStorageProfileRequestRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<StorageProfileRequestRecord> findAll() {
        ensureSchema();
        String sql = selectSql() + " ORDER BY id DESC";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            return collect(resultSet);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<StorageProfileRequestRecord> findByBucketName(String bucketName) {
        ensureSchema();
        String sql = selectSql() + " WHERE bucket_name = ? ORDER BY id DESC";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            try (ResultSet resultSet = statement.executeQuery()) {
                return collect(resultSet);
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<StorageProfileRequestRecord> findLatestByBucketName(String bucketName) {
        ensureSchema();
        String sql = selectSql() + " WHERE bucket_name = ? ORDER BY id DESC LIMIT 1";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
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
    public Optional<StorageProfileRequestRecord> findById(long id) {
        ensureSchema();
        String sql = selectSql() + " WHERE id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
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
    public long nextId() {
        ensureSchema();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement("SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM storage_profile_requests");
             ResultSet resultSet = statement.executeQuery()) {
            if (resultSet.next()) {
                return resultSet.getLong("next_id");
            }
            return 1L;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public StorageProfileRequestRecord save(StorageProfileRequestRecord request) {
        ensureSchema();
        String sql = """
                INSERT INTO storage_profile_requests
                    (id, bucket_name, current_profile_code, requested_profile_code, status, reason,
                     requested_by, approved_by, approved_at, applied_by, applied_at, admin_note,
                     created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    current_profile_code = VALUES(current_profile_code),
                    requested_profile_code = VALUES(requested_profile_code),
                    status = VALUES(status),
                    reason = VALUES(reason),
                    approved_by = VALUES(approved_by),
                    approved_at = VALUES(approved_at),
                    applied_by = VALUES(applied_by),
                    applied_at = VALUES(applied_at),
                    admin_note = VALUES(admin_note),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, request.id());
            statement.setString(2, request.bucketName());
            statement.setString(3, request.currentProfileCode());
            statement.setString(4, request.requestedProfileCode());
            statement.setString(5, request.status());
            statement.setString(6, request.reason());
            statement.setString(7, request.requestedBy());
            statement.setString(8, request.approvedBy());
            statement.setTimestamp(9, timestamp(request.approvedAt()));
            statement.setString(10, request.appliedBy());
            statement.setTimestamp(11, timestamp(request.appliedAt()));
            statement.setString(12, request.adminNote());
            statement.setTimestamp(13, timestamp(request.createdAt()));
            statement.setTimestamp(14, timestamp(request.updatedAt()));
            statement.executeUpdate();
            return request;
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
                CREATE TABLE IF NOT EXISTS storage_profile_requests (
                    id BIGINT NOT NULL PRIMARY KEY,
                    bucket_name VARCHAR(63) NOT NULL,
                    current_profile_code VARCHAR(32) NOT NULL,
                    requested_profile_code VARCHAR(32) NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    reason VARCHAR(512) NULL,
                    requested_by VARCHAR(128) NOT NULL,
                    approved_by VARCHAR(128) NULL,
                    approved_at TIMESTAMP NULL,
                    applied_by VARCHAR(128) NULL,
                    applied_at TIMESTAMP NULL,
                    admin_note VARCHAR(512) NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    INDEX idx_storage_profile_requests_bucket (bucket_name, id),
                    INDEX idx_storage_profile_requests_status (status, id)
                )
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private String selectSql() {
        return """
                SELECT id, bucket_name, current_profile_code, requested_profile_code, status, reason,
                       requested_by, approved_by, approved_at, applied_by, applied_at, admin_note,
                       created_at, updated_at
                FROM storage_profile_requests
                """;
    }

    private List<StorageProfileRequestRecord> collect(ResultSet resultSet) throws SQLException {
        List<StorageProfileRequestRecord> records = new ArrayList<>();
        while (resultSet.next()) {
            records.add(mapRow(resultSet));
        }
        return records;
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private StorageProfileRequestRecord mapRow(ResultSet resultSet) throws SQLException {
        return new StorageProfileRequestRecord(
                resultSet.getLong("id"),
                resultSet.getString("bucket_name"),
                resultSet.getString("current_profile_code"),
                resultSet.getString("requested_profile_code"),
                resultSet.getString("status"),
                resultSet.getString("reason"),
                resultSet.getString("requested_by"),
                resultSet.getString("approved_by"),
                toOffset(resultSet.getTimestamp("approved_at")),
                resultSet.getString("applied_by"),
                toOffset(resultSet.getTimestamp("applied_at")),
                resultSet.getString("admin_note"),
                toOffset(resultSet.getTimestamp("created_at")),
                toOffset(resultSet.getTimestamp("updated_at"))
        );
    }

    private Timestamp timestamp(OffsetDateTime value) {
        return value == null ? null : Timestamp.from(value.toInstant());
    }

    private OffsetDateTime toOffset(Timestamp value) {
        return value == null ? null : value.toInstant().atOffset(ZoneOffset.UTC);
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
