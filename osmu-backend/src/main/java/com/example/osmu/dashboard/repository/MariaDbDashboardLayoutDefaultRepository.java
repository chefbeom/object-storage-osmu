package com.example.osmu.dashboard.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.dashboard.DashboardLayoutDefaultRecord;
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
public class MariaDbDashboardLayoutDefaultRepository implements DashboardLayoutDefaultRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbDashboardLayoutDefaultRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<DashboardLayoutDefaultRecord> findAll() {
        ensureSchema();
        String sql = """
                SELECT target_type, target_id, preset_id, updated_by_user_id, updated_at
                FROM dashboard_layout_defaults
                ORDER BY target_type, target_id
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<DashboardLayoutDefaultRecord> defaults = new ArrayList<>();
            while (resultSet.next()) {
                defaults.add(mapRow(resultSet));
            }
            return defaults;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<DashboardLayoutDefaultRecord> findByTarget(String targetType, String targetId) {
        ensureSchema();
        String sql = """
                SELECT target_type, target_id, preset_id, updated_by_user_id, updated_at
                FROM dashboard_layout_defaults
                WHERE target_type = ? AND target_id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, targetType);
            statement.setString(2, targetId);
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
    public DashboardLayoutDefaultRecord save(DashboardLayoutDefaultRecord record) {
        ensureSchema();
        String sql = """
                INSERT INTO dashboard_layout_defaults
                    (target_type, target_id, preset_id, updated_by_user_id, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    preset_id = VALUES(preset_id),
                    updated_by_user_id = VALUES(updated_by_user_id),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, record.targetType());
            statement.setString(2, record.targetId());
            statement.setString(3, record.presetId());
            statement.setLong(4, record.updatedByUserId());
            statement.setTimestamp(5, Timestamp.from(record.updatedAt().toInstant()));
            statement.executeUpdate();
            return record;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public boolean deleteByTarget(String targetType, String targetId) {
        ensureSchema();
        String sql = "DELETE FROM dashboard_layout_defaults WHERE target_type = ? AND target_id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, targetType);
            statement.setString(2, targetId);
            return statement.executeUpdate() > 0;
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
                CREATE TABLE IF NOT EXISTS dashboard_layout_defaults (
                    target_type VARCHAR(32) NOT NULL,
                    target_id VARCHAR(64) NOT NULL,
                    preset_id VARCHAR(64) NOT NULL,
                    updated_by_user_id BIGINT NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    PRIMARY KEY (target_type, target_id),
                    KEY idx_dashboard_layout_defaults_preset_id (preset_id),
                    KEY idx_dashboard_layout_defaults_updated_at (updated_at)
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

    private DashboardLayoutDefaultRecord mapRow(ResultSet resultSet) throws SQLException {
        return new DashboardLayoutDefaultRecord(
                resultSet.getString("target_type"),
                resultSet.getString("target_id"),
                resultSet.getString("preset_id"),
                resultSet.getLong("updated_by_user_id"),
                resultSet.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
