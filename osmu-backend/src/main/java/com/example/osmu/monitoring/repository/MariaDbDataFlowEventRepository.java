package com.example.osmu.monitoring.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.monitoring.DataFlowDailyRollupPointResponse;
import com.example.osmu.monitoring.DataFlowEventFilter;
import com.example.osmu.monitoring.DataFlowEventRecord;
import com.example.osmu.monitoring.DataFlowMonthlyRollupPointResponse;
import java.sql.Connection;
import java.sql.Date;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDate;
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
        List<Object> parameters = appendFilter(sql, safeFilter);
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
    public List<DataFlowDailyRollupPointResponse> dailyRollup(DataFlowEventFilter filter, int limit) {
        ensureSchema();
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        StringBuilder sql = new StringBuilder("""
                SELECT
                    DATE(created_at) AS rollup_day,
                    bucket_name,
                    LOWER(source) AS source,
                    LOWER(operation) AS operation,
                    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS success_count,
                    SUM(CASE WHEN event_type = 'FAILURE' OR status = 'FAILED' THEN 1 ELSE 0 END) AS failure_count,
                    SUM(CASE WHEN event_type = 'CANCEL' OR status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_count,
                    COUNT(*) AS total_count,
                    SUM(CASE WHEN event_type = 'UPLOAD' AND status = 'SUCCESS' THEN size_bytes ELSE 0 END) AS uploaded_bytes,
                    SUM(CASE WHEN event_type = 'DOWNLOAD' AND status = 'SUCCESS' THEN size_bytes ELSE 0 END) AS downloaded_bytes,
                    SUM(CASE WHEN event_type = 'COPY' AND status = 'SUCCESS' THEN size_bytes ELSE 0 END) AS copied_bytes
                FROM data_flow_events
                WHERE 1 = 1
                """);
        List<Object> parameters = appendFilter(sql, safeFilter);
        sql.append("""
                GROUP BY rollup_day, bucket_name, LOWER(source), LOWER(operation)
                ORDER BY rollup_day DESC, total_count DESC, bucket_name ASC, source ASC, operation ASC
                LIMIT ?
                """);
        parameters.add(Math.max(0, limit));
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            bindParameters(statement, parameters);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<DataFlowDailyRollupPointResponse> records = new ArrayList<>();
                while (resultSet.next()) {
                    long uploadedBytes = resultSet.getLong("uploaded_bytes");
                    long downloadedBytes = resultSet.getLong("downloaded_bytes");
                    long copiedBytes = resultSet.getLong("copied_bytes");
                    records.add(new DataFlowDailyRollupPointResponse(
                            resultSet.getDate("rollup_day").toLocalDate(),
                            resultSet.getString("bucket_name"),
                            resultSet.getString("source"),
                            resultSet.getString("operation"),
                            resultSet.getLong("success_count"),
                            resultSet.getLong("failure_count"),
                            resultSet.getLong("cancel_count"),
                            resultSet.getLong("total_count"),
                            uploadedBytes,
                            downloadedBytes,
                            copiedBytes,
                            uploadedBytes + downloadedBytes + copiedBytes
                    ));
                }
                return records;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<DataFlowDailyRollupPointResponse> refreshDailyRollup(DataFlowEventFilter filter, int limit) {
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        List<DataFlowDailyRollupPointResponse> points = dailyRollup(safeFilter, limit);
        if (points.isEmpty()) {
            return points;
        }
        String sql = """
                INSERT INTO data_flow_daily_rollups
                    (rollup_day, bucket_name, actor_id, source, operation, status, success_count, failure_count,
                     cancel_count, total_count, uploaded_bytes, downloaded_bytes, copied_bytes,
                     total_bytes, refreshed_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    success_count = VALUES(success_count),
                    failure_count = VALUES(failure_count),
                    cancel_count = VALUES(cancel_count),
                    total_count = VALUES(total_count),
                    uploaded_bytes = VALUES(uploaded_bytes),
                    downloaded_bytes = VALUES(downloaded_bytes),
                    copied_bytes = VALUES(copied_bytes),
                    total_bytes = VALUES(total_bytes),
                    refreshed_at = VALUES(refreshed_at)
                """;
        Timestamp refreshedAt = Timestamp.from(OffsetDateTime.now(ZoneOffset.UTC).toInstant());
        String actorId = dimensionValue(safeFilter.actorId());
        String status = dimensionValue(safeFilter.status());
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            for (DataFlowDailyRollupPointResponse point : points) {
                statement.setDate(1, Date.valueOf(point.day()));
                statement.setString(2, point.bucketName());
                statement.setString(3, actorId);
                statement.setString(4, point.source());
                statement.setString(5, point.operation());
                statement.setString(6, status);
                statement.setLong(7, point.successCount());
                statement.setLong(8, point.failureCount());
                statement.setLong(9, point.cancelCount());
                statement.setLong(10, point.totalCount());
                statement.setLong(11, point.uploadedBytes());
                statement.setLong(12, point.downloadedBytes());
                statement.setLong(13, point.copiedBytes());
                statement.setLong(14, point.totalBytes());
                statement.setTimestamp(15, refreshedAt);
                statement.addBatch();
            }
            statement.executeBatch();
            return points;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<DataFlowDailyRollupPointResponse> materializedDailyRollup(DataFlowEventFilter filter, int limit) {
        ensureSchema();
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        StringBuilder sql = new StringBuilder("""
                SELECT
                    rollup_day,
                    bucket_name,
                    source,
                    operation,
                    success_count,
                    failure_count,
                    cancel_count,
                    total_count,
                    uploaded_bytes,
                    downloaded_bytes,
                    copied_bytes,
                    total_bytes
                FROM data_flow_daily_rollups
                WHERE 1 = 1
                """);
        List<Object> parameters = appendMaterializedFilter(sql, safeFilter);
        sql.append("""
                ORDER BY rollup_day DESC, total_count DESC, bucket_name ASC, source ASC, operation ASC
                LIMIT ?
                """);
        parameters.add(Math.max(0, limit));
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            bindParameters(statement, parameters);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<DataFlowDailyRollupPointResponse> records = new ArrayList<>();
                while (resultSet.next()) {
                    records.add(new DataFlowDailyRollupPointResponse(
                            resultSet.getDate("rollup_day").toLocalDate(),
                            resultSet.getString("bucket_name"),
                            resultSet.getString("source"),
                            resultSet.getString("operation"),
                            resultSet.getLong("success_count"),
                            resultSet.getLong("failure_count"),
                            resultSet.getLong("cancel_count"),
                            resultSet.getLong("total_count"),
                            resultSet.getLong("uploaded_bytes"),
                            resultSet.getLong("downloaded_bytes"),
                            resultSet.getLong("copied_bytes"),
                            resultSet.getLong("total_bytes")
                    ));
                }
                return records;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<DataFlowMonthlyRollupPointResponse> monthlyRollup(DataFlowEventFilter filter, int limit) {
        ensureSchema();
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        StringBuilder sql = new StringBuilder("""
                SELECT
                    CONCAT(YEAR(created_at), '-', LPAD(MONTH(created_at), 2, '0')) AS rollup_month,
                    bucket_name,
                    LOWER(source) AS source,
                    LOWER(operation) AS operation,
                    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS success_count,
                    SUM(CASE WHEN event_type = 'FAILURE' OR status = 'FAILED' THEN 1 ELSE 0 END) AS failure_count,
                    SUM(CASE WHEN event_type = 'CANCEL' OR status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancel_count,
                    COUNT(*) AS total_count,
                    SUM(CASE WHEN event_type = 'UPLOAD' AND status = 'SUCCESS' THEN size_bytes ELSE 0 END) AS uploaded_bytes,
                    SUM(CASE WHEN event_type = 'DOWNLOAD' AND status = 'SUCCESS' THEN size_bytes ELSE 0 END) AS downloaded_bytes,
                    SUM(CASE WHEN event_type = 'COPY' AND status = 'SUCCESS' THEN size_bytes ELSE 0 END) AS copied_bytes
                FROM data_flow_events
                WHERE 1 = 1
                """);
        List<Object> parameters = appendFilter(sql, safeFilter);
        sql.append("""
                GROUP BY YEAR(created_at), MONTH(created_at), bucket_name, LOWER(source), LOWER(operation)
                ORDER BY YEAR(created_at) DESC, MONTH(created_at) DESC, total_count DESC, bucket_name ASC, source ASC, operation ASC
                LIMIT ?
                """);
        parameters.add(Math.max(0, limit));
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            bindParameters(statement, parameters);
            try (ResultSet resultSet = statement.executeQuery()) {
                return collectMonthlyRollup(resultSet);
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<DataFlowMonthlyRollupPointResponse> materializedMonthlyRollup(DataFlowEventFilter filter, int limit) {
        ensureSchema();
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        StringBuilder sql = new StringBuilder("""
                SELECT
                    CONCAT(YEAR(rollup_day), '-', LPAD(MONTH(rollup_day), 2, '0')) AS rollup_month,
                    bucket_name,
                    source,
                    operation,
                    SUM(success_count) AS success_count,
                    SUM(failure_count) AS failure_count,
                    SUM(cancel_count) AS cancel_count,
                    SUM(total_count) AS total_count,
                    SUM(uploaded_bytes) AS uploaded_bytes,
                    SUM(downloaded_bytes) AS downloaded_bytes,
                    SUM(copied_bytes) AS copied_bytes
                FROM data_flow_daily_rollups
                WHERE 1 = 1
                """);
        List<Object> parameters = appendMaterializedFilter(sql, safeFilter);
        sql.append("""
                GROUP BY YEAR(rollup_day), MONTH(rollup_day), bucket_name, source, operation
                ORDER BY YEAR(rollup_day) DESC, MONTH(rollup_day) DESC, total_count DESC, bucket_name ASC, source ASC, operation ASC
                LIMIT ?
                """);
        parameters.add(Math.max(0, limit));
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            bindParameters(statement, parameters);
            try (ResultSet resultSet = statement.executeQuery()) {
                return collectMonthlyRollup(resultSet);
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
    public int deleteMaterializedRollupsBefore(LocalDate cutoffDay, int limit) {
        ensureSchema();
        if (cutoffDay == null || limit <= 0) {
            return 0;
        }
        String sql = """
                DELETE FROM data_flow_daily_rollups
                WHERE rollup_day < ?
                ORDER BY rollup_day ASC, bucket_name ASC, actor_id ASC, source ASC, operation ASC, status ASC
                LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setDate(1, Date.valueOf(cutoffDay));
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
        String eventSql = """
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
        String rollupSql = """
                CREATE TABLE IF NOT EXISTS data_flow_daily_rollups (
                    rollup_day DATE NOT NULL,
                    bucket_name VARCHAR(255) NOT NULL,
                    actor_id VARCHAR(255) NOT NULL DEFAULT '',
                    source VARCHAR(64) NOT NULL,
                    operation VARCHAR(64) NOT NULL,
                    status VARCHAR(32) NOT NULL DEFAULT '',
                    success_count BIGINT NOT NULL DEFAULT 0,
                    failure_count BIGINT NOT NULL DEFAULT 0,
                    cancel_count BIGINT NOT NULL DEFAULT 0,
                    total_count BIGINT NOT NULL DEFAULT 0,
                    uploaded_bytes BIGINT NOT NULL DEFAULT 0,
                    downloaded_bytes BIGINT NOT NULL DEFAULT 0,
                    copied_bytes BIGINT NOT NULL DEFAULT 0,
                    total_bytes BIGINT NOT NULL DEFAULT 0,
                    refreshed_at TIMESTAMP NOT NULL,
                    PRIMARY KEY (rollup_day, bucket_name, actor_id, source, operation, status),
                    INDEX idx_data_flow_daily_rollups_bucket (bucket_name, rollup_day),
                    INDEX idx_data_flow_daily_rollups_actor (actor_id, rollup_day),
                    INDEX idx_data_flow_daily_rollups_operation (operation, rollup_day),
                    INDEX idx_data_flow_daily_rollups_status (status, rollup_day),
                    INDEX idx_data_flow_daily_rollups_refreshed_at (refreshed_at)
                )
                """;
        try (Connection connection = connect();
             PreparedStatement eventStatement = connection.prepareStatement(eventSql);
             PreparedStatement rollupStatement = connection.prepareStatement(rollupSql)) {
            eventStatement.executeUpdate();
            rollupStatement.executeUpdate();
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

    private List<DataFlowMonthlyRollupPointResponse> collectMonthlyRollup(ResultSet resultSet) throws SQLException {
        List<DataFlowMonthlyRollupPointResponse> records = new ArrayList<>();
        while (resultSet.next()) {
            long uploadedBytes = resultSet.getLong("uploaded_bytes");
            long downloadedBytes = resultSet.getLong("downloaded_bytes");
            long copiedBytes = resultSet.getLong("copied_bytes");
            records.add(new DataFlowMonthlyRollupPointResponse(
                    resultSet.getString("rollup_month"),
                    resultSet.getString("bucket_name"),
                    resultSet.getString("source"),
                    resultSet.getString("operation"),
                    resultSet.getLong("success_count"),
                    resultSet.getLong("failure_count"),
                    resultSet.getLong("cancel_count"),
                    resultSet.getLong("total_count"),
                    uploadedBytes,
                    downloadedBytes,
                    copiedBytes,
                    uploadedBytes + downloadedBytes + copiedBytes
            ));
        }
        return records;
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private List<Object> appendFilter(StringBuilder sql, DataFlowEventFilter safeFilter) {
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
        return parameters;
    }

    private List<Object> appendMaterializedFilter(StringBuilder sql, DataFlowEventFilter safeFilter) {
        List<Object> parameters = new ArrayList<>();
        if (safeFilter.bucketName() != null) {
            sql.append(" AND bucket_name = ?");
            parameters.add(safeFilter.bucketName());
        }
        sql.append(" AND actor_id = ?");
        parameters.add(dimensionValue(safeFilter.actorId()));
        if (safeFilter.source() != null) {
            sql.append(" AND source = ?");
            parameters.add(safeFilter.source());
        }
        if (safeFilter.operation() != null) {
            sql.append(" AND operation = ?");
            parameters.add(safeFilter.operation());
        }
        sql.append(" AND status = ?");
        parameters.add(dimensionValue(safeFilter.status()));
        if (safeFilter.from() != null) {
            sql.append(" AND rollup_day >= ?");
            parameters.add(Date.valueOf(safeFilter.from().withOffsetSameInstant(ZoneOffset.UTC).toLocalDate()));
        }
        if (safeFilter.to() != null) {
            sql.append(" AND rollup_day <= ?");
            parameters.add(Date.valueOf(safeFilter.to().withOffsetSameInstant(ZoneOffset.UTC).toLocalDate()));
        }
        return parameters;
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
            } else if (parameter instanceof Date date) {
                statement.setDate(index + 1, date);
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

    private String dimensionValue(String value) {
        return value == null || value.isBlank() ? "" : value;
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
