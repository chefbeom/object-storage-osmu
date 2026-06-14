package com.example.osmu.bucket.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbBucketTagRepository implements BucketTagRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbBucketTagRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public Map<String, String> findByBucketName(String bucketName) {
        ensureSchema();
        String sql = """
                SELECT tag_key, tag_value
                FROM bucket_tags
                WHERE bucket_name = ?
                ORDER BY tag_key
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, bucketName);
            try (ResultSet resultSet = statement.executeQuery()) {
                Map<String, String> tags = new LinkedHashMap<>();
                while (resultSet.next()) {
                    tags.put(resultSet.getString("tag_key"), resultSet.getString("tag_value"));
                }
                return tags;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Map<String, String> replace(String bucketName, Map<String, String> tags) {
        ensureSchema();
        try (Connection connection = connect()) {
            connection.setAutoCommit(false);
            try (PreparedStatement deleteStatement = connection.prepareStatement("DELETE FROM bucket_tags WHERE bucket_name = ?")) {
                deleteStatement.setString(1, bucketName);
                deleteStatement.executeUpdate();
            }
            if (!tags.isEmpty()) {
                try (PreparedStatement insertStatement = connection.prepareStatement("""
                        INSERT INTO bucket_tags (bucket_name, tag_key, tag_value)
                        VALUES (?, ?, ?)
                        """)) {
                    for (Map.Entry<String, String> tag : tags.entrySet()) {
                        insertStatement.setString(1, bucketName);
                        insertStatement.setString(2, tag.getKey());
                        insertStatement.setString(3, tag.getValue());
                        insertStatement.addBatch();
                    }
                    insertStatement.executeBatch();
                }
            }
            connection.commit();
            return findByBucketName(bucketName);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void delete(String bucketName) {
        ensureSchema();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement("DELETE FROM bucket_tags WHERE bucket_name = ?")) {
            statement.setString(1, bucketName);
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private synchronized void ensureSchema() {
        if (schemaReady) {
            return;
        }
        String sql = """
                CREATE TABLE IF NOT EXISTS bucket_tags (
                    bucket_name VARCHAR(63) NOT NULL,
                    tag_key VARCHAR(128) NOT NULL,
                    tag_value VARCHAR(256) NOT NULL,
                    PRIMARY KEY (bucket_name, tag_key),
                    INDEX idx_bucket_tags_key_value (tag_key, tag_value),
                    CONSTRAINT fk_bucket_tags_bucket
                        FOREIGN KEY (bucket_name) REFERENCES buckets(name)
                        ON DELETE CASCADE
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

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
