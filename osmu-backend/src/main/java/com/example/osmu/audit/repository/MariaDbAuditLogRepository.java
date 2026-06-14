package com.example.osmu.audit.repository;

import com.example.osmu.audit.AuditLogEntry;
import com.example.osmu.audit.AuditLogQuery;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbAuditLogRepository implements AuditLogRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbAuditLogRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<AuditLogEntry> findRecent(int limit) {
        ensureSchema();
        String sql = """
                SELECT id, event_type, actor_id, target_type, target_id, result, message,
                       ip_address, user_agent, request_id, created_at
                FROM audit_logs
                ORDER BY id DESC
                LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, Math.max(0, limit));
            try (ResultSet resultSet = statement.executeQuery()) {
                List<AuditLogEntry> entries = new ArrayList<>();
                while (resultSet.next()) {
                    entries.add(mapRow(resultSet));
                }
                return entries;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<AuditLogEntry> find(AuditLogQuery query) {
        ensureSchema();
        StringBuilder sql = new StringBuilder("""
                SELECT id, event_type, actor_id, target_type, target_id, result, message,
                       ip_address, user_agent, request_id, created_at
                FROM audit_logs
                WHERE 1 = 1
                """);
        List<Object> parameters = new ArrayList<>();
        if (query.eventType() != null) {
            sql.append(" AND event_type = ?");
            parameters.add(query.eventType());
        }
        if (query.actorId() != null) {
            sql.append(" AND actor_id = ?");
            parameters.add(query.actorId());
        }
        if (query.requestId() != null) {
            sql.append(" AND request_id = ?");
            parameters.add(query.requestId());
        }
        if (query.targetType() != null) {
            sql.append(" AND target_type = ?");
            parameters.add(query.targetType());
        }
        if (query.targetId() != null) {
            sql.append(" AND target_id = ?");
            parameters.add(query.targetId());
        }
        if (query.result() != null) {
            sql.append(" AND result = ?");
            parameters.add(query.result());
        }
        if (query.cursor() != null) {
            sql.append(" AND id < ?");
            parameters.add(query.cursor());
        }
        if (query.from() != null) {
            sql.append(" AND created_at >= ?");
            parameters.add(Timestamp.from(query.from().toInstant()));
        }
        if (query.to() != null) {
            sql.append(" AND created_at <= ?");
            parameters.add(Timestamp.from(query.to().toInstant()));
        }
        sql.append(" ORDER BY id DESC LIMIT ?");
        parameters.add(Math.max(0, query.limit()));

        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            bindParameters(statement, parameters);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<AuditLogEntry> entries = new ArrayList<>();
                while (resultSet.next()) {
                    entries.add(mapRow(resultSet));
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
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM audit_logs";
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
    public AuditLogEntry save(AuditLogEntry entry) {
        ensureSchema();
        String sql = """
                INSERT INTO audit_logs
                    (id, event_type, actor_id, target_type, target_id, result, message,
                     ip_address, user_agent, request_id, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, entry.id());
            statement.setString(2, entry.eventType());
            statement.setString(3, entry.actorId());
            statement.setString(4, entry.targetType());
            statement.setString(5, entry.targetId());
            statement.setString(6, entry.result());
            statement.setString(7, entry.message());
            statement.setString(8, entry.ipAddress());
            statement.setString(9, entry.userAgent());
            statement.setString(10, entry.requestId());
            statement.setTimestamp(11, Timestamp.from(entry.createdAt().toInstant()));
            statement.executeUpdate();
            return entry;
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
                CREATE TABLE IF NOT EXISTS audit_logs (
                    id BIGINT NOT NULL PRIMARY KEY,
                    event_type VARCHAR(80) NOT NULL,
                    actor_id VARCHAR(120) NOT NULL,
                    target_type VARCHAR(80) NOT NULL,
                    target_id VARCHAR(255) NOT NULL,
                    result VARCHAR(40) NOT NULL,
                    message VARCHAR(500) NOT NULL,
                    ip_address VARCHAR(80),
                    user_agent VARCHAR(500),
                    request_id VARCHAR(120),
                    created_at TIMESTAMP NOT NULL,
                    INDEX idx_audit_logs_created_at (created_at),
                    INDEX idx_audit_logs_event_type (event_type),
                    INDEX idx_audit_logs_actor_id (actor_id),
                    INDEX idx_audit_logs_request_id (request_id),
                    INDEX idx_audit_logs_target_type (target_type),
                    INDEX idx_audit_logs_target_id (target_id),
                    INDEX idx_audit_logs_result (result)
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

    private AuditLogEntry mapRow(ResultSet resultSet) throws SQLException {
        return new AuditLogEntry(
                resultSet.getLong("id"),
                resultSet.getString("event_type"),
                resultSet.getString("actor_id"),
                resultSet.getString("target_type"),
                resultSet.getString("target_id"),
                resultSet.getString("result"),
                resultSet.getString("message"),
                resultSet.getString("ip_address"),
                resultSet.getString("user_agent"),
                resultSet.getString("request_id"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private void bindParameters(PreparedStatement statement, List<Object> parameters) throws SQLException {
        for (int index = 0; index < parameters.size(); index += 1) {
            Object parameter = parameters.get(index);
            if (parameter instanceof Timestamp timestamp) {
                statement.setTimestamp(index + 1, timestamp);
            } else if (parameter instanceof Integer integer) {
                statement.setInt(index + 1, integer);
            } else {
                statement.setString(index + 1, parameter.toString());
            }
        }
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
