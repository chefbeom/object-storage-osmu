package com.example.osmu.storageprofile.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storageprofile.StorageProfileAssignmentRecord;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbStorageProfileAssignmentRepository implements StorageProfileAssignmentRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbStorageProfileAssignmentRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }


    @Override
    public Optional<StorageProfileAssignmentRecord> findByBucketName(String bucketName) {
        ensureSchema();
        String sql = """
                SELECT bucket_name, profile_code, storage_layout_plan_id, storage_pool_name,
                       storage_layout_code, applied_by, applied_at, updated_at
                FROM bucket_storage_profile_assignments
                WHERE bucket_name = ?
                """;
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
    public StorageProfileAssignmentRecord save(StorageProfileAssignmentRecord assignment) {
        ensureSchema();
        String sql = """
                INSERT INTO bucket_storage_profile_assignments
                    (bucket_name, profile_code, storage_layout_plan_id, storage_pool_name,
                     storage_layout_code, applied_by, applied_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    profile_code = VALUES(profile_code),
                    storage_layout_plan_id = VALUES(storage_layout_plan_id),
                    storage_pool_name = VALUES(storage_pool_name),
                    storage_layout_code = VALUES(storage_layout_code),
                    applied_by = VALUES(applied_by),
                    applied_at = VALUES(applied_at),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, assignment.bucketName());
            statement.setString(2, assignment.profileCode());
            statement.setObject(3, assignment.storageLayoutPlanId());
            statement.setString(4, assignment.storagePoolName());
            statement.setString(5, assignment.storageLayoutCode());
            statement.setString(6, assignment.appliedBy());
            statement.setTimestamp(7, timestamp(assignment.appliedAt()));
            statement.setTimestamp(8, timestamp(assignment.updatedAt()));
            statement.executeUpdate();
            return assignment;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteByBucketName(String bucketName) {
        ensureSchema();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement("DELETE FROM bucket_storage_profile_assignments WHERE bucket_name = ?")) {
            statement.setString(1, bucketName);
            statement.executeUpdate();
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
                CREATE TABLE IF NOT EXISTS bucket_storage_profile_assignments (
                    bucket_name VARCHAR(63) NOT NULL PRIMARY KEY,
                    profile_code VARCHAR(32) NOT NULL,
                    storage_layout_plan_id BIGINT NULL,
                    storage_pool_name VARCHAR(128) NULL,
                    storage_layout_code VARCHAR(32) NULL,
                    applied_by VARCHAR(128) NOT NULL,
                    applied_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL
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

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private StorageProfileAssignmentRecord mapRow(ResultSet resultSet) throws SQLException {
        return new StorageProfileAssignmentRecord(
                resultSet.getString("bucket_name"),
                resultSet.getString("profile_code"),
                nullableLong(resultSet, "storage_layout_plan_id"),
                resultSet.getString("storage_pool_name"),
                resultSet.getString("storage_layout_code"),
                resultSet.getString("applied_by"),
                toOffset(resultSet.getTimestamp("applied_at")),
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
