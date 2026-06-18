package com.example.osmu.admin.repository;

import com.example.osmu.admin.BackupRestoreDrillEvidenceResponse;
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
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbBackupRestoreDrillEvidenceRepository implements BackupRestoreDrillEvidenceRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbBackupRestoreDrillEvidenceRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public Optional<BackupRestoreDrillEvidenceResponse> findLatest() {
        return findLatestByResult(null);
    }

    @Override
    public Optional<BackupRestoreDrillEvidenceResponse> findLatestByResult(String result) {
        List<BackupRestoreDrillEvidenceResponse> records = findRecent(result, 1);
        if (records.isEmpty()) {
            return Optional.empty();
        }
        return Optional.of(records.get(0));
    }

    @Override
    public List<BackupRestoreDrillEvidenceResponse> findRecent(String result, int limit) {
        ensureSchema();
        String normalizedResult = normalizeResult(result);
        StringBuilder sql = new StringBuilder("""
                SELECT audit_log_id, environment, operator_name, result, started_at, completed_at,
                       backup_timestamp, restore_duration_minutes, observed_rpo_hours, rpo_target_met,
                       rto_target_met, metadata_row_count, object_count, object_bytes,
                       backup_manifest_sha256, evidence_uri, gaps_text, status_impact, recorded_at
                FROM backup_restore_drill_evidence
                WHERE 1 = 1
                """);
        List<Object> parameters = new ArrayList<>();
        if (normalizedResult != null) {
            sql.append(" AND result = ?");
            parameters.add(normalizedResult);
        }
        sql.append(" ORDER BY recorded_at DESC, audit_log_id DESC LIMIT ?");
        parameters.add(Math.max(0, limit));

        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            bindParameters(statement, parameters);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<BackupRestoreDrillEvidenceResponse> records = new ArrayList<>();
                while (resultSet.next()) {
                    records.add(mapRow(resultSet));
                }
                return records;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public BackupRestoreDrillEvidenceResponse save(BackupRestoreDrillEvidenceResponse evidence) {
        ensureSchema();
        String sql = """
                INSERT INTO backup_restore_drill_evidence
                    (audit_log_id, environment, operator_name, result, started_at, completed_at,
                     backup_timestamp, restore_duration_minutes, observed_rpo_hours, rpo_target_met,
                     rto_target_met, metadata_row_count, object_count, object_bytes,
                     backup_manifest_sha256, evidence_uri, gaps_text, status_impact, recorded_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    environment = VALUES(environment),
                    operator_name = VALUES(operator_name),
                    result = VALUES(result),
                    started_at = VALUES(started_at),
                    completed_at = VALUES(completed_at),
                    backup_timestamp = VALUES(backup_timestamp),
                    restore_duration_minutes = VALUES(restore_duration_minutes),
                    observed_rpo_hours = VALUES(observed_rpo_hours),
                    rpo_target_met = VALUES(rpo_target_met),
                    rto_target_met = VALUES(rto_target_met),
                    metadata_row_count = VALUES(metadata_row_count),
                    object_count = VALUES(object_count),
                    object_bytes = VALUES(object_bytes),
                    backup_manifest_sha256 = VALUES(backup_manifest_sha256),
                    evidence_uri = VALUES(evidence_uri),
                    gaps_text = VALUES(gaps_text),
                    status_impact = VALUES(status_impact),
                    recorded_at = VALUES(recorded_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, evidence.auditLogId());
            statement.setString(2, evidence.environment());
            statement.setString(3, evidence.operator());
            statement.setString(4, evidence.result());
            statement.setTimestamp(5, timestamp(evidence.startedAt()));
            statement.setTimestamp(6, timestamp(evidence.completedAt()));
            statement.setTimestamp(7, timestamp(evidence.backupTimestamp()));
            statement.setLong(8, evidence.restoreDurationMinutes());
            statement.setLong(9, evidence.observedRpoHours());
            statement.setBoolean(10, evidence.rpoTargetMet());
            statement.setBoolean(11, evidence.rtoTargetMet());
            statement.setLong(12, evidence.metadataRowCount());
            statement.setLong(13, evidence.objectCount());
            statement.setLong(14, evidence.objectBytes());
            statement.setString(15, evidence.backupManifestSha256());
            statement.setString(16, evidence.evidenceUri());
            statement.setString(17, encodeGaps(evidence.gaps()));
            statement.setString(18, evidence.statusImpact());
            statement.setTimestamp(19, timestamp(evidence.recordedAt()));
            statement.executeUpdate();
            return evidence;
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
                CREATE TABLE IF NOT EXISTS backup_restore_drill_evidence (
                    audit_log_id BIGINT NOT NULL PRIMARY KEY,
                    environment VARCHAR(160) NOT NULL,
                    operator_name VARCHAR(160) NOT NULL,
                    result VARCHAR(32) NOT NULL,
                    started_at TIMESTAMP NULL,
                    completed_at TIMESTAMP NULL,
                    backup_timestamp TIMESTAMP NULL,
                    restore_duration_minutes BIGINT NOT NULL,
                    observed_rpo_hours BIGINT NOT NULL,
                    rpo_target_met BOOLEAN NOT NULL,
                    rto_target_met BOOLEAN NOT NULL,
                    metadata_row_count BIGINT NOT NULL,
                    object_count BIGINT NOT NULL,
                    object_bytes BIGINT NOT NULL,
                    backup_manifest_sha256 VARCHAR(64) NULL,
                    evidence_uri VARCHAR(255) NULL,
                    gaps_text MEDIUMTEXT NULL,
                    status_impact VARCHAR(64) NOT NULL,
                    recorded_at TIMESTAMP NOT NULL,
                    KEY idx_backup_restore_drill_result_recorded (result, recorded_at, audit_log_id),
                    KEY idx_backup_restore_drill_recorded (recorded_at, audit_log_id)
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

    private BackupRestoreDrillEvidenceResponse mapRow(ResultSet resultSet) throws SQLException {
        return new BackupRestoreDrillEvidenceResponse(
                resultSet.getLong("audit_log_id"),
                resultSet.getString("environment"),
                resultSet.getString("operator_name"),
                resultSet.getString("result"),
                timestampString(resultSet.getTimestamp("started_at")),
                timestampString(resultSet.getTimestamp("completed_at")),
                timestampString(resultSet.getTimestamp("backup_timestamp")),
                resultSet.getLong("restore_duration_minutes"),
                resultSet.getLong("observed_rpo_hours"),
                resultSet.getBoolean("rpo_target_met"),
                resultSet.getBoolean("rto_target_met"),
                resultSet.getLong("metadata_row_count"),
                resultSet.getLong("object_count"),
                resultSet.getLong("object_bytes"),
                resultSet.getString("backup_manifest_sha256"),
                resultSet.getString("evidence_uri"),
                decodeGaps(resultSet.getString("gaps_text")),
                resultSet.getString("status_impact"),
                timestampString(resultSet.getTimestamp("recorded_at"))
        );
    }

    private Timestamp timestamp(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return Timestamp.from(OffsetDateTime.parse(value).toInstant());
    }

    private String timestampString(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant().atOffset(ZoneOffset.UTC).toString();
    }

    private String encodeGaps(List<String> gaps) {
        if (gaps == null || gaps.isEmpty()) {
            return "";
        }
        return String.join("\n", gaps);
    }

    private List<String> decodeGaps(String value) {
        if (value == null || value.isBlank()) {
            return List.of();
        }
        return Arrays.stream(value.split("\\R"))
                .filter(line -> !line.isBlank())
                .toList();
    }

    private String normalizeResult(String result) {
        return result == null || result.isBlank() ? null : result.trim().toUpperCase(java.util.Locale.ROOT);
    }

    private void bindParameters(PreparedStatement statement, List<Object> parameters) throws SQLException {
        for (int index = 0; index < parameters.size(); index += 1) {
            Object parameter = parameters.get(index);
            if (parameter instanceof Integer integer) {
                statement.setInt(index + 1, integer);
            } else {
                statement.setString(index + 1, parameter.toString());
            }
        }
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
