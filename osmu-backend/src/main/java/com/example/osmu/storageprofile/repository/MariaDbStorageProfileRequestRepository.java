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
import java.util.LinkedHashSet;
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
    public List<StorageProfileRequestRecord> findPage(List<String> statuses, Long cursorId, int limit) {
        ensureSchema();
        List<String> statusFilter = statuses == null
                ? List.of()
                : statuses.stream()
                        .filter(java.util.Objects::nonNull)
                        .distinct()
                        .toList();
        StringBuilder sql = new StringBuilder(selectSql()).append(" WHERE 1 = 1");
        if (!statusFilter.isEmpty()) {
            sql.append(" AND status IN (")
                    .append(String.join(", ", java.util.Collections.nCopies(statusFilter.size(), "?")))
                    .append(")");
        }
        if (cursorId != null) {
            sql.append(" AND id < ?");
        }
        sql.append(" ORDER BY id DESC LIMIT ?");

        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            int parameterIndex = 1;
            for (String status : statusFilter) {
                statement.setString(parameterIndex++, status);
            }
            if (cursorId != null) {
                statement.setLong(parameterIndex++, cursorId);
            }
            statement.setInt(parameterIndex, limit);
            try (ResultSet resultSet = statement.executeQuery()) {
                return collect(resultSet);
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<StorageProfileRequestRecord> findPageByBucketName(
            String bucketName,
            Long cursorId,
            int limit
    ) {
        ensureSchema();
        String sql = selectSql() + " WHERE bucket_name = ?"
                + (cursorId == null ? "" : " AND id < ?")
                + " ORDER BY id DESC LIMIT ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            int parameterIndex = 1;
            statement.setString(parameterIndex++, bucketName);
            if (cursorId != null) {
                statement.setLong(parameterIndex++, cursorId);
            }
            statement.setInt(parameterIndex, limit);
            try (ResultSet resultSet = statement.executeQuery()) {
                return collect(resultSet);
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<StorageProfileRequestRecord> findPageByBucketNames(
            List<String> bucketNames,
            Long cursorId,
            int limit
    ) {
        ensureSchema();
        LinkedHashSet<String> uniqueBucketNames = new LinkedHashSet<>(bucketNames == null ? List.of() : bucketNames);
        uniqueBucketNames.remove(null);
        if (uniqueBucketNames.isEmpty()) {
            return List.of();
        }
        String placeholders = String.join(", ", java.util.Collections.nCopies(uniqueBucketNames.size(), "?"));
        String sql = selectSql() + " WHERE bucket_name IN (" + placeholders + ")"
                + (cursorId == null ? "" : " AND id < ?")
                + " ORDER BY id DESC LIMIT ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            int parameterIndex = 1;
            for (String bucketName : uniqueBucketNames) {
                statement.setString(parameterIndex++, bucketName);
            }
            if (cursorId != null) {
                statement.setLong(parameterIndex++, cursorId);
            }
            statement.setInt(parameterIndex, limit);
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
                     requested_by, approved_by, approved_at, applied_by, applied_at,
                     storage_layout_plan_id, storage_pool_name, storage_layout_code, admin_note,
                     created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    current_profile_code = VALUES(current_profile_code),
                    requested_profile_code = VALUES(requested_profile_code),
                    status = VALUES(status),
                    reason = VALUES(reason),
                    approved_by = VALUES(approved_by),
                    approved_at = VALUES(approved_at),
                    applied_by = VALUES(applied_by),
                    applied_at = VALUES(applied_at),
                    storage_layout_plan_id = VALUES(storage_layout_plan_id),
                    storage_pool_name = VALUES(storage_pool_name),
                    storage_layout_code = VALUES(storage_layout_code),
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
            statement.setObject(12, request.storageLayoutPlanId());
            statement.setString(13, request.storagePoolName());
            statement.setString(14, request.storageLayoutCode());
            statement.setString(15, request.adminNote());
            statement.setTimestamp(16, timestamp(request.createdAt()));
            statement.setTimestamp(17, timestamp(request.updatedAt()));
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
                    storage_layout_plan_id BIGINT NULL,
                    storage_pool_name VARCHAR(128) NULL,
                    storage_layout_code VARCHAR(32) NULL,
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
                       requested_by, approved_by, approved_at, applied_by, applied_at,
                       storage_layout_plan_id, storage_pool_name, storage_layout_code, admin_note,
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
                nullableLong(resultSet, "storage_layout_plan_id"),
                resultSet.getString("storage_pool_name"),
                resultSet.getString("storage_layout_code"),
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

    private Long nullableLong(ResultSet resultSet, String column) throws SQLException {
        long value = resultSet.getLong(column);
        return resultSet.wasNull() ? null : value;
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
