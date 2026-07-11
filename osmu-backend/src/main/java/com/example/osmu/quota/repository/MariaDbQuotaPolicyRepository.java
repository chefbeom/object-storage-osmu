package com.example.osmu.quota.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.quota.QuotaPolicy;
import com.example.osmu.quota.QuotaPolicyHistory;
import com.example.osmu.quota.QuotaPolicyPageCursor;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbQuotaPolicyRepository implements QuotaPolicyRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbQuotaPolicyRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<QuotaPolicy> findPage(QuotaPolicyPageCursor cursor, int limit) {
        ensureSchema();
        String sql = cursor == null ? """
                SELECT id, target_type, target_id, quota_bytes, created_at, updated_at
                FROM quota_policies
                ORDER BY target_type, target_id
                LIMIT ?
                """ : """
                SELECT id, target_type, target_id, quota_bytes, created_at, updated_at
                FROM quota_policies
                WHERE target_type > ?
                   OR (target_type = ? AND target_id > ?)
                ORDER BY target_type, target_id
                LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            if (cursor == null) {
                statement.setInt(1, limit);
            } else {
                statement.setString(1, cursor.targetType());
                statement.setString(2, cursor.targetType());
                statement.setLong(3, cursor.targetId());
                statement.setInt(4, limit);
            }
            try (ResultSet resultSet = statement.executeQuery()) {
                List<QuotaPolicy> policies = new ArrayList<>();
                while (resultSet.next()) {
                    policies.add(mapRow(resultSet));
                }
                return policies;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<QuotaPolicy> findAllForDashboardSummary() {
        ensureSchema();
        String sql = """
                SELECT id, target_type, target_id, quota_bytes, created_at, updated_at
                FROM quota_policies
                ORDER BY target_type, target_id
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<QuotaPolicy> policies = new ArrayList<>();
            while (resultSet.next()) {
                policies.add(mapRow(resultSet));
            }
            return policies;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<QuotaPolicy> findByTarget(String targetType, long targetId) {
        ensureSchema();
        String sql = """
                SELECT id, target_type, target_id, quota_bytes, created_at, updated_at
                FROM quota_policies
                WHERE target_type = ? AND target_id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, targetType);
            statement.setLong(2, targetId);
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
    public List<QuotaPolicyHistory> findHistory(int limit) {
        ensureSchema();
        String sql = """
                SELECT id, target_type, target_id, action, previous_quota_bytes, new_quota_bytes, actor_id, reason, created_at
                FROM quota_policy_history
                ORDER BY id DESC
                LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, limit);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<QuotaPolicyHistory> entries = new ArrayList<>();
                while (resultSet.next()) {
                    entries.add(mapHistoryRow(resultSet));
                }
                return entries;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public long nextId() {
        ensureSchema();
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM quota_policies";
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
    public long nextHistoryId() {
        ensureSchema();
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM quota_policy_history";
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
    public QuotaPolicy save(QuotaPolicy policy) {
        ensureSchema();
        String sql = """
                INSERT INTO quota_policies
                    (id, target_type, target_id, quota_bytes, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    quota_bytes = VALUES(quota_bytes),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, policy.id());
            statement.setString(2, policy.targetType());
            statement.setLong(3, policy.targetId());
            statement.setLong(4, policy.quotaBytes());
            statement.setTimestamp(5, Timestamp.from(policy.createdAt().toInstant()));
            statement.setTimestamp(6, Timestamp.from(policy.updatedAt().toInstant()));
            statement.executeUpdate();
            return policy;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public QuotaPolicyHistory saveHistory(QuotaPolicyHistory history) {
        ensureSchema();
        String sql = """
                INSERT INTO quota_policy_history
                    (id, target_type, target_id, action, previous_quota_bytes, new_quota_bytes, actor_id, reason, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, history.id());
            statement.setString(2, history.targetType());
            statement.setLong(3, history.targetId());
            statement.setString(4, history.action());
            setNullableLong(statement, 5, history.previousQuotaBytes());
            setNullableLong(statement, 6, history.newQuotaBytes());
            statement.setString(7, history.actorId());
            statement.setString(8, history.reason());
            statement.setTimestamp(9, Timestamp.from(history.createdAt().toInstant()));
            statement.executeUpdate();
            return history;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteByTarget(String targetType, long targetId) {
        ensureSchema();
        String sql = "DELETE FROM quota_policies WHERE target_type = ? AND target_id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, targetType);
            statement.setLong(2, targetId);
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
        String policySql = """
                CREATE TABLE IF NOT EXISTS quota_policies (
                    id BIGINT NOT NULL PRIMARY KEY,
                    target_type VARCHAR(32) NOT NULL,
                    target_id BIGINT NOT NULL,
                    quota_bytes BIGINT NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    UNIQUE KEY uk_quota_target (target_type, target_id)
                )
                """;
        String historySql = """
                CREATE TABLE IF NOT EXISTS quota_policy_history (
                    id BIGINT NOT NULL PRIMARY KEY,
                    target_type VARCHAR(32) NOT NULL,
                    target_id BIGINT NOT NULL,
                    action VARCHAR(32) NOT NULL,
                    previous_quota_bytes BIGINT NULL,
                    new_quota_bytes BIGINT NULL,
                    actor_id VARCHAR(128) NOT NULL,
                    reason VARCHAR(512) NULL,
                    created_at TIMESTAMP NOT NULL,
                    KEY idx_quota_policy_history_target (target_type, target_id, id),
                    KEY idx_quota_policy_history_created_at (created_at)
                )
                """;
        String historyReasonSql = """
                ALTER TABLE quota_policy_history
                    ADD COLUMN IF NOT EXISTS reason VARCHAR(512) NULL AFTER actor_id
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(policySql);
             PreparedStatement historyStatement = connection.prepareStatement(historySql);
             PreparedStatement historyReasonStatement = connection.prepareStatement(historyReasonSql)) {
            statement.executeUpdate();
            historyStatement.executeUpdate();
            historyReasonStatement.executeUpdate();
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private QuotaPolicy mapRow(ResultSet resultSet) throws SQLException {
        return new QuotaPolicy(
                resultSet.getLong("id"),
                resultSet.getString("target_type"),
                resultSet.getLong("target_id"),
                resultSet.getLong("quota_bytes"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private QuotaPolicyHistory mapHistoryRow(ResultSet resultSet) throws SQLException {
        return new QuotaPolicyHistory(
                resultSet.getLong("id"),
                resultSet.getString("target_type"),
                resultSet.getLong("target_id"),
                resultSet.getString("action"),
                nullableLong(resultSet, "previous_quota_bytes"),
                nullableLong(resultSet, "new_quota_bytes"),
                resultSet.getString("actor_id"),
                resultSet.getString("reason"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private Long nullableLong(ResultSet resultSet, String column) throws SQLException {
        long value = resultSet.getLong(column);
        return resultSet.wasNull() ? null : value;
    }

    private void setNullableLong(PreparedStatement statement, int index, Long value) throws SQLException {
        if (value == null) {
            statement.setNull(index, java.sql.Types.BIGINT);
            return;
        }
        statement.setLong(index, value);
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
