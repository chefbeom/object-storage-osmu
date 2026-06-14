package com.example.osmu.object.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectLifecycleRule;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbObjectLifecycleRuleRepository implements ObjectLifecycleRuleRepository {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final TypeReference<Map<String, String>> TAG_MAP_TYPE = new TypeReference<>() {
    };

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbObjectLifecycleRuleRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<ObjectLifecycleRule> findAll() {
        ensureSchema();
        String sql = """
                SELECT rule_id, name, enabled, priority, bucket_name, target_type, prefix, tags, retention_days, batch_size, created_at, updated_at
                FROM object_lifecycle_rules
                ORDER BY priority ASC, created_at ASC, rule_id ASC
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<ObjectLifecycleRule> rules = new ArrayList<>();
            while (resultSet.next()) {
                rules.add(mapRow(resultSet));
            }
            return rules;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<ObjectLifecycleRule> findById(String ruleId) {
        ensureSchema();
        String sql = """
                SELECT rule_id, name, enabled, priority, bucket_name, target_type, prefix, tags, retention_days, batch_size, created_at, updated_at
                FROM object_lifecycle_rules
                WHERE rule_id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, ruleId);
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
    public ObjectLifecycleRule save(ObjectLifecycleRule rule) {
        ensureSchema();
        String sql = """
                INSERT INTO object_lifecycle_rules
                    (rule_id, name, enabled, priority, bucket_name, target_type, prefix, tags, retention_days, batch_size, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    enabled = VALUES(enabled),
                    priority = VALUES(priority),
                    bucket_name = VALUES(bucket_name),
                    target_type = VALUES(target_type),
                    prefix = VALUES(prefix),
                    tags = VALUES(tags),
                    retention_days = VALUES(retention_days),
                    batch_size = VALUES(batch_size),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, rule.ruleId());
            statement.setString(2, rule.name());
            statement.setBoolean(3, rule.enabled());
            statement.setInt(4, rule.priority());
            statement.setString(5, rule.bucketName());
            statement.setString(6, rule.targetType());
            statement.setString(7, rule.prefix());
            statement.setString(8, tagsJson(rule.tags()));
            statement.setInt(9, rule.retentionDays());
            statement.setInt(10, rule.batchSize());
            statement.setTimestamp(11, Timestamp.from(rule.createdAt().toInstant()));
            statement.setTimestamp(12, Timestamp.from(rule.updatedAt().toInstant()));
            statement.executeUpdate();
            return rule;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void delete(String ruleId) {
        ensureSchema();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(
                     "DELETE FROM object_lifecycle_rules WHERE rule_id = ?")) {
            statement.setString(1, ruleId);
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
                CREATE TABLE IF NOT EXISTS object_lifecycle_rules (
                    rule_id VARCHAR(64) NOT NULL PRIMARY KEY,
                    name VARCHAR(128) NOT NULL,
                    enabled BOOLEAN NOT NULL,
                    priority INT NOT NULL DEFAULT 100,
                    bucket_name VARCHAR(63) NOT NULL DEFAULT '',
                    target_type VARCHAR(32) NOT NULL,
                    prefix VARCHAR(1024) NOT NULL,
                    tags TEXT NOT NULL,
                    retention_days INT NOT NULL,
                    batch_size INT NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    INDEX idx_object_lifecycle_rules_target (enabled, target_type, priority),
                    INDEX idx_object_lifecycle_rules_bucket_target (bucket_name, enabled, target_type, priority)
                )
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
            ensurePriorityColumn(connection);
            ensureBucketNameColumn(connection);
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void ensureBucketNameColumn(Connection connection) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                ALTER TABLE object_lifecycle_rules
                ADD COLUMN bucket_name VARCHAR(63) NOT NULL DEFAULT '' AFTER priority
                """)) {
            statement.executeUpdate();
        } catch (SQLException exception) {
            if (!isDuplicateColumn(exception)) {
                throw exception;
            }
        }
    }

    private void ensurePriorityColumn(Connection connection) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                ALTER TABLE object_lifecycle_rules
                ADD COLUMN priority INT NOT NULL DEFAULT 100 AFTER enabled
                """)) {
            statement.executeUpdate();
        } catch (SQLException exception) {
            if (!isDuplicateColumn(exception)) {
                throw exception;
            }
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private ObjectLifecycleRule mapRow(ResultSet resultSet) throws SQLException {
        return new ObjectLifecycleRule(
                resultSet.getString("rule_id"),
                resultSet.getString("name"),
                resultSet.getBoolean("enabled"),
                resultSet.getInt("priority"),
                resultSet.getString("bucket_name"),
                resultSet.getString("target_type"),
                resultSet.getString("prefix"),
                tagsFromJson(resultSet.getString("tags")),
                resultSet.getInt("retention_days"),
                resultSet.getInt("batch_size"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private String tagsJson(Map<String, String> tags) {
        try {
            return OBJECT_MAPPER.writeValueAsString(tags == null ? Map.of() : tags);
        } catch (Exception exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object lifecycle rule tags serialization failed.");
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
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Object lifecycle rule tags deserialization failed.");
        }
    }

    private boolean isDuplicateColumn(SQLException exception) {
        return exception.getErrorCode() == 1060 || "42S21".equals(exception.getSQLState());
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
