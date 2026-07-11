package com.example.osmu.user.repository;

import com.example.osmu.auth.PasswordService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.BootstrapAdminProperties;
import com.example.osmu.user.UserAccount;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbUserRepository implements UserRepository {

    private final String url;
    private final String username;
    private final String password;
    private final PasswordService passwordService;
    private final BootstrapAdminProperties bootstrapAdminProperties;
    private volatile boolean schemaReady;

    public MariaDbUserRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password,
            PasswordService passwordService,
            BootstrapAdminProperties bootstrapAdminProperties
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
        this.passwordService = passwordService;
        this.bootstrapAdminProperties = bootstrapAdminProperties;
    }


    @Override
    public List<UserAccount> findByIds(List<Long> userIds) {
        ensureSchema();
        List<Long> ids = userIds == null
                ? List.of()
                : userIds.stream()
                        .filter(java.util.Objects::nonNull)
                        .distinct()
                        .toList();
        if (ids.isEmpty()) {
            return List.of();
        }
        String sql = """
                SELECT id, login_id, email, name, password_hash, role, status, organization_id
                FROM users
                WHERE id IN (%s)
                ORDER BY id
                """.formatted(String.join(", ", java.util.Collections.nCopies(ids.size(), "?")));
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            for (int index = 0; index < ids.size(); index += 1) {
                statement.setLong(index + 1, ids.get(index));
            }
            try (ResultSet resultSet = statement.executeQuery()) {
                List<UserAccount> users = new ArrayList<>();
                while (resultSet.next()) {
                    users.add(mapRow(resultSet));
                }
                return users;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<UserAccount> findPage(
            Long organizationId,
            String keyword,
            String status,
            Long cursorId,
            int limit
    ) {
        ensureSchema();
        String normalizedKeyword = keyword == null ? "" : keyword.trim();
        String normalizedStatus = status == null ? "" : status.trim().toUpperCase(Locale.ROOT);
        StringBuilder sql = new StringBuilder("""
                SELECT id, login_id, email, name, password_hash, role, status, organization_id
                FROM users
                WHERE 1 = 1
                """);
        if (organizationId != null) {
            sql.append(" AND organization_id = ?");
        }
        if (!normalizedKeyword.isBlank()) {
            sql.append("""
                     AND (LOCATE(LOWER(?), LOWER(login_id)) > 0
                       OR LOCATE(LOWER(?), LOWER(email)) > 0
                       OR LOCATE(LOWER(?), LOWER(name)) > 0)
                    """);
        }
        if (!normalizedStatus.isBlank()) {
            sql.append(" AND status = ?");
        }
        if (cursorId != null) {
            sql.append(" AND id < ?");
        }
        sql.append(" ORDER BY id DESC LIMIT ?");

        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            int parameterIndex = 1;
            if (organizationId != null) {
                statement.setLong(parameterIndex++, organizationId);
            }
            if (!normalizedKeyword.isBlank()) {
                statement.setString(parameterIndex++, normalizedKeyword);
                statement.setString(parameterIndex++, normalizedKeyword);
                statement.setString(parameterIndex++, normalizedKeyword);
            }
            if (!normalizedStatus.isBlank()) {
                statement.setString(parameterIndex++, normalizedStatus);
            }
            if (cursorId != null) {
                statement.setLong(parameterIndex++, cursorId);
            }
            statement.setInt(parameterIndex, limit);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<UserAccount> users = new ArrayList<>();
                while (resultSet.next()) {
                    users.add(mapRow(resultSet));
                }
                return users;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<UserAccount> findById(long id) {
        ensureSchema();
        String sql = """
                SELECT id, login_id, email, name, password_hash, role, status, organization_id
                FROM users
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
    public Optional<UserAccount> findByLoginId(String loginId) {
        ensureSchema();
        String sql = """
                SELECT id, login_id, email, name, password_hash, role, status, organization_id
                FROM users
                WHERE login_id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, loginId);
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
    public Optional<UserAccount> findByEmail(String email) {
        ensureSchema();
        String sql = """
                SELECT id, login_id, email, name, password_hash, role, status, organization_id
                FROM users
                WHERE email = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, email);
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
    public List<Long> findIdsByOrganizationId(long organizationId) {
        ensureSchema();
        String sql = "SELECT id FROM users WHERE organization_id = ? ORDER BY id";
        List<Long> userIds = new ArrayList<>();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, organizationId);
            try (ResultSet resultSet = statement.executeQuery()) {
                while (resultSet.next()) {
                    userIds.add(resultSet.getLong("id"));
                }
            }
            return List.copyOf(userIds);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public boolean existsByLoginId(String loginId) {
        ensureSchema();
        String sql = "SELECT 1 FROM users WHERE login_id = ? LIMIT 1";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, loginId);
            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public boolean existsByEmail(String email) {
        ensureSchema();
        String sql = "SELECT 1 FROM users WHERE email = ? LIMIT 1";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, email);
            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public boolean existsByOrganizationId(long organizationId) {
        ensureSchema();
        String sql = "SELECT 1 FROM users WHERE organization_id = ? LIMIT 1";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, organizationId);
            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public long nextId() {
        ensureSchema();
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM users";
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
    public UserAccount save(UserAccount user) {
        ensureSchema();
        String sql = """
                INSERT INTO users
                    (id, login_id, email, name, password_hash, role, status, organization_id, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    email = VALUES(email),
                    name = VALUES(name),
                    password_hash = VALUES(password_hash),
                    role = VALUES(role),
                    status = VALUES(status),
                    organization_id = VALUES(organization_id),
                    updated_at = VALUES(updated_at)
                """;
        Timestamp now = Timestamp.from(Instant.now());
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, user.id());
            statement.setString(2, user.loginId());
            statement.setString(3, user.email());
            statement.setString(4, user.name());
            statement.setString(5, user.passwordHash());
            statement.setString(6, user.role());
            statement.setString(7, user.status());
            setNullableLong(statement, 8, user.organizationId());
            statement.setTimestamp(9, now);
            statement.setTimestamp(10, now);
            statement.executeUpdate();
            return user;
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
                CREATE TABLE IF NOT EXISTS users (
                    id BIGINT NOT NULL PRIMARY KEY,
                    login_id VARCHAR(100) NOT NULL UNIQUE,
                    email VARCHAR(255) NOT NULL UNIQUE,
                    name VARCHAR(100) NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    role VARCHAR(32) NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    organization_id BIGINT NULL,
                    created_at TIMESTAMP NOT NULL,
                    updated_at TIMESTAMP NOT NULL
                )
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
            ensureOrganizationColumn(connection);
            seedAdmin(connection);
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void seedAdmin(Connection connection) throws SQLException {
        Optional<UserAccount> bootstrapAdmin = bootstrapAdminProperties.createAdmin(1L, passwordService);
        if (bootstrapAdmin.isEmpty()) {
            return;
        }
        UserAccount admin = bootstrapAdmin.get();
        String sql = """
                INSERT IGNORE INTO users
                    (id, login_id, email, name, password_hash, role, status, organization_id, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;
        Timestamp now = Timestamp.from(Instant.now());
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, admin.id());
            statement.setString(2, admin.loginId());
            statement.setString(3, admin.email());
            statement.setString(4, admin.name());
            statement.setString(5, admin.passwordHash());
            statement.setString(6, admin.role());
            statement.setString(7, admin.status());
            setNullableLong(statement, 8, admin.organizationId());
            statement.setTimestamp(9, now);
            statement.setTimestamp(10, now);
            statement.executeUpdate();
        }
    }

    private void ensureOrganizationColumn(Connection connection) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "ALTER TABLE users ADD COLUMN IF NOT EXISTS organization_id BIGINT NULL"
        )) {
            statement.executeUpdate();
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private UserAccount mapRow(ResultSet resultSet) throws SQLException {
        return new UserAccount(
                resultSet.getLong("id"),
                resultSet.getString("login_id"),
                resultSet.getString("email"),
                resultSet.getString("name"),
                resultSet.getString("password_hash"),
                resultSet.getString("role"),
                resultSet.getString("status"),
                nullableLong(resultSet, "organization_id")
        );
    }

    private void setNullableLong(PreparedStatement statement, int index, Long value) throws SQLException {
        if (value == null) {
            statement.setObject(index, null);
            return;
        }
        statement.setLong(index, value);
    }

    private Long nullableLong(ResultSet resultSet, String column) throws SQLException {
        long value = resultSet.getLong(column);
        return resultSet.wasNull() ? null : value;
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
