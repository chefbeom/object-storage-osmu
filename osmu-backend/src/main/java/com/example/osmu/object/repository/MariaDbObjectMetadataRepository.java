package com.example.osmu.object.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.DeletedObjectCandidate;
import com.example.osmu.object.StoredObjectPage;
import com.example.osmu.object.StoredObjectRecord;
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
import java.util.TreeMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbObjectMetadataRepository implements ObjectMetadataRepository {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final TypeReference<Map<String, String>> TAG_MAP_TYPE = new TypeReference<>() {
    };

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbObjectMetadataRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public StoredObjectPage listObjects(
            String bucketName,
            String prefix,
            String delimiter,
            String search,
            Map<String, String> tagFilter,
            String cursor,
            int limit
    ) {
        String normalizedPrefix = prefix == null ? "" : prefix;
        String normalizedDelimiter = delimiter == null ? "" : delimiter;
        String normalizedSearch = search == null ? "" : search.trim().toLowerCase();
        Map<String, String> normalizedTagFilter = tagFilter == null ? Map.of() : tagFilter;
        String normalizedCursor = cursor == null ? "" : cursor;

        List<StoredObjectRecord> objects = findCandidates(
                bucketName,
                normalizedPrefix,
                normalizedSearch,
                normalizedTagFilter
        )
                .stream()
                .filter(object -> object.key().startsWith(normalizedPrefix))
                .filter(object -> normalizedSearch.isBlank()
                        || object.key().toLowerCase().contains(normalizedSearch))
                .filter(object -> matchesTags(object, normalizedTagFilter))
                .toList();

        if (normalizedDelimiter.isBlank() || !normalizedSearch.isBlank() || !normalizedTagFilter.isEmpty()) {
            List<StoredObjectRecord> pageObjects = objects.stream()
                    .filter(object -> normalizedCursor.isBlank() || object.key().compareTo(normalizedCursor) > 0)
                    .limit((long) limit + 1)
                    .toList();
            return toPage(pageObjects, limit);
        }

        Map<String, ListedObjectEntry> entries = new TreeMap<>();
        for (StoredObjectRecord object : objects) {
            addDelimitedEntry(entries, object, normalizedPrefix, normalizedDelimiter);
        }
        List<ListedObjectEntry> pageEntries = entries.values().stream()
                .filter(entry -> normalizedCursor.isBlank() || entry.key().compareTo(normalizedCursor) > 0)
                .limit((long) limit + 1)
                .toList();
        return toDelimitedPage(pageEntries, limit);
    }

    @Override
    public Optional<StoredObjectRecord> findByKey(String bucketName, String objectKey) {
        ensureSchema();
        String sql = """
                SELECT object_key, size_bytes, content_type, last_modified_at, tags, deleted_at, etag, checksums
                FROM object_metadata
                WHERE bucket_name = ? AND object_key_hash = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            statement.setString(2, keyHash(objectKey));
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
    public List<StoredObjectRecord> findAllByBucketName(String bucketName) {
        ensureSchema();
        String sql = """
                SELECT object_key, size_bytes, content_type, last_modified_at, tags, deleted_at, etag, checksums
                FROM object_metadata
                WHERE bucket_name = ?
                ORDER BY object_key
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<StoredObjectRecord> objects = new ArrayList<>();
                while (resultSet.next()) {
                    objects.add(mapRow(resultSet));
                }
                return objects;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public StoredObjectPage listDeletedObjects(
            String bucketName,
            String prefix,
            String search,
            Map<String, String> tagFilter,
            String cursor,
            int limit
    ) {
        String normalizedPrefix = prefix == null ? "" : prefix;
        String normalizedSearch = search == null ? "" : search.trim().toLowerCase();
        Map<String, String> normalizedTagFilter = tagFilter == null ? Map.of() : tagFilter;
        String normalizedCursor = cursor == null ? "" : cursor;
        List<StoredObjectRecord> pageObjects = findDeletedCandidates(
                bucketName,
                normalizedPrefix,
                normalizedSearch,
                normalizedTagFilter
        )
                .stream()
                .filter(object -> normalizedCursor.isBlank() || object.key().compareTo(normalizedCursor) > 0)
                .limit((long) limit + 1)
                .toList();
        return toPage(pageObjects, limit);
    }

    @Override
    public List<DeletedObjectCandidate> findDeletedBefore(OffsetDateTime cutoff, int limit) {
        return findDeletedBefore(cutoff, limit, "", "", Map.of());
    }

    @Override
    public List<DeletedObjectCandidate> findDeletedBefore(
            OffsetDateTime cutoff,
            int limit,
            String prefix,
            Map<String, String> tagFilter
    ) {
        return findDeletedBefore(cutoff, limit, "", prefix, tagFilter);
    }

    @Override
    public List<DeletedObjectCandidate> findDeletedBefore(
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
                SELECT bucket_name, object_key, size_bytes, deleted_at
                FROM object_metadata m
                WHERE deleted_at IS NOT NULL AND deleted_at <= ? AND object_key LIKE ?
                """);
        if (!normalizedBucketName.isBlank()) {
            sql.append("AND bucket_name = ?\n");
        }
        for (int index = 0; index < normalizedTagFilter.size(); index++) {
            sql.append("""
                    AND EXISTS (
                        SELECT 1
                        FROM object_metadata_tags t
                        WHERE t.bucket_name = m.bucket_name
                          AND t.object_key_hash = m.object_key_hash
                          AND t.tag_key = ?
                          AND t.tag_value = ?
                    )
                    """);
        }
        sql.append("ORDER BY deleted_at, bucket_name, object_key LIMIT ?");
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            statement.setTimestamp(1, Timestamp.from(cutoff.toInstant()));
            statement.setString(2, normalizedPrefix + "%");
            int parameterIndex = 3;
            if (!normalizedBucketName.isBlank()) {
                statement.setString(parameterIndex++, normalizedBucketName);
            }
            for (Map.Entry<String, String> entry : normalizedTagFilter.entrySet()) {
                statement.setString(parameterIndex++, entry.getKey());
                statement.setString(parameterIndex++, entry.getValue());
            }
            statement.setInt(parameterIndex, Math.max(1, limit));
            try (ResultSet resultSet = statement.executeQuery()) {
                List<DeletedObjectCandidate> candidates = new ArrayList<>();
                while (resultSet.next()) {
                    candidates.add(new DeletedObjectCandidate(
                            resultSet.getString("bucket_name"),
                            resultSet.getString("object_key"),
                            resultSet.getLong("size_bytes"),
                            resultSet.getTimestamp("deleted_at").toInstant().atOffset(ZoneOffset.UTC)
                    ));
                }
                return candidates;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public StoredObjectRecord save(String bucketName, StoredObjectRecord object) {
        ensureSchema();
        try (Connection connection = connect()) {
            connection.setAutoCommit(false);
            try {
                upsertObject(connection, bucketName, object);
                replaceObjectTags(connection, bucketName, object);
                connection.commit();
            } catch (SQLException exception) {
                rollback(connection, exception);
                throw exception;
            }
            return object;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void delete(String bucketName, String objectKey) {
        ensureSchema();
        try (Connection connection = connect()) {
            connection.setAutoCommit(false);
            try {
                deleteObjectTags(connection, bucketName, keyHash(objectKey));
                try (PreparedStatement statement = connection.prepareStatement(
                        "DELETE FROM object_metadata WHERE bucket_name = ? AND object_key_hash = ?")) {
                    statement.setString(1, bucketName);
                    statement.setString(2, keyHash(objectKey));
                    statement.executeUpdate();
                }
                connection.commit();
            } catch (SQLException exception) {
                rollback(connection, exception);
                throw exception;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void replaceBucketObjects(String bucketName, List<StoredObjectRecord> objects) {
        ensureSchema();
        try (Connection connection = connect()) {
            connection.setAutoCommit(false);
            try {
                try (PreparedStatement deleteTagsStatement = connection.prepareStatement(
                        "DELETE FROM object_metadata_tags WHERE bucket_name = ?")) {
                    deleteTagsStatement.setString(1, bucketName);
                    deleteTagsStatement.executeUpdate();
                }
                try (PreparedStatement deleteStatement = connection.prepareStatement(
                        "DELETE FROM object_metadata WHERE bucket_name = ?")) {
                    deleteStatement.setString(1, bucketName);
                    deleteStatement.executeUpdate();
                }
                try (PreparedStatement upsertStatement = connection.prepareStatement(upsertSql())) {
                    for (StoredObjectRecord object : objects) {
                        bindUpsert(upsertStatement, bucketName, object);
                        upsertStatement.addBatch();
                    }
                    upsertStatement.executeBatch();
                }
                try (PreparedStatement tagStatement = connection.prepareStatement(insertTagSql())) {
                    for (StoredObjectRecord object : objects) {
                        addObjectTagsBatch(tagStatement, bucketName, object);
                    }
                    tagStatement.executeBatch();
                }
                connection.commit();
            } catch (SQLException exception) {
                rollback(connection, exception);
                throw exception;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteByBucketName(String bucketName) {
        ensureSchema();
        try (Connection connection = connect()) {
            connection.setAutoCommit(false);
            try (PreparedStatement deleteTagsStatement = connection.prepareStatement(
                    "DELETE FROM object_metadata_tags WHERE bucket_name = ?");
                 PreparedStatement deleteObjectsStatement = connection.prepareStatement(
                         "DELETE FROM object_metadata WHERE bucket_name = ?")) {
                deleteTagsStatement.setString(1, bucketName);
                deleteTagsStatement.executeUpdate();
                deleteObjectsStatement.setString(1, bucketName);
                deleteObjectsStatement.executeUpdate();
                connection.commit();
            } catch (SQLException exception) {
                rollback(connection, exception);
                throw exception;
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

    private List<StoredObjectRecord> findCandidates(
            String bucketName,
            String prefix,
            String search,
            Map<String, String> tagFilter
    ) {
        ensureSchema();
        StringBuilder sql = new StringBuilder("""
                SELECT m.object_key, m.size_bytes, m.content_type, m.last_modified_at, m.tags, m.deleted_at, m.etag, m.checksums
                FROM object_metadata m
                WHERE m.bucket_name = ? AND m.object_key LIKE ? AND m.deleted_at IS NULL
                """);
        for (int index = 0; index < tagFilter.size(); index++) {
            sql.append("""
                    AND EXISTS (
                        SELECT 1
                        FROM object_metadata_tags t
                        WHERE t.bucket_name = m.bucket_name
                          AND t.object_key_hash = m.object_key_hash
                          AND t.tag_key = ?
                          AND t.tag_value = ?
                    )
                    """);
        }
        sql.append("ORDER BY m.object_key");
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            statement.setString(1, bucketName);
            statement.setString(2, prefix + "%");
            int parameterIndex = 3;
            for (Map.Entry<String, String> entry : tagFilter.entrySet()) {
                statement.setString(parameterIndex++, entry.getKey());
                statement.setString(parameterIndex++, entry.getValue());
            }
            try (ResultSet resultSet = statement.executeQuery()) {
                List<StoredObjectRecord> objects = new ArrayList<>();
                while (resultSet.next()) {
                    objects.add(mapRow(resultSet));
                }
                return objects;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private List<StoredObjectRecord> findDeletedCandidates(
            String bucketName,
            String prefix,
            String search,
            Map<String, String> tagFilter
    ) {
        ensureSchema();
        StringBuilder sql = new StringBuilder("""
                SELECT m.object_key, m.size_bytes, m.content_type, m.last_modified_at, m.tags, m.deleted_at, m.etag, m.checksums
                FROM object_metadata m
                WHERE m.bucket_name = ? AND m.object_key LIKE ? AND m.deleted_at IS NOT NULL
                """);
        if (!search.isBlank()) {
            sql.append("AND LOWER(m.object_key) LIKE ?\n");
        }
        for (int index = 0; index < tagFilter.size(); index++) {
            sql.append("""
                    AND EXISTS (
                        SELECT 1
                        FROM object_metadata_tags t
                        WHERE t.bucket_name = m.bucket_name
                          AND t.object_key_hash = m.object_key_hash
                          AND t.tag_key = ?
                          AND t.tag_value = ?
                    )
                    """);
        }
        sql.append("ORDER BY m.object_key");
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            statement.setString(1, bucketName);
            statement.setString(2, prefix + "%");
            int parameterIndex = 3;
            if (!search.isBlank()) {
                statement.setString(parameterIndex++, "%" + search + "%");
            }
            for (Map.Entry<String, String> entry : tagFilter.entrySet()) {
                statement.setString(parameterIndex++, entry.getKey());
                statement.setString(parameterIndex++, entry.getValue());
            }
            try (ResultSet resultSet = statement.executeQuery()) {
                List<StoredObjectRecord> objects = new ArrayList<>();
                while (resultSet.next()) {
                    objects.add(mapRow(resultSet));
                }
                return objects;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private synchronized void ensureSchema() {
        if (schemaReady) {
            return;
        }

        String objectMetadataSql = """
                CREATE TABLE IF NOT EXISTS object_metadata (
                    bucket_name VARCHAR(63) NOT NULL,
                    object_key_hash CHAR(64) NOT NULL,
                    object_key VARCHAR(1024) NOT NULL,
                    size_bytes BIGINT NOT NULL,
                    content_type VARCHAR(255) NOT NULL,
                    last_modified_at TIMESTAMP NOT NULL,
                    tags TEXT NOT NULL,
                    deleted_at TIMESTAMP NULL,
                    etag VARCHAR(128) NOT NULL DEFAULT '',
                    checksums TEXT NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    PRIMARY KEY (bucket_name, object_key_hash),
                    INDEX idx_object_metadata_bucket_key (bucket_name, object_key(255)),
                    INDEX idx_object_metadata_deleted_at (bucket_name, deleted_at),
                    INDEX idx_object_metadata_bucket_updated (bucket_name, updated_at)
                )
                """;
        String objectTagSql = """
                CREATE TABLE IF NOT EXISTS object_metadata_tags (
                    bucket_name VARCHAR(63) NOT NULL,
                    object_key_hash CHAR(64) NOT NULL,
                    tag_key VARCHAR(255) NOT NULL,
                    tag_value VARCHAR(256) NOT NULL,
                    PRIMARY KEY (bucket_name, object_key_hash, tag_key),
                    INDEX idx_object_metadata_tags_lookup (bucket_name, tag_key, tag_value, object_key_hash),
                    INDEX idx_object_metadata_tags_object (bucket_name, object_key_hash)
                )
                """;
        try (Connection connection = connect();
             PreparedStatement metadataStatement = connection.prepareStatement(objectMetadataSql);
             PreparedStatement tagStatement = connection.prepareStatement(objectTagSql)) {
            metadataStatement.executeUpdate();
            tagStatement.executeUpdate();
            ensureDeletedAtColumn(connection);
            ensureEtagColumn(connection);
            ensureChecksumsColumn(connection);
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private String upsertSql() {
        return """
                INSERT INTO object_metadata
                    (bucket_name, object_key_hash, object_key, size_bytes, content_type, last_modified_at, tags, deleted_at, etag, checksums, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    object_key = VALUES(object_key),
                    size_bytes = VALUES(size_bytes),
                    content_type = VALUES(content_type),
                    last_modified_at = VALUES(last_modified_at),
                    tags = VALUES(tags),
                    deleted_at = VALUES(deleted_at),
                    etag = VALUES(etag),
                    checksums = VALUES(checksums),
                    updated_at = VALUES(updated_at)
                """;
    }

    private void bindUpsert(PreparedStatement statement, String bucketName, StoredObjectRecord object)
            throws SQLException {
        OffsetDateTime modifiedAt = object.lastModifiedAt() == null ? OffsetDateTime.now() : object.lastModifiedAt();
        OffsetDateTime updatedAt = OffsetDateTime.now();
        statement.setString(1, bucketName);
        statement.setString(2, keyHash(object.key()));
        statement.setString(3, object.key());
        statement.setLong(4, object.sizeBytes());
        statement.setString(5, object.contentType() == null ? "application/octet-stream" : object.contentType());
        statement.setTimestamp(6, Timestamp.from(modifiedAt.toInstant()));
        statement.setString(7, tagsJson(object.tags()));
        statement.setTimestamp(8, object.deletedAt() == null ? null : Timestamp.from(object.deletedAt().toInstant()));
        statement.setString(9, object.etag());
        statement.setString(10, checksumsJson(object.checksums()));
        statement.setTimestamp(11, Timestamp.from(updatedAt.toInstant()));
    }

    private void ensureDeletedAtColumn(Connection connection) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "ALTER TABLE object_metadata ADD COLUMN deleted_at TIMESTAMP NULL")) {
            statement.executeUpdate();
        } catch (SQLException exception) {
            if (exception.getErrorCode() != 1060) {
                throw exception;
            }
        }
        try (PreparedStatement statement = connection.prepareStatement(
                "CREATE INDEX idx_object_metadata_deleted_at ON object_metadata (bucket_name, deleted_at)")) {
            statement.executeUpdate();
        } catch (SQLException exception) {
            if (exception.getErrorCode() != 1061) {
                throw exception;
            }
        }
    }

    private void ensureEtagColumn(Connection connection) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "ALTER TABLE object_metadata ADD COLUMN etag VARCHAR(128) NOT NULL DEFAULT '' AFTER deleted_at")) {
            statement.executeUpdate();
        } catch (SQLException exception) {
            if (exception.getErrorCode() != 1060) {
                throw exception;
            }
        }
    }

    private void ensureChecksumsColumn(Connection connection) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "ALTER TABLE object_metadata ADD COLUMN checksums TEXT NULL AFTER etag")) {
            statement.executeUpdate();
        } catch (SQLException exception) {
            if (exception.getErrorCode() != 1060) {
                throw exception;
            }
        }
        try (PreparedStatement statement = connection.prepareStatement(
                "UPDATE object_metadata SET checksums = '{}' WHERE checksums IS NULL")) {
            statement.executeUpdate();
        }
        try (PreparedStatement statement = connection.prepareStatement(
                "ALTER TABLE object_metadata MODIFY COLUMN checksums TEXT NOT NULL")) {
            statement.executeUpdate();
        }
    }

    private String insertTagSql() {
        return """
                INSERT INTO object_metadata_tags
                    (bucket_name, object_key_hash, tag_key, tag_value)
                VALUES (?, ?, ?, ?)
                """;
    }

    private void upsertObject(Connection connection, String bucketName, StoredObjectRecord object) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(upsertSql())) {
            bindUpsert(statement, bucketName, object);
            statement.executeUpdate();
        }
    }

    private void replaceObjectTags(Connection connection, String bucketName, StoredObjectRecord object)
            throws SQLException {
        String objectKeyHash = keyHash(object.key());
        deleteObjectTags(connection, bucketName, objectKeyHash);
        if (object.tags().isEmpty()) {
            return;
        }
        try (PreparedStatement statement = connection.prepareStatement(insertTagSql())) {
            addObjectTagsBatch(statement, bucketName, object);
            statement.executeBatch();
        }
    }

    private void deleteObjectTags(Connection connection, String bucketName, String objectKeyHash) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "DELETE FROM object_metadata_tags WHERE bucket_name = ? AND object_key_hash = ?")) {
            statement.setString(1, bucketName);
            statement.setString(2, objectKeyHash);
            statement.executeUpdate();
        }
    }

    private void addObjectTagsBatch(PreparedStatement statement, String bucketName, StoredObjectRecord object)
            throws SQLException {
        String objectKeyHash = keyHash(object.key());
        for (Map.Entry<String, String> entry : object.tags().entrySet()) {
            statement.setString(1, bucketName);
            statement.setString(2, objectKeyHash);
            statement.setString(3, entry.getKey());
            statement.setString(4, entry.getValue());
            statement.addBatch();
        }
    }

    private void rollback(Connection connection, SQLException cause) {
        try {
            connection.rollback();
        } catch (SQLException rollbackException) {
            cause.addSuppressed(rollbackException);
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private StoredObjectRecord mapRow(ResultSet resultSet) throws SQLException {
        return new StoredObjectRecord(
                resultSet.getString("object_key"),
                resultSet.getLong("size_bytes"),
                resultSet.getString("content_type"),
                resultSet.getTimestamp("last_modified_at").toInstant().atOffset(ZoneOffset.UTC),
                tagsFromJson(resultSet.getString("tags")),
                resultSet.getTimestamp("deleted_at") == null
                        ? null
                        : resultSet.getTimestamp("deleted_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getString("etag"),
                checksumsFromJson(resultSet.getString("checksums"))
        );
    }

    private boolean matchesTags(StoredObjectRecord object, Map<String, String> tagFilter) {
        if (tagFilter.isEmpty()) {
            return true;
        }
        return tagFilter.entrySet().stream()
                .allMatch(entry -> entry.getValue().equals(object.tags().get(entry.getKey())));
    }

    private StoredObjectPage toPage(List<StoredObjectRecord> objects, int limit) {
        if (objects.size() <= limit) {
            return StoredObjectPage.recursive(objects, null);
        }
        List<StoredObjectRecord> pageItems = List.copyOf(objects.subList(0, limit));
        return StoredObjectPage.recursive(pageItems, pageItems.get(pageItems.size() - 1).key());
    }

    private void addDelimitedEntry(
            Map<String, ListedObjectEntry> entries,
            StoredObjectRecord object,
            String prefix,
            String delimiter
    ) {
        String remainingKey = object.key().substring(prefix.length());
        int delimiterIndex = remainingKey.indexOf(delimiter);
        if (delimiterIndex >= 0) {
            String commonPrefix = prefix + remainingKey.substring(0, delimiterIndex + delimiter.length());
            entries.putIfAbsent(commonPrefix, new ListedObjectEntry(commonPrefix, null));
            return;
        }
        entries.putIfAbsent(object.key(), new ListedObjectEntry(object.key(), object));
    }

    private StoredObjectPage toDelimitedPage(List<ListedObjectEntry> entries, int limit) {
        boolean hasNext = entries.size() > limit;
        List<ListedObjectEntry> pageEntries = hasNext ? entries.subList(0, limit) : entries;
        List<StoredObjectRecord> objects = new ArrayList<>();
        List<String> prefixes = new ArrayList<>();
        for (ListedObjectEntry entry : pageEntries) {
            if (entry.isPrefix()) {
                prefixes.add(entry.key());
            } else {
                objects.add(entry.object());
            }
        }
        String nextCursor = hasNext ? pageEntries.get(pageEntries.size() - 1).key() : null;
        return new StoredObjectPage(objects, prefixes, nextCursor);
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
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object tags serialization failed.");
        }
    }

    private String checksumsJson(Map<String, String> checksums) {
        try {
            return OBJECT_MAPPER.writeValueAsString(checksums == null ? Map.of() : checksums);
        } catch (Exception exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object checksums serialization failed.");
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
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object tags deserialization failed.");
        }
    }

    private Map<String, String> checksumsFromJson(String rawChecksums) {
        if (rawChecksums == null || rawChecksums.isBlank()) {
            return Map.of();
        }
        try {
            Map<String, String> checksums = OBJECT_MAPPER.readValue(rawChecksums, TAG_MAP_TYPE);
            return checksums == null ? Map.of() : Map.copyOf(checksums);
        } catch (Exception exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object checksums deserialization failed.");
        }
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }

    private record ListedObjectEntry(String key, StoredObjectRecord object) {
        private boolean isPrefix() {
            return object == null;
        }
    }
}
