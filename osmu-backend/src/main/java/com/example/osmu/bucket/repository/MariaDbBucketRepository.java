package com.example.osmu.bucket.repository;

import com.example.osmu.bucket.BucketRecord;
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
public class MariaDbBucketRepository implements BucketRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbBucketRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<BucketRecord> findAll() {
        ensureSchema();
        String sql = """
                SELECT id, name, owner_type, owner_id, quota_bytes, used_bytes, object_count, created_at
                FROM buckets
                ORDER BY name
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<BucketRecord> buckets = new ArrayList<>();
            while (resultSet.next()) {
                buckets.add(mapRow(resultSet));
            }
            return buckets;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<BucketRecord> findByName(String bucketName) {
        ensureSchema();
        String sql = """
                SELECT id, name, owner_type, owner_id, quota_bytes, used_bytes, object_count, created_at
                FROM buckets
                WHERE name = ?
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
    public boolean existsByName(String bucketName) {
        ensureSchema();
        String sql = "SELECT 1 FROM buckets WHERE name = ? LIMIT 1";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
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
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM buckets";
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
    public BucketRecord save(BucketRecord bucket) {
        ensureSchema();
        String sql = """
                INSERT INTO buckets
                    (id, name, owner_type, owner_id, quota_bytes, used_bytes, object_count, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    owner_type = VALUES(owner_type),
                    owner_id = VALUES(owner_id),
                    quota_bytes = VALUES(quota_bytes),
                    used_bytes = VALUES(used_bytes),
                    object_count = VALUES(object_count)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, bucket.id());
            statement.setString(2, bucket.name());
            statement.setString(3, bucket.ownerType());
            statement.setLong(4, bucket.ownerId());
            statement.setLong(5, bucket.quotaBytes());
            statement.setLong(6, bucket.usedBytes());
            statement.setLong(7, bucket.objectCount());
            statement.setTimestamp(8, Timestamp.from(bucket.createdAt().toInstant()));
            statement.executeUpdate();
            return bucket;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteByName(String bucketName) {
        ensureSchema();
        String sql = "DELETE FROM buckets WHERE name = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
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
                CREATE TABLE IF NOT EXISTS buckets (
                    id BIGINT NOT NULL PRIMARY KEY,
                    name VARCHAR(63) NOT NULL UNIQUE,
                    owner_type VARCHAR(20) NOT NULL,
                    owner_id BIGINT NOT NULL,
                    quota_bytes BIGINT NOT NULL,
                    used_bytes BIGINT NOT NULL,
                    object_count BIGINT NOT NULL,
                    created_at TIMESTAMP NOT NULL
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

    private BucketRecord mapRow(ResultSet resultSet) throws SQLException {
        return new BucketRecord(
                resultSet.getLong("id"),
                resultSet.getString("name"),
                resultSet.getString("owner_type"),
                resultSet.getLong("owner_id"),
                resultSet.getLong("quota_bytes"),
                resultSet.getLong("used_bytes"),
                resultSet.getLong("object_count"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
