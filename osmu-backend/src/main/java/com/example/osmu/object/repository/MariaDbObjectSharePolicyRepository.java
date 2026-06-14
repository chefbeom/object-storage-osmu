package com.example.osmu.object.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectSharePolicy;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbObjectSharePolicyRepository implements ObjectSharePolicyRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbObjectSharePolicyRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public ObjectSharePolicy get() {
        ensureSchema();
        String sql = """
                SELECT require_password, require_ip_allowlist, max_expires_seconds, max_downloads_limit, updated_at
                FROM object_share_policy
                WHERE id = 1
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            return resultSet.next() ? mapRow(resultSet) : ObjectSharePolicy.defaults();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public ObjectSharePolicy save(ObjectSharePolicy policy) {
        ensureSchema();
        String sql = """
                INSERT INTO object_share_policy
                    (id, require_password, require_ip_allowlist, max_expires_seconds, max_downloads_limit, updated_at)
                VALUES (1, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    require_password = VALUES(require_password),
                    require_ip_allowlist = VALUES(require_ip_allowlist),
                    max_expires_seconds = VALUES(max_expires_seconds),
                    max_downloads_limit = VALUES(max_downloads_limit),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setBoolean(1, policy.requirePassword());
            statement.setBoolean(2, policy.requireIpAllowlist());
            statement.setInt(3, policy.maxExpiresSeconds());
            if (policy.maxDownloadsLimit() == null) {
                statement.setNull(4, java.sql.Types.INTEGER);
            } else {
                statement.setInt(4, policy.maxDownloadsLimit());
            }
            statement.setTimestamp(5, Timestamp.from(policy.updatedAt().toInstant()));
            statement.executeUpdate();
            return policy;
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
                CREATE TABLE IF NOT EXISTS object_share_policy (
                    id TINYINT NOT NULL PRIMARY KEY,
                    require_password BOOLEAN NOT NULL DEFAULT FALSE,
                    require_ip_allowlist BOOLEAN NOT NULL DEFAULT FALSE,
                    max_expires_seconds INT NOT NULL DEFAULT 604800,
                    max_downloads_limit INT NULL,
                    updated_at TIMESTAMP NULL
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

    private ObjectSharePolicy mapRow(ResultSet resultSet) throws SQLException {
        Timestamp updatedAt = resultSet.getTimestamp("updated_at");
        return new ObjectSharePolicy(
                resultSet.getBoolean("require_password"),
                resultSet.getBoolean("require_ip_allowlist"),
                resultSet.getInt("max_expires_seconds"),
                nullableInteger(resultSet, "max_downloads_limit"),
                updatedAt == null ? null : updatedAt.toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private Integer nullableInteger(ResultSet resultSet, String columnName) throws SQLException {
        int value = resultSet.getInt(columnName);
        return resultSet.wasNull() ? null : value;
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
