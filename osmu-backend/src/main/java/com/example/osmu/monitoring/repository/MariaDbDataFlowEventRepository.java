package com.example.osmu.monitoring.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.monitoring.DataFlowEventFilter;
import com.example.osmu.monitoring.DataFlowEventRecord;
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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbDataFlowEventRepository implements DataFlowEventRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbDataFlowEventRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<DataFlowEventRecord> find(DataFlowEventFilter filter, int limit) {
        ensureSchema();
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        StringBuilder sql = new StringBuilder(selectSql()).append(" WHERE 1 = 1");
        List<Object> parameters = new ArrayList<>();
        if (safeFilter.bucketName() != null) {
            sql.append(" AND bucket_name = ?");
            parameters.add(safeFilter.bucketName());
        }
        if (safeFilter.actorId() != null) {
            sql.append(" AND actor_id = ?");
            parameters.add(safeFilter.actorId());
        }
        if (safeFilter.source() != null) {
            sql.append(" AND source = ?");
            parameters.add(safeFilter.source());
        }
        if (safeFilter.operation() != null) {
            sql.append(" AND operation = ?");
            parameters.add(safeFilter.operation());
        }
        if (safeFilter.status() != null) {
            sql.append(" AND status = ?");
            parameters.add(safeFilter.status());
        }
        if (safeFilter.from() != null) {
            sql.append(" AND created_at >= ?");
            parameters.add(Timestamp.from(safeFilter.from().toInstant()));
        }
        if (safeFilter.to() != null) {
            sql.append(" AND created_at <= ?");
            parameters.add(Timestamp.from(safeFilter.to().toInstant()));
        }
        sql.append(" ORDER BY created_at DESC, id DESC LIMIT ?");
        parameters.add(Math.max(0, limit));

        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            bindParameters(statement, parameters);
            try (ResultSet resultSet = statement.executeQuery()) {
                return collect(resultSet);
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public long nextId() {
        ensureSchema();
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM data_flow_events";
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
    public DataFlowEventRecord save(DataFlowEventRecord event) {
        ensureSchema();
        DataFlowEventRecord saved = event.id() == null ? event.withId(nextId()) : event;
        if (saved.createdAt() == null) {
            saved = saved.withCreatedAt(OffsetDateTime.now());
        }
        String sql = """
                INSERT INTO data_flow_events
                    (id, event_type, operation, direction, bucket_name, object_key, actor_id,
                     status, size_bytes, message, source, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, saved.id());
            statement.setString(2, saved.eventType());
            statement.setString(3, saved.operation());
            statement.setString(4, saved.direction());
            statement.setString(5, saved.bucketName());
            statement.setString(6, saved.objectKey());
            statement.setString(7, saved.actorId());
            statement.setString(8, saved.status());
            statement.setLong(9, saved.sizeBytes());
            statement.setString(10, saved.message());
            statement.setString(11, saved.source());
            statement.setTimestamp(12, timestamp(saved.createdAt()));
            statement.executeUpdate();
            return saved;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public int deleteBefore(OffsetDateTime cutoff, int limit) {
        ensureSchema();
        if (cutoff == null || limit <= 0) {
            return 0;
        }
        String sql = """
                DELETE FROM data_flow_events
                WHERE created_at < ?
                ORDER BY created_at ASC, id ASC
                LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setTimestamp(1, timestamp(cutoff));
            statement.setInt(2, limit);
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
                CREATE TABLE IF NOT EXISTS data_flow_events (
                    id BIGINT NOT NULL PRIMARY KEY,
                    event_type VARCHAR(32) NOT NULL,
                    operation VARCHAR(64) NOT NULL,
                    direction VARCHAR(32) NOT NULL,
                    bucket_name VARCHAR(255) NOT NULL,
                    object_key TEXT NULL,
                    actor_id VARCHAR(255) NULL,
                    status VARCHAR(32) NOT NULL,
                    size_bytes BIGINT NOT NULL DEFAULT 0,
                    message VARCHAR(512) NULL,
                    source VARCHAR(64) NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    INDEX idx_data_flow_events_created_at (created_at, id),
                    INDEX idx_data_flow_events_bucket (bucket_name, created_at),
                    INDEX idx_data_flow_events_actor (actor_id, created_at),
                    INDEX idx_data_flow_events_source (source, created_at),
                    INDEX idx_data_flow_events_operation (operation, created_at),
                    INDEX idx_data_flow_events_status (status, created_at)
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

    private String selectSql() {
        return """
                SELECT id, event_type, operation, direction, bucket_name, object_key, actor_id,
                       status, size_bytes, message, source, created_at
                FROM data_flow_events
                """;
    }

    private List<DataFlowEventRecord> collect(ResultSet resultSet) throws SQLException {
        List<DataFlowEventRecord> records = new ArrayList<>();
        while (resultSet.next()) {
            records.add(mapRow(resultSet));
        }
        return records;
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private DataFlowEventRecord mapRow(ResultSet resultSet) throws SQLException {
        return new DataFlowEventRecord(
                resultSet.getLong("id"),
                resultSet.getString("event_type"),
                resultSet.getString("operation"),
                resultSet.getString("direction"),
                resultSet.getString("bucket_name"),
                resultSet.getString("object_key"),
                resultSet.getString("actor_id"),
                resultSet.getString("status"),
                resultSet.getLong("size_bytes"),
                resultSet.getString("message"),
                resultSet.getString("source"),
                toOffset(resultSet.getTimestamp("created_at"))
        );
    }

    private void bindParameters(PreparedStatement statement, List<Object> parameters) throws SQLException {
        for (int index = 0; index < parameters.size(); index += 1) {
            Object parameter = parameters.get(index);
            if (parameter instanceof Timestamp timestamp) {
                statement.setTimestamp(index + 1, timestamp);
            } else if (parameter instanceof Integer integer) {
                statement.setInt(index + 1, integer);
            } else if (parameter instanceof Long longValue) {
                statement.setLong(index + 1, longValue);
            } else {
                statement.setString(index + 1, parameter.toString());
            }
        }
    }

    private Timestamp timestamp(OffsetDateTime value) {
        return value == null ? null : Timestamp.from(value.toInstant());
    }

    private OffsetDateTime toOffset(Timestamp value) {
        return value == null ? null : value.toInstant().atOffset(ZoneOffset.UTC);
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
