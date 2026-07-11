package com.example.osmu.storagelayout.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storagelayout.StorageLayoutPlanRecord;
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
public class MariaDbStorageLayoutPlanRepository implements StorageLayoutPlanRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbStorageLayoutPlanRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<StorageLayoutPlanRecord> findPage(List<String> statuses, Long cursorId, int limit) {
        ensureSchema();
        List<String> statusFilter = statuses == null
                ? List.of()
                : statuses.stream().filter(java.util.Objects::nonNull).distinct().toList();
        StringBuilder sql = new StringBuilder(selectSql()).append(" WHERE 1 = 1");
        if (!statusFilter.isEmpty()) {
            sql.append(" AND status IN (")
                    .append(String.join(", ", java.util.Collections.nCopies(statusFilter.size(), "?")))
                    .append(")");
        }
        if (cursorId != null) {
            sql.append(" AND id < ?");
        }
        sql.append(" ORDER BY id DESC LIMIT ?");
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            int parameterIndex = 1;
            for (String status : statusFilter) {
                statement.setString(parameterIndex++, status);
            }
            if (cursorId != null) {
                statement.setLong(parameterIndex++, cursorId);
            }
            statement.setInt(parameterIndex, limit);
            try (ResultSet resultSet = statement.executeQuery()) {
                return collect(resultSet);
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<StorageLayoutPlanRecord> findById(long id) {
        ensureSchema();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(selectSql() + " WHERE id = ?")) {
            statement.setLong(1, id);
            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next() ? Optional.of(mapRow(resultSet)) : Optional.empty();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public long nextId() {
        ensureSchema();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(
                     "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM storage_layout_plans"
             );
             ResultSet resultSet = statement.executeQuery()) {
            return resultSet.next() ? resultSet.getLong("next_id") : 1L;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public StorageLayoutPlanRecord save(StorageLayoutPlanRecord plan) {
        ensureSchema();
        String sql = """
                INSERT INTO storage_layout_plans
                    (id, layout_code, storage_class_name, server_count, volumes_per_server, volume_size_gib,
                     status, reason, created_by, approved_by, approved_at, simulated_by, simulated_at,
                     admin_note, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    layout_code = VALUES(layout_code),
                    storage_class_name = VALUES(storage_class_name),
                    server_count = VALUES(server_count),
                    volumes_per_server = VALUES(volumes_per_server),
                    volume_size_gib = VALUES(volume_size_gib),
                    status = VALUES(status),
                    reason = VALUES(reason),
                    approved_by = VALUES(approved_by),
                    approved_at = VALUES(approved_at),
                    simulated_by = VALUES(simulated_by),
                    simulated_at = VALUES(simulated_at),
                    admin_note = VALUES(admin_note),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, plan.id());
            statement.setString(2, plan.layoutCode());
            statement.setString(3, plan.storageClassName());
            statement.setInt(4, plan.serverCount());
            statement.setInt(5, plan.volumesPerServer());
            statement.setLong(6, plan.volumeSizeGiB());
            statement.setString(7, plan.status());
            statement.setString(8, plan.reason());
            statement.setString(9, plan.createdBy());
            statement.setString(10, plan.approvedBy());
            statement.setTimestamp(11, timestamp(plan.approvedAt()));
            statement.setString(12, plan.simulatedBy());
            statement.setTimestamp(13, timestamp(plan.simulatedAt()));
            statement.setString(14, plan.adminNote());
            statement.setTimestamp(15, timestamp(plan.createdAt()));
            statement.setTimestamp(16, timestamp(plan.updatedAt()));
            statement.executeUpdate();
            return plan;
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
                CREATE TABLE IF NOT EXISTS storage_layout_plans (
                    id BIGINT NOT NULL PRIMARY KEY,
                    layout_code VARCHAR(32) NOT NULL,
                    storage_class_name VARCHAR(128) NOT NULL,
                    server_count INT NOT NULL,
                    volumes_per_server INT NOT NULL,
                    volume_size_gib BIGINT NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    reason VARCHAR(512) NULL,
                    created_by VARCHAR(128) NOT NULL,
                    approved_by VARCHAR(128) NULL,
                    approved_at TIMESTAMP NULL,
                    simulated_by VARCHAR(128) NULL,
                    simulated_at TIMESTAMP NULL,
                    admin_note VARCHAR(512) NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    INDEX idx_storage_layout_plans_status (status, id)
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
                SELECT id, layout_code, storage_class_name, server_count, volumes_per_server, volume_size_gib,
                       status, reason, created_by, approved_by, approved_at, simulated_by, simulated_at,
                       admin_note, created_at, updated_at
                FROM storage_layout_plans
                """;
    }

    private List<StorageLayoutPlanRecord> collect(ResultSet resultSet) throws SQLException {
        List<StorageLayoutPlanRecord> records = new ArrayList<>();
        while (resultSet.next()) {
            records.add(mapRow(resultSet));
        }
        return records;
    }

    private StorageLayoutPlanRecord mapRow(ResultSet resultSet) throws SQLException {
        return new StorageLayoutPlanRecord(
                resultSet.getLong("id"),
                resultSet.getString("layout_code"),
                resultSet.getString("storage_class_name"),
                resultSet.getInt("server_count"),
                resultSet.getInt("volumes_per_server"),
                resultSet.getLong("volume_size_gib"),
                resultSet.getString("status"),
                resultSet.getString("reason"),
                resultSet.getString("created_by"),
                resultSet.getString("approved_by"),
                toOffset(resultSet.getTimestamp("approved_at")),
                resultSet.getString("simulated_by"),
                toOffset(resultSet.getTimestamp("simulated_at")),
                resultSet.getString("admin_note"),
                toOffset(resultSet.getTimestamp("created_at")),
                toOffset(resultSet.getTimestamp("updated_at"))
        );
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
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
