package com.example.osmu.object.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectRetentionPolicy;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbObjectRetentionPolicyRepository implements ObjectRetentionPolicyRepository {

    private final String url;
    private final String username;
    private final String password;
    private final boolean defaultEnabled;
    private final int defaultRetentionDays;
    private final int defaultBatchSize;
    private final int defaultVersionRetentionDays;
    private final int defaultVersionBatchSize;
    private volatile boolean schemaReady;

    public MariaDbObjectRetentionPolicyRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password,
            @Value("${osmu.object.retention.enabled:true}") boolean defaultEnabled,
            @Value("${osmu.object.retention.days:30}") int defaultRetentionDays,
            @Value("${osmu.object.retention.batch-size:100}") int defaultBatchSize,
            @Value("${osmu.object.version-retention.days:90}") int defaultVersionRetentionDays,
            @Value("${osmu.object.version-retention.batch-size:100}") int defaultVersionBatchSize
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
        this.defaultEnabled = defaultEnabled;
        this.defaultRetentionDays = Math.max(1, defaultRetentionDays);
        this.defaultBatchSize = Math.max(1, defaultBatchSize);
        this.defaultVersionRetentionDays = Math.max(1, defaultVersionRetentionDays);
        this.defaultVersionBatchSize = Math.max(1, defaultVersionBatchSize);
    }

    @Override
    public ObjectRetentionPolicy getPolicy() {
        ensureSchema();
        String sql = """
                SELECT enabled, retention_days, batch_size, version_retention_days, version_batch_size, updated_at
                FROM object_retention_policy
                WHERE id = 1
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            if (resultSet.next()) {
                return mapRow(resultSet);
            }
            return save(ObjectRetentionPolicy.initial(
                    defaultEnabled,
                    defaultRetentionDays,
                    defaultBatchSize,
                    defaultVersionRetentionDays,
                    defaultVersionBatchSize
            ));
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public ObjectRetentionPolicy save(ObjectRetentionPolicy policy) {
        ensureSchema();
        String sql = """
                INSERT INTO object_retention_policy
                    (id, enabled, retention_days, batch_size, version_retention_days, version_batch_size, updated_at)
                VALUES (1, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    enabled = VALUES(enabled),
                    retention_days = VALUES(retention_days),
                    batch_size = VALUES(batch_size),
                    version_retention_days = VALUES(version_retention_days),
                    version_batch_size = VALUES(version_batch_size),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setBoolean(1, policy.enabled());
            statement.setInt(2, policy.retentionDays());
            statement.setInt(3, policy.batchSize());
            statement.setInt(4, policy.versionRetentionDays());
            statement.setInt(5, policy.versionBatchSize());
            statement.setTimestamp(6, Timestamp.from(policy.updatedAt().toInstant()));
            statement.executeUpdate();
            return policy;
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
                CREATE TABLE IF NOT EXISTS object_retention_policy (
                    id TINYINT NOT NULL PRIMARY KEY,
                    enabled BOOLEAN NOT NULL,
                    retention_days INT NOT NULL,
                    batch_size INT NOT NULL,
                    version_retention_days INT NOT NULL,
                    version_batch_size INT NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    CONSTRAINT chk_object_retention_policy_singleton CHECK (id = 1),
                    CONSTRAINT chk_object_retention_policy_days CHECK (retention_days >= 1),
                    CONSTRAINT chk_object_retention_policy_batch CHECK (batch_size >= 1),
                    CONSTRAINT chk_object_retention_policy_version_days CHECK (version_retention_days >= 1),
                    CONSTRAINT chk_object_retention_policy_version_batch CHECK (version_batch_size >= 1)
                )
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
            seedDefaultPolicy(connection);
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void seedDefaultPolicy(Connection connection) throws SQLException {
        String sql = """
                INSERT INTO object_retention_policy
                    (id, enabled, retention_days, batch_size, version_retention_days, version_batch_size, updated_at)
                VALUES (1, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE id = id
                """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setBoolean(1, defaultEnabled);
            statement.setInt(2, defaultRetentionDays);
            statement.setInt(3, defaultBatchSize);
            statement.setInt(4, defaultVersionRetentionDays);
            statement.setInt(5, defaultVersionBatchSize);
            statement.setTimestamp(6, Timestamp.from(OffsetDateTime.now().toInstant()));
            statement.executeUpdate();
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private ObjectRetentionPolicy mapRow(ResultSet resultSet) throws SQLException {
        return new ObjectRetentionPolicy(
                resultSet.getBoolean("enabled"),
                resultSet.getInt("retention_days"),
                resultSet.getInt("batch_size"),
                resultSet.getInt("version_retention_days"),
                resultSet.getInt("version_batch_size"),
                resultSet.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
