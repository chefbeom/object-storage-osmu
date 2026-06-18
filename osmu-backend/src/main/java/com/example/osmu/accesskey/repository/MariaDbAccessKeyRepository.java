package com.example.osmu.accesskey.repository;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.example.osmu.accesskey.AccessKeyBucketScope;
import com.example.osmu.accesskey.AccessKeyCredential;
import com.example.osmu.accesskey.AccessKeyEntity;
import com.example.osmu.accesskey.AccessKeyPolicyNames;
import com.example.osmu.accesskey.AccessKeyRecord;
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
public class MariaDbAccessKeyRepository implements AccessKeyRepository {

    private static final TypeReference<List<String>> STRING_LIST = new TypeReference<>() {
    };
    private static final TypeReference<List<AccessKeyBucketScope>> BUCKET_SCOPE_LIST = new TypeReference<>() {
    };

    private final String url;
    private final String username;
    private final String password;
    private final ObjectMapper objectMapper;
    private volatile boolean schemaReady;

    public MariaDbAccessKeyRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password,
            ObjectMapper objectMapper
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
        this.objectMapper = objectMapper;
    }

    @Override
    public List<AccessKeyRecord> findAllRecords() {
        ensureSchema();
        String sql = """
                SELECT id, owner_id, name, access_key, allowed_buckets, permissions, bucket_scopes, status, created_at, expires_at, last_used_at
                FROM access_keys
                ORDER BY id
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<AccessKeyRecord> keys = new ArrayList<>();
            while (resultSet.next()) {
                keys.add(mapRecord(resultSet));
            }
            return keys;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<AccessKeyRecord> findRecordsByOwnerId(long ownerId) {
        ensureSchema();
        String sql = """
                SELECT id, owner_id, name, access_key, allowed_buckets, permissions, bucket_scopes, status, created_at, expires_at, last_used_at
                FROM access_keys
                WHERE owner_id = ?
                ORDER BY id
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, ownerId);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<AccessKeyRecord> keys = new ArrayList<>();
                while (resultSet.next()) {
                    keys.add(mapRecord(resultSet));
                }
                return keys;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<AccessKeyRecord> findRecordById(long id) {
        ensureSchema();
        String sql = """
                SELECT id, owner_id, name, access_key, allowed_buckets, permissions, bucket_scopes, status, created_at, expires_at, last_used_at
                FROM access_keys
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    return Optional.of(mapRecord(resultSet));
                }
                return Optional.empty();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<AccessKeyCredential> findCredentialByAccessKey(String accessKey) {
        ensureSchema();
        String sql = """
                SELECT id, owner_id, access_key, secret_key_hash, secret_key_ciphertext, allowed_buckets, permissions, bucket_scopes, status, expires_at
                FROM access_keys
                WHERE access_key = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, accessKey);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    return Optional.of(mapCredential(resultSet));
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
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM access_keys";
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
    public AccessKeyRecord save(AccessKeyEntity accessKey) {
        ensureSchema();
        String sql = """
                INSERT INTO access_keys
                    (id, owner_id, name, access_key, secret_key_hash, secret_key_ciphertext, allowed_buckets, permissions, bucket_scopes, status, created_at, expires_at, last_used_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    secret_key_hash = VALUES(secret_key_hash),
                    secret_key_ciphertext = VALUES(secret_key_ciphertext),
                    allowed_buckets = VALUES(allowed_buckets),
                    permissions = VALUES(permissions),
                    bucket_scopes = VALUES(bucket_scopes),
                    status = VALUES(status),
                    expires_at = VALUES(expires_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, accessKey.id());
            statement.setLong(2, accessKey.ownerId());
            statement.setString(3, accessKey.name());
            statement.setString(4, accessKey.accessKey());
            statement.setString(5, accessKey.secretKeyHash());
            statement.setString(6, accessKey.secretKeyCiphertext());
            statement.setString(7, jsonList(accessKey.allowedBuckets()));
            statement.setString(8, jsonList(accessKey.permissions()));
            statement.setString(9, jsonBucketScopes(accessKey.bucketScopes()));
            statement.setString(10, accessKey.status());
            statement.setTimestamp(11, Timestamp.from(accessKey.createdAt().toInstant()));
            statement.setTimestamp(12, timestampOrNull(accessKey.expiresAt()));
            statement.setTimestamp(13, timestampOrNull(accessKey.lastUsedAt()));
            statement.executeUpdate();
            return accessKey.toRecord();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void updateStatus(long id, String status) {
        ensureSchema();
        String sql = "UPDATE access_keys SET status = ? WHERE id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);
            statement.setLong(2, id);
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void updateScope(long id, List<String> allowedBuckets, List<String> permissions, List<AccessKeyBucketScope> bucketScopes) {
        ensureSchema();
        String sql = "UPDATE access_keys SET allowed_buckets = ?, permissions = ?, bucket_scopes = ? WHERE id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, jsonList(allowedBuckets));
            statement.setString(2, jsonList(permissions));
            statement.setString(3, jsonBucketScopes(bucketScopes));
            statement.setLong(4, id);
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void updateSecret(long id, String secretKeyHash, String secretKeyCiphertext) {
        ensureSchema();
        String sql = "UPDATE access_keys SET secret_key_hash = ?, secret_key_ciphertext = ? WHERE id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, secretKeyHash);
            statement.setString(2, secretKeyCiphertext);
            statement.setLong(3, id);
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void markUsed(long id, OffsetDateTime usedAt) {
        ensureSchema();
        String sql = "UPDATE access_keys SET last_used_at = ? WHERE id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setTimestamp(1, timestampOrNull(usedAt));
            statement.setLong(2, id);
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
                CREATE TABLE IF NOT EXISTS access_keys (
                    id BIGINT NOT NULL PRIMARY KEY,
                    owner_id BIGINT NOT NULL,
                    name VARCHAR(100) NOT NULL,
                    access_key VARCHAR(128) NOT NULL UNIQUE,
                    secret_key_hash VARCHAR(128) NOT NULL,
                    secret_key_ciphertext TEXT NULL,
                    allowed_buckets TEXT NOT NULL,
                    permissions TEXT NOT NULL,
                    bucket_scopes TEXT NULL,
                    status VARCHAR(32) NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    expires_at TIMESTAMP NULL,
                    last_used_at TIMESTAMP NULL,
                    INDEX idx_access_keys_owner_id (owner_id),
                    INDEX idx_access_keys_status (status),
                    INDEX idx_access_keys_last_used_at (last_used_at)
                )
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
            ensureScopeColumns(connection);
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void ensureScopeColumns(Connection connection) throws SQLException {
        executeUpdate(connection, "ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS allowed_buckets TEXT NULL");
        executeUpdate(connection, "ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS permissions TEXT NULL");
        executeUpdate(connection, "ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS bucket_scopes TEXT NULL");
        executeUpdate(connection, "ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS secret_key_ciphertext TEXT NULL");
        executeUpdate(connection, "ALTER TABLE access_keys ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMP NULL");
        executeUpdate(connection, "CREATE INDEX IF NOT EXISTS idx_access_keys_last_used_at ON access_keys (last_used_at)");
        executeUpdate(connection, "UPDATE access_keys SET allowed_buckets = '[\"*\"]' WHERE allowed_buckets IS NULL");
        executeUpdate(connection, "UPDATE access_keys SET permissions = '[\"READ\",\"WRITE\",\"DELETE\"]' WHERE permissions IS NULL");
        executeUpdate(connection, "ALTER TABLE access_keys MODIFY COLUMN allowed_buckets TEXT NOT NULL");
        executeUpdate(connection, "ALTER TABLE access_keys MODIFY COLUMN permissions TEXT NOT NULL");
    }

    private void executeUpdate(Connection connection, String sql) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private AccessKeyRecord mapRecord(ResultSet resultSet) throws SQLException {
        List<String> allowedBuckets = readList(resultSet.getString("allowed_buckets"));
        List<String> permissions = readList(resultSet.getString("permissions"));
        return new AccessKeyRecord(
                resultSet.getLong("id"),
                resultSet.getLong("owner_id"),
                resultSet.getString("name"),
                resultSet.getString("access_key"),
                AccessKeyPolicyNames.policyName(resultSet.getLong("id")),
                allowedBuckets,
                permissions,
                readBucketScopes(resultSet.getString("bucket_scopes"), allowedBuckets, permissions),
                resultSet.getString("status"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                offsetDateTimeOrNull(resultSet.getTimestamp("expires_at")),
                offsetDateTimeOrNull(resultSet.getTimestamp("last_used_at"))
        );
    }

    private AccessKeyCredential mapCredential(ResultSet resultSet) throws SQLException {
        List<String> allowedBuckets = readList(resultSet.getString("allowed_buckets"));
        List<String> permissions = readList(resultSet.getString("permissions"));
        return new AccessKeyCredential(
                resultSet.getLong("id"),
                resultSet.getLong("owner_id"),
                resultSet.getString("access_key"),
                resultSet.getString("secret_key_hash"),
                resultSet.getString("secret_key_ciphertext"),
                readBucketScopes(resultSet.getString("bucket_scopes"), allowedBuckets, permissions),
                resultSet.getString("status"),
                offsetDateTimeOrNull(resultSet.getTimestamp("expires_at"))
        );
    }

    private String jsonBucketScopes(List<AccessKeyBucketScope> values) {
        try {
            return objectMapper.writeValueAsString(values);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to serialize access key bucket scope.");
        }
    }

    private String jsonList(List<String> values) {
        try {
            return objectMapper.writeValueAsString(values);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to serialize access key scope.");
        }
    }

    private List<AccessKeyBucketScope> readBucketScopes(String value, List<String> allowedBuckets, List<String> permissions) {
        if (value == null || value.isBlank()) {
            return allowedBuckets.stream()
                    .map(bucketName -> new AccessKeyBucketScope(bucketName, permissions))
                    .toList();
        }
        try {
            return objectMapper.readValue(value, BUCKET_SCOPE_LIST);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to parse access key bucket scope.");
        }
    }

    private List<String> readList(String value) {
        if (value == null || value.isBlank()) {
            return List.of();
        }
        try {
            return objectMapper.readValue(value, STRING_LIST);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to parse access key scope.");
        }
    }

    private Timestamp timestampOrNull(OffsetDateTime value) {
        return value == null ? null : Timestamp.from(value.toInstant());
    }

    private OffsetDateTime offsetDateTimeOrNull(Timestamp value) {
        return value == null ? null : value.toInstant().atOffset(ZoneOffset.UTC);
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
