package com.example.osmu.bucket.repository;

import com.example.osmu.bucket.BucketPermissionRecord;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
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
public class MariaDbBucketPermissionRepository implements BucketPermissionRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbBucketPermissionRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<BucketPermissionRecord> findByBucketId(long bucketId) {
        ensureSchema();
        String sql = """
                SELECT id, bucket_id, subject_type, subject_id, permission, created_at, updated_at
                FROM bucket_permissions
                WHERE bucket_id = ?
                ORDER BY id
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, bucketId);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<BucketPermissionRecord> permissions = new ArrayList<>();
                while (resultSet.next()) {
                    permissions.add(mapRow(resultSet));
                }
                return permissions;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<BucketPermissionRecord> findById(long id) {
        ensureSchema();
        String sql = """
                SELECT id, bucket_id, subject_type, subject_id, permission, created_at, updated_at
                FROM bucket_permissions
                WHERE id = ?
                """;
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
    public boolean exists(long bucketId, String subjectType, long subjectId, String permission) {
        ensureSchema();
        String sql = """
                SELECT 1
                FROM bucket_permissions
                WHERE bucket_id = ? AND subject_type = ? AND subject_id = ? AND permission = ?
                LIMIT 1
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, bucketId);
            statement.setString(2, subjectType);
            statement.setLong(3, subjectId);
            statement.setString(4, permission);
            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public long nextId() {
        ensureSchema();
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM bucket_permissions";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
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
    public BucketPermissionRecord save(BucketPermissionRecord permission) {
        ensureSchema();
        String sql = """
                INSERT INTO bucket_permissions
                    (id, bucket_id, subject_type, subject_id, permission, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, permission.id());
            statement.setLong(2, permission.bucketId());
            statement.setString(3, permission.subjectType());
            statement.setLong(4, permission.subjectId());
            statement.setString(5, permission.permission());
            statement.setTimestamp(6, Timestamp.from(permission.createdAt().toInstant()));
            statement.setTimestamp(7, Timestamp.from(permission.updatedAt().toInstant()));
            statement.executeUpdate();
            return permission;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteById(long id) {
        ensureSchema();
        String sql = "DELETE FROM bucket_permissions WHERE id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteByBucketId(long bucketId) {
        ensureSchema();
        String sql = "DELETE FROM bucket_permissions WHERE bucket_id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, bucketId);
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public int deleteBySubject(String subjectType, long subjectId) {
        ensureSchema();
        String sql = "DELETE FROM bucket_permissions WHERE subject_type = ? AND subject_id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, subjectType);
            statement.setLong(2, subjectId);
            return statement.executeUpdate();
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
                CREATE TABLE IF NOT EXISTS bucket_permissions (
                    id BIGINT NOT NULL PRIMARY KEY,
                    bucket_id BIGINT NOT NULL,
                    subject_type VARCHAR(32) NOT NULL,
                    subject_id BIGINT NOT NULL,
                    permission VARCHAR(32) NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    UNIQUE KEY uk_bucket_permission (bucket_id, subject_type, subject_id, permission),
                    INDEX idx_bucket_permissions_subject (subject_type, subject_id)
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

    private BucketPermissionRecord mapRow(ResultSet resultSet) throws SQLException {
        return new BucketPermissionRecord(
                resultSet.getLong("id"),
                resultSet.getLong("bucket_id"),
                resultSet.getString("subject_type"),
                resultSet.getLong("subject_id"),
                resultSet.getString("permission"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
