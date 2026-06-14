package com.example.osmu.auth.repository;

import com.example.osmu.auth.RefreshTokenRecord;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbRefreshTokenRepository implements RefreshTokenRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbRefreshTokenRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public Optional<RefreshTokenRecord> findByTokenHash(String tokenHash) {
        ensureSchema();
        String sql = """
                SELECT id, user_id, token_hash, status, expires_at, created_at, revoked_at
                FROM refresh_tokens
                WHERE token_hash = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, tokenHash);
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
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM refresh_tokens";
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
    public RefreshTokenRecord save(RefreshTokenRecord token) {
        ensureSchema();
        String sql = """
                INSERT INTO refresh_tokens
                    (id, user_id, token_hash, status, expires_at, created_at, revoked_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    status = VALUES(status),
                    expires_at = VALUES(expires_at),
                    revoked_at = VALUES(revoked_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, token.id());
            statement.setLong(2, token.userId());
            statement.setString(3, token.tokenHash());
            statement.setString(4, token.status());
            statement.setTimestamp(5, Timestamp.from(token.expiresAt().toInstant()));
            statement.setTimestamp(6, Timestamp.from(token.createdAt().toInstant()));
            statement.setTimestamp(7, timestampOrNull(token.revokedAt()));
            statement.executeUpdate();
            return token;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void revokeByTokenHash(String tokenHash) {
        ensureSchema();
        String sql = """
                UPDATE refresh_tokens
                SET status = 'REVOKED', revoked_at = ?
                WHERE token_hash = ? AND status = 'ACTIVE'
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setTimestamp(1, Timestamp.from(OffsetDateTime.now().toInstant()));
            statement.setString(2, tokenHash);
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void revokeAllByUserId(long userId) {
        ensureSchema();
        String sql = """
                UPDATE refresh_tokens
                SET status = 'REVOKED', revoked_at = ?
                WHERE user_id = ? AND status = 'ACTIVE'
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setTimestamp(1, Timestamp.from(OffsetDateTime.now().toInstant()));
            statement.setLong(2, userId);
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
                CREATE TABLE IF NOT EXISTS refresh_tokens (
                    id BIGINT NOT NULL PRIMARY KEY,
                    user_id BIGINT NOT NULL,
                    token_hash VARCHAR(128) NOT NULL UNIQUE,
                    status VARCHAR(32) NOT NULL,
                    expires_at TIMESTAMP NOT NULL,
                    created_at TIMESTAMP NOT NULL,
                    revoked_at TIMESTAMP NULL,
                    INDEX idx_refresh_tokens_user_id (user_id),
                    INDEX idx_refresh_tokens_status (status),
                    INDEX idx_refresh_tokens_expires_at (expires_at)
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

    private RefreshTokenRecord mapRow(ResultSet resultSet) throws SQLException {
        return new RefreshTokenRecord(
                resultSet.getLong("id"),
                resultSet.getLong("user_id"),
                resultSet.getString("token_hash"),
                resultSet.getString("status"),
                resultSet.getTimestamp("expires_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                offsetDateTimeOrNull(resultSet.getTimestamp("revoked_at"))
        );
    }

    private Timestamp timestampOrNull(OffsetDateTime value) {
        return value == null ? null : Timestamp.from(value.toInstant());
    }

    private OffsetDateTime offsetDateTimeOrNull(Timestamp value) {
        return value == null ? null : value.toInstant().atOffset(ZoneOffset.UTC);
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
