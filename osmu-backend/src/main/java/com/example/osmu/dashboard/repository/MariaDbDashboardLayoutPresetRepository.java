package com.example.osmu.dashboard.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.dashboard.DashboardLayoutPresetRecord;
import com.example.osmu.dashboard.DashboardSectionLayout;
import com.example.osmu.dashboard.DashboardWidgetLayout;
import com.fasterxml.jackson.core.JsonProcessingException;
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
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbDashboardLayoutPresetRepository implements DashboardLayoutPresetRepository {

    private static final TypeReference<List<DashboardWidgetLayout>> WIDGET_LIST_TYPE = new TypeReference<>() {
    };
    private static final TypeReference<List<DashboardSectionLayout>> SECTION_LIST_TYPE = new TypeReference<>() {
    };

    private final String url;
    private final String username;
    private final String password;
    private final ObjectMapper objectMapper;
    private volatile boolean schemaReady;

    public MariaDbDashboardLayoutPresetRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password,
            ObjectMapper objectMapper
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
        this.objectMapper = objectMapper;
    }

    @Override
    public List<DashboardLayoutPresetRecord> findAll() {
        ensureSchema();
        String sql = """
                SELECT preset_id, created_by_user_id, preset_name, description, widgets_json, sections_json, schema_version, created_at, updated_at
                FROM dashboard_layout_presets
                ORDER BY preset_name ASC
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<DashboardLayoutPresetRecord> presets = new ArrayList<>();
            while (resultSet.next()) {
                presets.add(mapRow(resultSet));
            }
            return presets;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<DashboardLayoutPresetRecord> findById(String id) {
        ensureSchema();
        String sql = """
                SELECT preset_id, created_by_user_id, preset_name, description, widgets_json, sections_json, schema_version, created_at, updated_at
                FROM dashboard_layout_presets
                WHERE preset_id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, id);
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
    public DashboardLayoutPresetRecord save(DashboardLayoutPresetRecord preset) {
        ensureSchema();
        String sql = """
                INSERT INTO dashboard_layout_presets
                    (preset_id, created_by_user_id, preset_name, description, widgets_json, sections_json, schema_version, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    preset_name = VALUES(preset_name),
                    description = VALUES(description),
                    widgets_json = VALUES(widgets_json),
                    sections_json = VALUES(sections_json),
                    schema_version = VALUES(schema_version),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, preset.id());
            statement.setLong(2, preset.createdByUserId());
            statement.setString(3, preset.name());
            statement.setString(4, preset.description());
            statement.setString(5, serializeWidgets(preset.widgets()));
            statement.setString(6, serializeSections(preset.sections()));
            statement.setString(7, preset.schemaVersion());
            statement.setTimestamp(8, Timestamp.from(preset.createdAt().toInstant()));
            statement.setTimestamp(9, Timestamp.from(preset.updatedAt().toInstant()));
            statement.executeUpdate();
            return preset;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public boolean deleteById(String id) {
        ensureSchema();
        String sql = "DELETE FROM dashboard_layout_presets WHERE preset_id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, id);
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
                CREATE TABLE IF NOT EXISTS dashboard_layout_presets (
                    preset_id VARCHAR(64) NOT NULL,
                    created_by_user_id BIGINT NOT NULL,
                    preset_name VARCHAR(120) NOT NULL,
                    description VARCHAR(500) NOT NULL,
                    widgets_json TEXT NOT NULL,
                    sections_json TEXT NULL,
                    schema_version VARCHAR(64) NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL,
                    PRIMARY KEY (preset_id),
                    KEY idx_dashboard_layout_presets_name (preset_name),
                    KEY idx_dashboard_layout_presets_updated_at (updated_at)
                )
                """;
        try (Connection connection = connect()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.executeUpdate();
            }
            ensureColumn(connection, "dashboard_layout_presets", "sections_json", "ALTER TABLE dashboard_layout_presets ADD COLUMN sections_json TEXT NULL");
            ensureColumn(connection, "dashboard_layout_presets", "schema_version", "ALTER TABLE dashboard_layout_presets ADD COLUMN schema_version VARCHAR(64) NULL");
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private DashboardLayoutPresetRecord mapRow(ResultSet resultSet) throws SQLException {
        return new DashboardLayoutPresetRecord(
                resultSet.getString("preset_id"),
                resultSet.getLong("created_by_user_id"),
                resultSet.getString("preset_name"),
                resultSet.getString("description"),
                deserializeWidgets(resultSet.getString("widgets_json")),
                deserializeSections(resultSet.getString("sections_json")),
                resultSet.getString("schema_version"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private String serializeWidgets(List<DashboardWidgetLayout> widgets) {
        try {
            return objectMapper.writeValueAsString(widgets);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Dashboard layout preset serialization failed.");
        }
    }

    private List<DashboardWidgetLayout> deserializeWidgets(String value) {
        try {
            return objectMapper.readValue(value, WIDGET_LIST_TYPE);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Dashboard layout preset deserialization failed.");
        }
    }

    private String serializeSections(List<DashboardSectionLayout> sections) {
        try {
            return objectMapper.writeValueAsString(sections);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Dashboard layout preset serialization failed.");
        }
    }

    private List<DashboardSectionLayout> deserializeSections(String value) {
        if (value == null || value.isBlank()) {
            return List.of();
        }
        try {
            return objectMapper.readValue(value, SECTION_LIST_TYPE);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Dashboard layout preset deserialization failed.");
        }
    }

    private void ensureColumn(Connection connection, String tableName, String columnName, String alterSql) throws SQLException {
        String sql = "SHOW COLUMNS FROM " + tableName + " LIKE ?";
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
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

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
