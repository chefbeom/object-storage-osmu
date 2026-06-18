package com.example.osmu.object.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectVersionRecord;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbObjectVersionRepository implements ObjectVersionRepository {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final TypeReference<Map<String, String>> TAG_MAP_TYPE = new TypeReference<>() {
    };

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbObjectVersionRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<ObjectVersionRecord> findByObjectKey(String bucketName, String objectKey) {
        ensureSchema();
        String sql = """
                SELECT version_id, object_key, storage_key, size_bytes, content_type, object_last_modified_at, created_at, tags, user_metadata
                FROM object_versions
                WHERE bucket_name = ? AND object_key_hash = ?
                ORDER BY created_at DESC, version_id DESC
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            statement.setString(2, keyHash(objectKey));
            try (ResultSet resultSet = statement.executeQuery()) {
                List<ObjectVersionRecord> versions = new ArrayList<>();
                while (resultSet.next()) {
                    versions.add(mapRow(resultSet));
                }
                return versions;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<VersionCandidate> findCreatedBefore(OffsetDateTime cutoff, int limit) {
        return findCreatedBefore(cutoff, limit, "", "", Map.of());
    }

    @Override
    public List<VersionCandidate> findCreatedBefore(
            OffsetDateTime cutoff,
            int limit,
            String prefix,
            Map<String, String> tagFilter
    ) {
        return findCreatedBefore(cutoff, limit, "", prefix, tagFilter);
    }

    @Override
    public List<VersionCandidate> findCreatedBefore(
            OffsetDateTime cutoff,
            int limit,
            String bucketName,
            String prefix,
            Map<String, String> tagFilter
    ) {
        ensureSchema();
        String normalizedBucketName = bucketName == null ? "" : bucketName.trim();
        String normalizedPrefix = prefix == null ? "" : prefix;
        Map<String, String> normalizedTagFilter = tagFilter == null ? Map.of() : tagFilter;
        StringBuilder sql = new StringBuilder("""
                SELECT bucket_name, version_id, object_key, storage_key, size_bytes, content_type,
                       object_last_modified_at, created_at, tags, user_metadata
                FROM object_versions
                WHERE created_at <= ? AND object_key LIKE ?
                """);
        if (!normalizedBucketName.isBlank()) {
            sql.append("AND bucket_name = ?\n");
        }
        sql.append("""
                ORDER BY created_at ASC, version_id ASC
                LIMIT ?
                """);
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            statement.setTimestamp(1, Timestamp.from(cutoff.toInstant()));
            statement.setString(2, normalizedPrefix + "%");
            int parameterIndex = 3;
            if (!normalizedBucketName.isBlank()) {
                statement.setString(parameterIndex++, normalizedBucketName);
            }
            statement.setInt(parameterIndex, Math.max(1, limit * 10));
            try (ResultSet resultSet = statement.executeQuery()) {
                List<VersionCandidate> versions = new ArrayList<>();
                while (resultSet.next()) {
                    VersionCandidate candidate = new VersionCandidate(resultSet.getString("bucket_name"), mapRow(resultSet));
                    if (matchesTags(candidate.version(), normalizedTagFilter)) {
                        versions.add(candidate);
                        if (versions.size() >= limit) {
                            break;
                        }
                    }
                }
                return versions;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<ObjectVersionRecord> findByVersionId(String bucketName, String objectKey, String versionId) {
        ensureSchema();
        String sql = """
                SELECT version_id, object_key, storage_key, size_bytes, content_type, object_last_modified_at, created_at, tags, user_metadata
                FROM object_versions
                WHERE bucket_name = ? AND object_key_hash = ? AND version_id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            statement.setString(2, keyHash(objectKey));
            statement.setString(3, versionId);
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
    public ObjectVersionRecord save(String bucketName, ObjectVersionRecord version) {
        ensureSchema();
        String sql = """
                INSERT INTO object_versions
                    (bucket_name, object_key_hash, object_key, version_id, storage_key, size_bytes, content_type,
                     object_last_modified_at, created_at, tags, user_metadata)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    storage_key = VALUES(storage_key),
                    size_bytes = VALUES(size_bytes),
                    content_type = VALUES(content_type),
                    object_last_modified_at = VALUES(object_last_modified_at),
                    created_at = VALUES(created_at),
                    tags = VALUES(tags),
                    user_metadata = VALUES(user_metadata)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            statement.setString(2, keyHash(version.key()));
            statement.setString(3, version.key());
            statement.setString(4, version.versionId());
            statement.setString(5, version.storageKey());
            statement.setLong(6, version.sizeBytes());
            statement.setString(7, version.contentType());
            statement.setTimestamp(8, Timestamp.from(version.objectLastModifiedAt().toInstant()));
            statement.setTimestamp(9, Timestamp.from(version.createdAt().toInstant()));
            statement.setString(10, tagsJson(version.tags()));
            statement.setString(11, userMetadataJson(version.userMetadata()));
            statement.executeUpdate();
            return version;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void delete(String bucketName, String objectKey, String versionId) {
        ensureSchema();
        String sql = "DELETE FROM object_versions WHERE bucket_name = ? AND object_key_hash = ? AND version_id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            statement.setString(2, keyHash(objectKey));
            statement.setString(3, versionId);
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteByObjectKey(String bucketName, String objectKey) {
        ensureSchema();
        String sql = "DELETE FROM object_versions WHERE bucket_name = ? AND object_key_hash = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            statement.setString(2, keyHash(objectKey));
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteByBucketName(String bucketName) {
        ensureSchema();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement("DELETE FROM object_versions WHERE bucket_name = ?")) {
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
                CREATE TABLE IF NOT EXISTS object_versions (
                    bucket_name VARCHAR(63) NOT NULL,
                    object_key_hash CHAR(64) NOT NULL,
                    object_key VARCHAR(1024) NOT NULL,
                    version_id VARCHAR(64) NOT NULL,
                    storage_key VARCHAR(1200) NOT NULL,
                    size_bytes BIGINT NOT NULL,
                    content_type VARCHAR(255) NOT NULL,
                    object_last_modified_at TIMESTAMP NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    tags TEXT NOT NULL,
                    user_metadata TEXT NOT NULL,
                    PRIMARY KEY (bucket_name, object_key_hash, version_id),
                    INDEX idx_object_versions_object (bucket_name, object_key_hash, created_at)
                )
                """;
        try (Connection connection = connect();
            PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
            ensureUserMetadataColumn(connection);
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private void ensureUserMetadataColumn(Connection connection) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "ALTER TABLE object_versions ADD COLUMN user_metadata TEXT NULL AFTER tags")) {
            statement.executeUpdate();
        } catch (SQLException exception) {
            if (exception.getErrorCode() != 1060) {
                throw exception;
            }
        }
        try (PreparedStatement statement = connection.prepareStatement(
                "UPDATE object_versions SET user_metadata = '{}' WHERE user_metadata IS NULL")) {
            statement.executeUpdate();
        }
        try (PreparedStatement statement = connection.prepareStatement(
                "ALTER TABLE object_versions MODIFY COLUMN user_metadata TEXT NOT NULL")) {
            statement.executeUpdate();
        }
    }

    private ObjectVersionRecord mapRow(ResultSet resultSet) throws SQLException {
        return new ObjectVersionRecord(
                resultSet.getString("version_id"),
                resultSet.getString("object_key"),
                resultSet.getString("storage_key"),
                resultSet.getLong("size_bytes"),
                resultSet.getString("content_type"),
                resultSet.getTimestamp("object_last_modified_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                tagsFromJson(resultSet.getString("tags")),
                userMetadataFromJson(resultSet.getString("user_metadata"))
        );
    }

    private String keyHash(String objectKey) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(objectKey.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "SHA-256 is not available.");
        }
    }

    private String tagsJson(Map<String, String> tags) {
        try {
            return OBJECT_MAPPER.writeValueAsString(tags == null ? Map.of() : tags);
        } catch (Exception exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object version tags serialization failed.");
        }
    }

    private String userMetadataJson(Map<String, String> userMetadata) {
        try {
            return OBJECT_MAPPER.writeValueAsString(userMetadata == null ? Map.of() : userMetadata);
        } catch (Exception exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object version user metadata serialization failed.");
        }
    }

    private Map<String, String> tagsFromJson(String rawTags) {
        if (rawTags == null || rawTags.isBlank()) {
            return Map.of();
        }
        try {
            Map<String, String> tags = OBJECT_MAPPER.readValue(rawTags, TAG_MAP_TYPE);
            return tags == null ? Map.of() : Map.copyOf(tags);
        } catch (Exception exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object version tags deserialization failed.");
        }
    }

    private Map<String, String> userMetadataFromJson(String rawUserMetadata) {
        if (rawUserMetadata == null || rawUserMetadata.isBlank()) {
            return Map.of();
        }
        try {
            Map<String, String> userMetadata = OBJECT_MAPPER.readValue(rawUserMetadata, TAG_MAP_TYPE);
            return userMetadata == null ? Map.of() : Map.copyOf(userMetadata);
        } catch (Exception exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object version user metadata deserialization failed.");
        }
    }

    private boolean matchesTags(ObjectVersionRecord version, Map<String, String> tagFilter) {
        if (tagFilter.isEmpty()) {
            return true;
        }
        return tagFilter.entrySet().stream()
                .allMatch(entry -> entry.getValue().equals(version.tags().get(entry.getKey())));
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
