package com.example.osmu.storageexpansion.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storageexpansion.StorageExpansionExecutionRecord;
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
public class MariaDbStorageExpansionExecutionRepository implements StorageExpansionExecutionRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbStorageExpansionExecutionRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<StorageExpansionExecutionRecord> findAll() {
        ensureSchema();
        String sql = """
                SELECT id, request_id, execution_type, result, command_text, output_text,
                       external_url, artifact_sha256, exit_code, timed_out, notes, created_by, created_at
                FROM storage_expansion_executions
                ORDER BY id DESC
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<StorageExpansionExecutionRecord> executions = new ArrayList<>();
            while (resultSet.next()) {
                executions.add(mapRow(resultSet));
            }
            return executions;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public long countAll() {
        return count("SELECT COUNT(*) AS value FROM storage_expansion_executions");
    }

    @Override
    public long countByResult(String result) {
        ensureSchema();
        String sql = "SELECT COUNT(*) AS value FROM storage_expansion_executions WHERE result = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, result);
            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next() ? resultSet.getLong("value") : 0L;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public long countTimedOut() {
        return count("SELECT COUNT(*) AS value FROM storage_expansion_executions WHERE timed_out = TRUE");
    }

    @Override
    public Optional<StorageExpansionExecutionRecord> findLatest() {
        List<StorageExpansionExecutionRecord> records = findRecent(1);
        return records.isEmpty() ? Optional.empty() : Optional.of(records.get(0));
    }

    @Override
    public List<StorageExpansionExecutionRecord> findRecent(int limit) {
        ensureSchema();
        String sql = """
                SELECT id, request_id, execution_type, result, command_text, output_text,
                       external_url, artifact_sha256, exit_code, timed_out, notes, created_by, created_at
                FROM storage_expansion_executions
                ORDER BY id DESC
                LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, Math.max(0, limit));
            try (ResultSet resultSet = statement.executeQuery()) {
                List<StorageExpansionExecutionRecord> executions = new ArrayList<>();
                while (resultSet.next()) {
                    executions.add(mapRow(resultSet));
                }
                return executions;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<StorageExpansionExecutionRecord> findByRequestId(long requestId) {
        ensureSchema();
        String sql = """
                SELECT id, request_id, execution_type, result, command_text, output_text,
                       external_url, artifact_sha256, exit_code, timed_out, notes, created_by, created_at
                FROM storage_expansion_executions
                WHERE request_id = ?
                ORDER BY id DESC
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, requestId);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<StorageExpansionExecutionRecord> executions = new ArrayList<>();
                while (resultSet.next()) {
                    executions.add(mapRow(resultSet));
                }
                return executions;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<StorageExpansionExecutionRecord> findById(long id) {
        ensureSchema();
        String sql = """
                SELECT id, request_id, execution_type, result, command_text, output_text,
                       external_url, artifact_sha256, exit_code, timed_out, notes, created_by, created_at
                FROM storage_expansion_executions
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
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
    public long nextId() {
        ensureSchema();
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM storage_expansion_executions";
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
    public StorageExpansionExecutionRecord save(StorageExpansionExecutionRecord execution) {
        ensureSchema();
        String sql = """
                INSERT INTO storage_expansion_executions
                    (id, request_id, execution_type, result, command_text, output_text,
                     external_url, artifact_sha256, exit_code, timed_out, notes, created_by, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, execution.id());
            statement.setLong(2, execution.requestId());
            statement.setString(3, execution.executionType());
            statement.setString(4, execution.result());
            statement.setString(5, execution.command());
            statement.setString(6, execution.output());
            statement.setString(7, execution.externalUrl());
            statement.setString(8, execution.artifactSha256());
            if (execution.exitCode() == null) {
                statement.setNull(9, java.sql.Types.INTEGER);
            } else {
                statement.setInt(9, execution.exitCode());
            }
            statement.setBoolean(10, execution.timedOut());
            statement.setString(11, execution.notes());
            statement.setString(12, execution.createdBy());
            statement.setTimestamp(13, Timestamp.from(execution.createdAt().toInstant()));
            statement.executeUpdate();
            return execution;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public long countOutputsBefore(OffsetDateTime cutoff) {
        ensureSchema();
        String sql = """
                SELECT COUNT(*) AS retained_output_count
                FROM storage_expansion_executions
                WHERE output_text IS NOT NULL
                  AND output_text <> ''
                  AND output_text NOT LIKE '[redacted by execution log retention policy]%'
                  AND created_at < ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setTimestamp(1, Timestamp.from(cutoff.toInstant()));
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    return resultSet.getLong("retained_output_count");
                }
                return 0L;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public int redactOutputsBefore(OffsetDateTime cutoff, int batchSize, String redactedOutput) {
        ensureSchema();
        String sql = """
                UPDATE storage_expansion_executions
                SET output_text = ?
                WHERE output_text IS NOT NULL
                  AND output_text <> ''
                  AND output_text NOT LIKE '[redacted by execution log retention policy]%'
                  AND created_at < ?
                ORDER BY created_at ASC, id ASC
                LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, redactedOutput);
            statement.setTimestamp(2, Timestamp.from(cutoff.toInstant()));
            statement.setInt(3, Math.max(1, batchSize));
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
                CREATE TABLE IF NOT EXISTS storage_expansion_executions (
                    id BIGINT NOT NULL PRIMARY KEY,
                    request_id BIGINT NOT NULL,
                    execution_type VARCHAR(32) NOT NULL,
                    result VARCHAR(32) NOT NULL,
                    command_text VARCHAR(1024) NULL,
                    output_text MEDIUMTEXT NULL,
                    external_url VARCHAR(1024) NULL,
                    artifact_sha256 VARCHAR(128) NULL,
                    exit_code INT NULL,
                    timed_out BOOLEAN NOT NULL DEFAULT FALSE,
                    notes VARCHAR(1024) NULL,
                    created_by VARCHAR(128) NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    KEY idx_storage_expansion_execution_request (request_id, id),
                    KEY idx_storage_expansion_execution_type (execution_type, result),
                    KEY idx_storage_expansion_execution_result (result, id),
                    KEY idx_storage_expansion_execution_timeout (timed_out, id)
                )
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
            addColumnIfMissing(connection, "exit_code INT NULL");
            addColumnIfMissing(connection, "timed_out BOOLEAN NOT NULL DEFAULT FALSE");
            addIndexIfMissing(connection, "idx_storage_expansion_execution_result", "result, id");
            addIndexIfMissing(connection, "idx_storage_expansion_execution_timeout", "timed_out, id");
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void addColumnIfMissing(Connection connection, String columnDefinition) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "ALTER TABLE storage_expansion_executions ADD COLUMN IF NOT EXISTS " + columnDefinition)) {
            statement.executeUpdate();
        }
    }

    private void addIndexIfMissing(Connection connection, String indexName, String columns) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "CREATE INDEX IF NOT EXISTS " + indexName + " ON storage_expansion_executions (" + columns + ")")) {
            statement.executeUpdate();
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private long count(String sql) {
        ensureSchema();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            return resultSet.next() ? resultSet.getLong("value") : 0L;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private StorageExpansionExecutionRecord mapRow(ResultSet resultSet) throws SQLException {
        Integer exitCode = resultSet.getObject("exit_code") == null ? null : resultSet.getInt("exit_code");
        return new StorageExpansionExecutionRecord(
                resultSet.getLong("id"),
                resultSet.getLong("request_id"),
                resultSet.getString("execution_type"),
                resultSet.getString("result"),
                resultSet.getString("command_text"),
                resultSet.getString("output_text"),
                resultSet.getString("external_url"),
                resultSet.getString("artifact_sha256"),
                exitCode,
                resultSet.getBoolean("timed_out"),
                resultSet.getString("notes"),
                resultSet.getString("created_by"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
