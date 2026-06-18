package com.example.osmu.dashboard.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.dashboard.DashboardLayoutRecord;
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
import java.util.List;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbDashboardLayoutRepository implements DashboardLayoutRepository {

    private static final TypeReference<List<DashboardWidgetLayout>> WIDGET_LIST_TYPE = new TypeReference<>() {
    };
    private static final TypeReference<List<DashboardSectionLayout>> SECTION_LIST_TYPE = new TypeReference<>() {
    };

    private final String url;
    private final String username;
    private final String password;
    private final ObjectMapper objectMapper;
    private volatile boolean schemaReady;

    public MariaDbDashboardLayoutRepository(
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
    public Optional<DashboardLayoutRecord> findByUserIdAndScope(long userId, String scope) {
        ensureSchema();
        String sql = """
                SELECT user_id, scope_name, widgets_json, sections_json, schema_version, updated_at
                FROM dashboard_layouts
                WHERE user_id = ? AND scope_name = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, userId);
            statement.setString(2, scope);
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
    public DashboardLayoutRecord save(DashboardLayoutRecord layout) {
        ensureSchema();
        String sql = """
                INSERT INTO dashboard_layouts
                    (user_id, scope_name, widgets_json, sections_json, schema_version, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    widgets_json = VALUES(widgets_json),
                    sections_json = VALUES(sections_json),
                    schema_version = VALUES(schema_version),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, layout.userId());
            statement.setString(2, layout.scope());
            statement.setString(3, serializeWidgets(layout.widgets()));
            statement.setString(4, serializeSections(layout.sections()));
            statement.setString(5, layout.schemaVersion());
            statement.setTimestamp(6, Timestamp.from(layout.updatedAt().toInstant()));
            statement.executeUpdate();
            return layout;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteByUserIdAndScope(long userId, String scope) {
        ensureSchema();
        String sql = "DELETE FROM dashboard_layouts WHERE user_id = ? AND scope_name = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, userId);
            statement.setString(2, scope);
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
        String sql = """
                CREATE TABLE IF NOT EXISTS dashboard_layouts (
                    user_id BIGINT NOT NULL,
                    scope_name VARCHAR(64) NOT NULL,
                    widgets_json TEXT NOT NULL,
                    sections_json TEXT NULL,
                    schema_version VARCHAR(64) NULL,
                    updated_at TIMESTAMP NOT NULL,
                    PRIMARY KEY (user_id, scope_name),
                    KEY idx_dashboard_layouts_updated_at (updated_at)
                )
                """;
        try (Connection connection = connect()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.executeUpdate();
            }
            ensureColumn(connection, "dashboard_layouts", "sections_json", "ALTER TABLE dashboard_layouts ADD COLUMN sections_json TEXT NULL");
            ensureColumn(connection, "dashboard_layouts", "schema_version", "ALTER TABLE dashboard_layouts ADD COLUMN schema_version VARCHAR(64) NULL");
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private DashboardLayoutRecord mapRow(ResultSet resultSet) throws SQLException {
        return new DashboardLayoutRecord(
                resultSet.getLong("user_id"),
                resultSet.getString("scope_name"),
                deserializeWidgets(resultSet.getString("widgets_json")),
                deserializeSections(resultSet.getString("sections_json")),
                resultSet.getString("schema_version"),
                resultSet.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private String serializeWidgets(List<DashboardWidgetLayout> widgets) {
        try {
            return objectMapper.writeValueAsString(widgets);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Dashboard layout serialization failed.");
        }
    }

    private List<DashboardWidgetLayout> deserializeWidgets(String value) {
        try {
            return objectMapper.readValue(value, WIDGET_LIST_TYPE);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Dashboard layout deserialization failed.");
        }
    }

    private String serializeSections(List<DashboardSectionLayout> sections) {
        try {
            return objectMapper.writeValueAsString(sections);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Dashboard layout serialization failed.");
        }
    }

    private List<DashboardSectionLayout> deserializeSections(String value) {
        if (value == null || value.isBlank()) {
            return List.of();
        }
        try {
            return objectMapper.readValue(value, SECTION_LIST_TYPE);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Dashboard layout deserialization failed.");
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
