package com.example.osmu.object.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Map;
import java.util.TreeMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbMultipartUploadPartChecksumRepository implements MultipartUploadPartChecksumRepository {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final TypeReference<Map<String, String>> CHECKSUM_MAP_TYPE = new TypeReference<>() {
    };

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbMultipartUploadPartChecksumRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public void save(String uploadId, int partNumber, Map<String, String> checksums) {
        if (uploadId == null || uploadId.isBlank() || checksums == null || checksums.isEmpty()) {
            return;
        }
        ensureSchema();
        String sql = """
                INSERT INTO multipart_upload_part_checksums (upload_id, part_number, checksums)
                VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE checksums = VALUES(checksums)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, uploadId);
            statement.setInt(2, partNumber);
            statement.setString(3, serializeChecksums(checksums));
            statement.executeUpdate();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Map<Integer, Map<String, String>> findByUploadId(String uploadId) {
        ensureSchema();
        String sql = """
                SELECT part_number, checksums
                FROM multipart_upload_part_checksums
                WHERE upload_id = ?
                ORDER BY part_number ASC
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, uploadId);
            try (ResultSet resultSet = statement.executeQuery()) {
                Map<Integer, Map<String, String>> values = new TreeMap<>();
                while (resultSet.next()) {
                    values.put(resultSet.getInt("part_number"), deserializeChecksums(resultSet.getString("checksums")));
                }
                return Map.copyOf(values);
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteByUploadId(String uploadId) {
        ensureSchema();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(
                     "DELETE FROM multipart_upload_part_checksums WHERE upload_id = ?"
             )) {
            statement.setString(1, uploadId);
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
                CREATE TABLE IF NOT EXISTS multipart_upload_part_checksums (
                    upload_id VARCHAR(64) NOT NULL,
                    part_number INT NOT NULL,
                    checksums TEXT NOT NULL,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (upload_id, part_number),
                    INDEX idx_multipart_upload_part_checksums_upload_id (upload_id)
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

    private String serializeChecksums(Map<String, String> checksums) {
        try {
            return OBJECT_MAPPER.writeValueAsString(checksums == null ? Map.of() : checksums);
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to serialize multipart part checksums.");
        }
    }

    private Map<String, String> deserializeChecksums(String rawChecksums) {
        if (rawChecksums == null || rawChecksums.isBlank()) {
            return Map.of();
        }
        try {
            return Map.copyOf(OBJECT_MAPPER.readValue(rawChecksums, CHECKSUM_MAP_TYPE));
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to parse multipart part checksums.");
        }
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
