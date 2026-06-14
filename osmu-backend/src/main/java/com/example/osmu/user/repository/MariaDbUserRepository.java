package com.example.osmu.user.repository;

import com.example.osmu.auth.PasswordService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
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
    private final String adminLoginId;
    private final String adminPassword;
    private final String adminEmail;
    private final String adminName;
    private volatile boolean schemaReady;

    public MariaDbUserRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password,
            PasswordService passwordService,
            @Value("${osmu.bootstrap.admin.login-id:admin}") String adminLoginId,
            @Value("${osmu.bootstrap.admin.password:password}") String adminPassword,
            @Value("${osmu.bootstrap.admin.email:admin@example.com}") String adminEmail,
            @Value("${osmu.bootstrap.admin.name:Admin}") String adminName
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
        this.passwordService = passwordService;
        this.adminLoginId = adminLoginId;
        this.adminPassword = adminPassword;
        this.adminEmail = adminEmail;
        this.adminName = adminName;
    }

    @Override
    public List<UserAccount> findAll() {
        ensureSchema();
        String sql = """
                SELECT id, login_id, email, name, password_hash, role, status, organization_id
                FROM users
                ORDER BY id
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<UserAccount> users = new ArrayList<>();
            while (resultSet.next()) {
                users.add(mapRow(resultSet));
            }
            return users;
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
        String sql = """
                INSERT IGNORE INTO users
                    (id, login_id, email, name, password_hash, role, status, organization_id, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;
        Timestamp now = Timestamp.from(Instant.now());
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, 1L);
            statement.setString(2, adminLoginId);
            statement.setString(3, adminEmail);
            statement.setString(4, adminName);
            statement.setString(5, passwordService.hash(adminPassword));
            statement.setString(6, "ADMIN");
            statement.setString(7, "ACTIVE");
            statement.setObject(8, null);
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
