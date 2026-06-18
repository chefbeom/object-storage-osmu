package com.example.osmu.storageexpansion.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storageexpansion.StorageExpansionRequestAggregate;
import com.example.osmu.storageexpansion.StorageExpansionRequestRecord;
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
public class MariaDbStorageExpansionRequestRepository implements StorageExpansionRequestRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbStorageExpansionRequestRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<StorageExpansionRequestRecord> findAll() {
        ensureSchema();
        String sql = """
                SELECT id, requested_capacity_bytes, server_count, volumes_per_server, volume_size_bytes,
                       estimated_raw_capacity_bytes, estimated_usable_capacity_bytes,
                       status, reason, created_by, applied_by, applied_at, applied_evidence, created_at, updated_at
                FROM storage_expansion_requests
                ORDER BY id DESC
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<StorageExpansionRequestRecord> requests = new ArrayList<>();
            while (resultSet.next()) {
                requests.add(mapRow(resultSet));
            }
            return requests;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public StorageExpansionRequestAggregate aggregate() {
        ensureSchema();
        String sql = """
                SELECT
                    COUNT(*) AS request_count,
                    COALESCE(SUM(CASE WHEN status IN ('PLANNED', 'APPROVED') THEN 1 ELSE 0 END), 0) AS open_request_count,
                    COALESCE(SUM(CASE WHEN status = 'PLANNED' THEN 1 ELSE 0 END), 0) AS planned_request_count,
                    COALESCE(SUM(CASE WHEN status = 'APPROVED' THEN 1 ELSE 0 END), 0) AS approved_request_count,
                    COALESCE(SUM(CASE WHEN status = 'APPLIED' THEN 1 ELSE 0 END), 0) AS applied_request_count,
                    COALESCE(SUM(CASE WHEN status = 'REJECTED' THEN 1 ELSE 0 END), 0) AS rejected_request_count,
                    COALESCE(SUM(requested_capacity_bytes), 0) AS total_requested_capacity_bytes,
                    COALESCE(SUM(CASE WHEN status IN ('PLANNED', 'APPROVED') THEN requested_capacity_bytes ELSE 0 END), 0) AS open_requested_capacity_bytes,
                    COALESCE(SUM(estimated_usable_capacity_bytes), 0) AS total_estimated_usable_capacity_bytes,
                    COALESCE(SUM(CASE WHEN status IN ('PLANNED', 'APPROVED') THEN estimated_usable_capacity_bytes ELSE 0 END), 0) AS open_estimated_usable_capacity_bytes
                FROM storage_expansion_requests
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            if (!resultSet.next()) {
                return emptyAggregate();
            }
            return new StorageExpansionRequestAggregate(
                    resultSet.getLong("request_count"),
                    resultSet.getLong("open_request_count"),
                    resultSet.getLong("planned_request_count"),
                    resultSet.getLong("approved_request_count"),
                    resultSet.getLong("applied_request_count"),
                    resultSet.getLong("rejected_request_count"),
                    resultSet.getLong("total_requested_capacity_bytes"),
                    resultSet.getLong("open_requested_capacity_bytes"),
                    resultSet.getLong("total_estimated_usable_capacity_bytes"),
                    resultSet.getLong("open_estimated_usable_capacity_bytes")
            );
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<StorageExpansionRequestRecord> findLatest() {
        ensureSchema();
        String sql = """
                SELECT id, requested_capacity_bytes, server_count, volumes_per_server, volume_size_bytes,
                       estimated_raw_capacity_bytes, estimated_usable_capacity_bytes,
                       status, reason, created_by, applied_by, applied_at, applied_evidence, created_at, updated_at
                FROM storage_expansion_requests
                ORDER BY id DESC
                LIMIT 1
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            if (resultSet.next()) {
                return Optional.of(mapRow(resultSet));
            }
            return Optional.empty();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<StorageExpansionRequestRecord> findById(long id) {
        ensureSchema();
        String sql = """
                SELECT id, requested_capacity_bytes, server_count, volumes_per_server, volume_size_bytes,
                       estimated_raw_capacity_bytes, estimated_usable_capacity_bytes,
                       status, reason, created_by, applied_by, applied_at, applied_evidence, created_at, updated_at
                FROM storage_expansion_requests
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
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM storage_expansion_requests";
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
    public StorageExpansionRequestRecord save(StorageExpansionRequestRecord request) {
        ensureSchema();
        String sql = """
                INSERT INTO storage_expansion_requests
                    (id, requested_capacity_bytes, server_count, volumes_per_server, volume_size_bytes,
                     estimated_raw_capacity_bytes, estimated_usable_capacity_bytes,
                     status, reason, created_by, applied_by, applied_at, applied_evidence, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    requested_capacity_bytes = VALUES(requested_capacity_bytes),
                    server_count = VALUES(server_count),
                    volumes_per_server = VALUES(volumes_per_server),
                    volume_size_bytes = VALUES(volume_size_bytes),
                    estimated_raw_capacity_bytes = VALUES(estimated_raw_capacity_bytes),
                    estimated_usable_capacity_bytes = VALUES(estimated_usable_capacity_bytes),
                    status = VALUES(status),
                    reason = VALUES(reason),
                    applied_by = VALUES(applied_by),
                    applied_at = VALUES(applied_at),
                    applied_evidence = VALUES(applied_evidence),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, request.id());
            statement.setLong(2, request.requestedCapacityBytes());
            statement.setInt(3, request.serverCount());
            statement.setInt(4, request.volumesPerServer());
            statement.setLong(5, request.volumeSizeBytes());
            statement.setLong(6, request.estimatedRawCapacityBytes());
            statement.setLong(7, request.estimatedUsableCapacityBytes());
            statement.setString(8, request.status());
            statement.setString(9, request.reason());
            statement.setString(10, request.createdBy());
            statement.setString(11, request.appliedBy());
            statement.setTimestamp(12, request.appliedAt() == null ? null : Timestamp.from(request.appliedAt().toInstant()));
            statement.setString(13, request.appliedEvidence());
            statement.setTimestamp(14, Timestamp.from(request.createdAt().toInstant()));
            statement.setTimestamp(15, Timestamp.from(request.updatedAt().toInstant()));
            statement.executeUpdate();
            return request;
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
                CREATE TABLE IF NOT EXISTS storage_expansion_requests (
                    id BIGINT NOT NULL PRIMARY KEY,
                    requested_capacity_bytes BIGINT NOT NULL,
                    server_count INT NOT NULL,
                    volumes_per_server INT NOT NULL,
                    volume_size_bytes BIGINT NOT NULL,
                    estimated_raw_capacity_bytes BIGINT NOT NULL,
                    estimated_usable_capacity_bytes BIGINT NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    reason VARCHAR(512) NULL,
                    created_by VARCHAR(128) NOT NULL,
                    applied_by VARCHAR(128) NULL,
                    applied_at TIMESTAMP NULL,
                    applied_evidence VARCHAR(512) NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    KEY idx_storage_expansion_status (status, id),
                    KEY idx_storage_expansion_summary (status, requested_capacity_bytes, estimated_usable_capacity_bytes, id),
                    KEY idx_storage_expansion_created_at (created_at)
                )
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
            ensureColumn(connection, "applied_by", "ALTER TABLE storage_expansion_requests ADD COLUMN applied_by VARCHAR(128) NULL");
            ensureColumn(connection, "applied_at", "ALTER TABLE storage_expansion_requests ADD COLUMN applied_at TIMESTAMP NULL");
            ensureColumn(connection, "applied_evidence", "ALTER TABLE storage_expansion_requests ADD COLUMN applied_evidence VARCHAR(512) NULL");
            addIndexIfMissing(connection, "idx_storage_expansion_summary", "status, requested_capacity_bytes, estimated_usable_capacity_bytes, id");
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void ensureColumn(Connection connection, String columnName, String alterSql) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("SHOW COLUMNS FROM storage_expansion_requests LIKE ?")) {
            statement.setString(1, columnName);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    return;
                }
            }
        }
        try (PreparedStatement statement = connection.prepareStatement(alterSql)) {
            statement.executeUpdate();
        }
    }

    private void addIndexIfMissing(Connection connection, String indexName, String columns) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "CREATE INDEX IF NOT EXISTS " + indexName + " ON storage_expansion_requests (" + columns + ")")) {
            statement.executeUpdate();
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private StorageExpansionRequestAggregate emptyAggregate() {
        return new StorageExpansionRequestAggregate(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    }

    private StorageExpansionRequestRecord mapRow(ResultSet resultSet) throws SQLException {
        return new StorageExpansionRequestRecord(
                resultSet.getLong("id"),
                resultSet.getLong("requested_capacity_bytes"),
                resultSet.getInt("server_count"),
                resultSet.getInt("volumes_per_server"),
                resultSet.getLong("volume_size_bytes"),
                resultSet.getLong("estimated_raw_capacity_bytes"),
                resultSet.getLong("estimated_usable_capacity_bytes"),
                resultSet.getString("status"),
                resultSet.getString("reason"),
                resultSet.getString("created_by"),
                resultSet.getString("applied_by"),
                resultSet.getTimestamp("applied_at") == null ? null : resultSet.getTimestamp("applied_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getString("applied_evidence"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
