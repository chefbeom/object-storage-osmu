package com.example.osmu.object.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectShareLink;
import com.example.osmu.object.ObjectShareLinkAnalytics;
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
public class MariaDbObjectShareLinkRepository implements ObjectShareLinkRepository {

    private static final String SELECT_COLUMNS = """
            id, token_hash, password_hash, allowed_ip_cidrs, bucket_name, object_key, created_by_user_id, status, expires_at, note,
            max_downloads, download_count, last_accessed_at, created_at, revoked_at
            """;

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbObjectShareLinkRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public Optional<ObjectShareLink> findById(long id) {
        ensureSchema();
        String sql = "SELECT " + SELECT_COLUMNS + " FROM object_share_links WHERE id = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next() ? Optional.of(mapRow(resultSet)) : Optional.empty();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public int expireActiveBefore(OffsetDateTime expiresAt) {
        ensureSchema();
        String sql = """
                UPDATE object_share_links
                SET status = 'EXPIRED'
                WHERE status = 'ACTIVE'
                    AND expires_at <= ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setTimestamp(1, Timestamp.from(expiresAt.toInstant()));
            return statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<ObjectShareLink> findByTokenHash(String tokenHash) {
        ensureSchema();
        String sql = "SELECT " + SELECT_COLUMNS + " FROM object_share_links WHERE token_hash = ?";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, tokenHash);
            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next() ? Optional.of(mapRow(resultSet)) : Optional.empty();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<ObjectShareLink> findByBucket(String bucketName, int limit) {
        ensureSchema();
        String sql = "SELECT " + SELECT_COLUMNS + """
                 FROM object_share_links
                 WHERE bucket_name = ?
                 ORDER BY id DESC
                 LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            statement.setInt(2, limit);
            return readList(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<ObjectShareLink> findByBucketAndKey(String bucketName, String objectKey, int limit) {
        ensureSchema();
        String sql = "SELECT " + SELECT_COLUMNS + """
                 FROM object_share_links
                 WHERE bucket_name = ? AND object_key = ?
                 ORDER BY id DESC
                 LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            statement.setString(2, objectKey);
            statement.setInt(3, limit);
            return readList(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }


    @Override
    public ObjectShareLinkAnalytics analytics(String bucketName, String status, int recentLimit) {
        ensureSchema();
        if (recentLimit < 1) {
            throw new IllegalArgumentException("recentLimit must be positive.");
        }
        String bucketFilter = bucketName == null ? "" : bucketName;
        String statusFilter = status == null ? "" : status;
        String whereClause = analyticsWhereClause(bucketFilter, statusFilter);
        String aggregateSql = """
                SELECT COUNT(*) AS total_links,
                       COALESCE(SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END), 0) AS active_links,
                       COALESCE(SUM(CASE WHEN status = 'EXPIRED' THEN 1 ELSE 0 END), 0) AS expired_links,
                       COALESCE(SUM(CASE WHEN status = 'REVOKED' THEN 1 ELSE 0 END), 0) AS revoked_links,
                       COALESCE(SUM(CASE WHEN status = 'LIMIT_REACHED' THEN 1 ELSE 0 END), 0) AS limit_reached_links,
                       COALESCE(SUM(CASE WHEN password_hash IS NOT NULL AND TRIM(password_hash) <> '' THEN 1 ELSE 0 END), 0) AS password_protected_links,
                       COALESCE(SUM(CASE WHEN allowed_ip_cidrs IS NOT NULL AND TRIM(allowed_ip_cidrs) <> '' THEN 1 ELSE 0 END), 0) AS ip_restricted_links,
                       COALESCE(SUM(download_count), 0) AS total_downloads,
                       MAX(last_accessed_at) AS last_accessed_at
                FROM object_share_links
                """ + whereClause;
        String recentSql = "SELECT " + SELECT_COLUMNS
                + " FROM object_share_links"
                + whereClause
                + " ORDER BY id DESC LIMIT ?";
        try (Connection connection = connect();
             PreparedStatement aggregateStatement = connection.prepareStatement(aggregateSql);
             PreparedStatement recentStatement = connection.prepareStatement(recentSql)) {
            bindAnalyticsFilters(aggregateStatement, bucketFilter, statusFilter);
            int recentLimitIndex = bindAnalyticsFilters(recentStatement, bucketFilter, statusFilter);
            recentStatement.setInt(recentLimitIndex, recentLimit);
            long totalLinks;
            long activeLinks;
            long expiredLinks;
            long revokedLinks;
            long limitReachedLinks;
            long passwordProtectedLinks;
            long ipRestrictedLinks;
            long totalDownloads;
            OffsetDateTime lastAccessedAt;
            try (ResultSet aggregateResult = aggregateStatement.executeQuery()) {
                if (!aggregateResult.next()) {
                    throw new SQLException("Object share analytics aggregate returned no row.");
                }
                totalLinks = aggregateResult.getLong("total_links");
                activeLinks = aggregateResult.getLong("active_links");
                expiredLinks = aggregateResult.getLong("expired_links");
                revokedLinks = aggregateResult.getLong("revoked_links");
                limitReachedLinks = aggregateResult.getLong("limit_reached_links");
                passwordProtectedLinks = aggregateResult.getLong("password_protected_links");
                ipRestrictedLinks = aggregateResult.getLong("ip_restricted_links");
                totalDownloads = aggregateResult.getLong("total_downloads");
                lastAccessedAt = nullableTimestamp(aggregateResult, "last_accessed_at");
            }
            return new ObjectShareLinkAnalytics(
                    totalLinks,
                    activeLinks,
                    expiredLinks,
                    revokedLinks,
                    limitReachedLinks,
                    passwordProtectedLinks,
                    ipRestrictedLinks,
                    totalDownloads,
                    lastAccessedAt,
                    readList(recentStatement)
            );
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public long nextId() {
        ensureSchema();
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM object_share_links";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            return resultSet.next() ? resultSet.getLong("next_id") : 1L;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public ObjectShareLink save(ObjectShareLink link) {
        ensureSchema();
        String sql = """
                INSERT INTO object_share_links
                    (id, token_hash, password_hash, allowed_ip_cidrs, bucket_name, object_key, created_by_user_id, status, expires_at, note,
                     max_downloads, download_count, last_accessed_at, created_at, revoked_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    status = VALUES(status),
                    expires_at = VALUES(expires_at),
                    password_hash = VALUES(password_hash),
                    allowed_ip_cidrs = VALUES(allowed_ip_cidrs),
                    note = VALUES(note),
                    max_downloads = VALUES(max_downloads),
                    download_count = VALUES(download_count),
                    last_accessed_at = VALUES(last_accessed_at),
                    revoked_at = VALUES(revoked_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            bind(statement, link);
            statement.executeUpdate();
            return link;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public ObjectShareLink recordDownload(ObjectShareLink link, OffsetDateTime accessedAt) {
        ensureSchema();
        String sql = """
                UPDATE object_share_links
                SET download_count = download_count + 1,
                    last_accessed_at = ?
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setTimestamp(1, Timestamp.from(accessedAt.toInstant()));
            statement.setLong(2, link.id());
            statement.executeUpdate();
            return link.withDownloadRecorded(accessedAt);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public int expireActiveBefore(String bucketName, OffsetDateTime expiresAt) {
        ensureSchema();
        String sql = """
                UPDATE object_share_links
                SET status = 'EXPIRED'
                WHERE bucket_name = ?
                    AND status = 'ACTIVE'
                    AND expires_at <= ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            statement.setTimestamp(2, Timestamp.from(expiresAt.toInstant()));
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
                CREATE TABLE IF NOT EXISTS object_share_links (
                    id BIGINT NOT NULL PRIMARY KEY,
                    token_hash VARCHAR(64) NOT NULL,
                    password_hash VARCHAR(64) NULL,
                    allowed_ip_cidrs VARCHAR(512) NULL,
                    bucket_name VARCHAR(63) NOT NULL,
                    object_key VARCHAR(1024) NOT NULL,
                    created_by_user_id BIGINT NOT NULL,
                    status VARCHAR(16) NOT NULL,
                    expires_at TIMESTAMP NOT NULL,
                    note VARCHAR(512) NULL,
                    max_downloads INT NULL,
                    download_count BIGINT NOT NULL DEFAULT 0,
                    last_accessed_at TIMESTAMP NULL,
                    created_at TIMESTAMP NOT NULL,
                    revoked_at TIMESTAMP NULL,
                    UNIQUE KEY uk_object_share_links_token_hash (token_hash),
                    KEY idx_object_share_links_bucket_key (bucket_name, object_key(255), id),
                    KEY idx_object_share_links_status_expires (status, expires_at)
                )
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
            executeUpdate(connection, "ALTER TABLE object_share_links ADD COLUMN IF NOT EXISTS password_hash VARCHAR(64) NULL AFTER token_hash");
            executeUpdate(connection, "ALTER TABLE object_share_links ADD COLUMN IF NOT EXISTS allowed_ip_cidrs VARCHAR(512) NULL AFTER password_hash");
            executeUpdate(connection, "ALTER TABLE object_share_links ADD COLUMN IF NOT EXISTS max_downloads INT NULL AFTER note");
            executeUpdate(connection, "ALTER TABLE object_share_links ADD COLUMN IF NOT EXISTS download_count BIGINT NOT NULL DEFAULT 0 AFTER max_downloads");
            executeUpdate(connection, "ALTER TABLE object_share_links ADD COLUMN IF NOT EXISTS last_accessed_at TIMESTAMP NULL AFTER download_count");
            executeUpdate(connection, "CREATE INDEX IF NOT EXISTS idx_object_share_links_bucket_id ON object_share_links (bucket_name, id)");
            executeUpdate(connection, "CREATE INDEX IF NOT EXISTS idx_object_share_links_status_id ON object_share_links (status, id)");
            executeUpdate(connection, "CREATE INDEX IF NOT EXISTS idx_object_share_links_bucket_status_id ON object_share_links (bucket_name, status, id)");
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private List<ObjectShareLink> readList(PreparedStatement statement) throws SQLException {
        try (ResultSet resultSet = statement.executeQuery()) {
            List<ObjectShareLink> links = new ArrayList<>();
            while (resultSet.next()) {
                links.add(mapRow(resultSet));
            }
            return links;
        }
    }

    private String analyticsWhereClause(String bucketName, String status) {
        List<String> predicates = new ArrayList<>();
        if (!bucketName.isBlank()) {
            predicates.add("bucket_name = ?");
        }
        if (!status.isBlank()) {
            predicates.add("status = ?");
        }
        return predicates.isEmpty() ? "" : " WHERE " + String.join(" AND ", predicates);
    }

    private int bindAnalyticsFilters(
            PreparedStatement statement,
            String bucketName,
            String status
    ) throws SQLException {
        int parameterIndex = 1;
        if (!bucketName.isBlank()) {
            statement.setString(parameterIndex++, bucketName);
        }
        if (!status.isBlank()) {
            statement.setString(parameterIndex++, status);
        }
        return parameterIndex;
    }

    private void bind(PreparedStatement statement, ObjectShareLink link) throws SQLException {
        statement.setLong(1, link.id());
        statement.setString(2, link.tokenHash());
        statement.setString(3, link.passwordHash());
        statement.setString(4, link.allowedIpCidrs());
        statement.setString(5, link.bucketName());
        statement.setString(6, link.objectKey());
        statement.setLong(7, link.createdByUserId());
        statement.setString(8, link.status());
        statement.setTimestamp(9, Timestamp.from(link.expiresAt().toInstant()));
        statement.setString(10, link.note());
        if (link.maxDownloads() == null) {
            statement.setNull(11, java.sql.Types.INTEGER);
        } else {
            statement.setInt(11, link.maxDownloads());
        }
        statement.setLong(12, link.downloadCount());
        if (link.lastAccessedAt() == null) {
            statement.setNull(13, java.sql.Types.TIMESTAMP);
        } else {
            statement.setTimestamp(13, Timestamp.from(link.lastAccessedAt().toInstant()));
        }
        statement.setTimestamp(14, Timestamp.from(link.createdAt().toInstant()));
        if (link.revokedAt() == null) {
            statement.setNull(15, java.sql.Types.TIMESTAMP);
        } else {
            statement.setTimestamp(15, Timestamp.from(link.revokedAt().toInstant()));
        }
    }

    private ObjectShareLink mapRow(ResultSet resultSet) throws SQLException {
        return new ObjectShareLink(
                resultSet.getLong("id"),
                resultSet.getString("token_hash"),
                resultSet.getString("password_hash"),
                resultSet.getString("allowed_ip_cidrs"),
                resultSet.getString("bucket_name"),
                resultSet.getString("object_key"),
                resultSet.getLong("created_by_user_id"),
                resultSet.getString("status"),
                resultSet.getTimestamp("expires_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getString("note"),
                nullableInteger(resultSet, "max_downloads"),
                resultSet.getLong("download_count"),
                nullableTimestamp(resultSet, "last_accessed_at"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                nullableTimestamp(resultSet, "revoked_at")
        );
    }

    private void executeUpdate(Connection connection, String sql) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
        }
    }

    private Integer nullableInteger(ResultSet resultSet, String columnName) throws SQLException {
        int value = resultSet.getInt(columnName);
        return resultSet.wasNull() ? null : value;
    }

    private OffsetDateTime nullableTimestamp(ResultSet resultSet, String columnName) throws SQLException {
        Timestamp timestamp = resultSet.getTimestamp(columnName);
        return timestamp == null ? null : timestamp.toInstant().atOffset(ZoneOffset.UTC);
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
