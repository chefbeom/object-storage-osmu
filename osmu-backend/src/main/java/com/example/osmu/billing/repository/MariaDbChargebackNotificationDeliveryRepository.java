package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackAlertNotificationDeliveryRecord;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
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
public class MariaDbChargebackNotificationDeliveryRepository implements ChargebackNotificationDeliveryRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbChargebackNotificationDeliveryRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<ChargebackAlertNotificationDeliveryRecord> saveAll(List<ChargebackAlertNotificationDeliveryRecord> records) {
        ensureSchema();
        String sql = """
                INSERT INTO chargeback_notification_deliveries
                    (organization_id, organization_name, severity, estimated_total_cost, warning_amount,
                     critical_amount, channel, target, status, attempt_count, next_attempt_at, subject,
                     message, payload_json, requested_by, reason, created_at, updated_at, last_error)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;
        List<ChargebackAlertNotificationDeliveryRecord> saved = new ArrayList<>();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            for (ChargebackAlertNotificationDeliveryRecord record : records) {
                bind(statement, record);
                statement.executeUpdate();
                Long id = generatedId(statement);
                saved.add(withId(record, id));
            }
            return saved;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<ChargebackAlertNotificationDeliveryRecord> findById(long id) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_notification_deliveries
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
            List<ChargebackAlertNotificationDeliveryRecord> records = mapRows(statement);
            return records.stream().findFirst();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<ChargebackAlertNotificationDeliveryRecord> findAll(int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_notification_deliveries
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """;
        return query(sql, normalizeLimit(limit));
    }

    @Override
    public List<ChargebackAlertNotificationDeliveryRecord> findByStatus(String status, int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_notification_deliveries
                WHERE status = ?
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);
            statement.setInt(2, normalizeLimit(limit));
            return mapRows(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<ChargebackAlertNotificationDeliveryRecord> findByOrganizationId(long organizationId, int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_notification_deliveries
                WHERE organization_id = ?
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """;
        return queryByOrganization(sql, organizationId, normalizeLimit(limit));
    }

    @Override
    public ChargebackAlertNotificationDeliveryRecord update(ChargebackAlertNotificationDeliveryRecord record) {
        ensureSchema();
        String sql = """
                UPDATE chargeback_notification_deliveries
                SET status = ?, attempt_count = ?, next_attempt_at = ?, updated_at = ?, last_error = ?
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, record.status());
            statement.setInt(2, record.attemptCount());
            statement.setTimestamp(3, timestamp(record.nextAttemptAt()));
            statement.setTimestamp(4, timestamp(record.updatedAt()));
            statement.setString(5, record.lastError());
            statement.setLong(6, record.id());
            int updatedRows = statement.executeUpdate();
            if (updatedRows == 0) {
                throw new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback notification delivery not found.");
            }
            return findById(record.id())
                    .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback notification delivery not found."));
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void bind(PreparedStatement statement, ChargebackAlertNotificationDeliveryRecord record) throws SQLException {
        statement.setLong(1, record.organizationId());
        statement.setString(2, record.organizationName());
        statement.setString(3, record.severity());
        statement.setBigDecimal(4, record.estimatedTotalCost());
        statement.setBigDecimal(5, record.warningAmount());
        statement.setBigDecimal(6, record.criticalAmount());
        statement.setString(7, record.channel());
        statement.setString(8, record.target());
        statement.setString(9, record.status());
        statement.setInt(10, record.attemptCount());
        statement.setTimestamp(11, timestamp(record.nextAttemptAt()));
        statement.setString(12, record.subject());
        statement.setString(13, record.message());
        statement.setString(14, record.payloadJson());
        statement.setString(15, record.requestedBy());
        statement.setString(16, record.reason());
        statement.setTimestamp(17, timestamp(record.createdAt()));
        statement.setTimestamp(18, timestamp(record.updatedAt()));
        statement.setString(19, record.lastError());
    }

    private List<ChargebackAlertNotificationDeliveryRecord> query(String sql, int limit) {
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, limit);
            return mapRows(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private List<ChargebackAlertNotificationDeliveryRecord> queryByOrganization(String sql, long organizationId, int limit) {
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, organizationId);
            statement.setInt(2, limit);
            return mapRows(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private List<ChargebackAlertNotificationDeliveryRecord> mapRows(PreparedStatement statement) throws SQLException {
        List<ChargebackAlertNotificationDeliveryRecord> records = new ArrayList<>();
        try (ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                records.add(mapRow(resultSet));
            }
        }
        return records;
    }

    private ChargebackAlertNotificationDeliveryRecord mapRow(ResultSet resultSet) throws SQLException {
        return new ChargebackAlertNotificationDeliveryRecord(
                resultSet.getLong("id"),
                resultSet.getLong("organization_id"),
                resultSet.getString("organization_name"),
                resultSet.getString("severity"),
                decimal(resultSet, "estimated_total_cost"),
                decimal(resultSet, "warning_amount"),
                decimal(resultSet, "critical_amount"),
                resultSet.getString("channel"),
                resultSet.getString("target"),
                resultSet.getString("status"),
                resultSet.getInt("attempt_count"),
                offsetDateTime(resultSet.getTimestamp("next_attempt_at")),
                resultSet.getString("subject"),
                resultSet.getString("message"),
                resultSet.getString("payload_json"),
                resultSet.getString("requested_by"),
                resultSet.getString("reason"),
                offsetDateTime(resultSet.getTimestamp("created_at")),
                offsetDateTime(resultSet.getTimestamp("updated_at")),
                resultSet.getString("last_error")
        );
    }

    private synchronized void ensureSchema() {
        if (schemaReady) {
            return;
        }
        String sql = """
                CREATE TABLE IF NOT EXISTS chargeback_notification_deliveries (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    organization_id BIGINT NOT NULL,
                    organization_name VARCHAR(255) NOT NULL,
                    severity VARCHAR(32) NOT NULL,
                    estimated_total_cost DECIMAL(18,6) NOT NULL DEFAULT 0,
                    warning_amount DECIMAL(18,6) NOT NULL DEFAULT 0,
                    critical_amount DECIMAL(18,6) NOT NULL DEFAULT 0,
                    channel VARCHAR(32) NOT NULL,
                    target VARCHAR(512) NOT NULL,
                    status VARCHAR(64) NOT NULL,
                    attempt_count INT NOT NULL DEFAULT 0,
                    next_attempt_at TIMESTAMP NULL,
                    subject VARCHAR(512) NOT NULL,
                    message TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    requested_by VARCHAR(128) NOT NULL,
                    reason VARCHAR(512) NOT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    last_error VARCHAR(512) NULL,
                    INDEX idx_chargeback_notification_deliveries_org_created (organization_id, created_at),
                    INDEX idx_chargeback_notification_deliveries_status_next (status, next_attempt_at)
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

    private Long generatedId(PreparedStatement statement) throws SQLException {
        try (ResultSet generatedKeys = statement.getGeneratedKeys()) {
            return generatedKeys.next() ? generatedKeys.getLong(1) : null;
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private static int normalizeLimit(int limit) {
        return Math.max(1, Math.min(limit <= 0 ? 50 : limit, 200));
    }

    private static Timestamp timestamp(OffsetDateTime value) {
        return value == null ? null : Timestamp.from(value.toInstant());
    }

    private static OffsetDateTime offsetDateTime(Timestamp value) {
        return value == null ? null : value.toInstant().atOffset(ZoneOffset.UTC);
    }

    private static BigDecimal decimal(ResultSet resultSet, String columnName) throws SQLException {
        BigDecimal value = resultSet.getBigDecimal(columnName);
        return value == null ? BigDecimal.ZERO : value;
    }

    private static ChargebackAlertNotificationDeliveryRecord withId(
            ChargebackAlertNotificationDeliveryRecord record,
            Long id
    ) {
        return new ChargebackAlertNotificationDeliveryRecord(
                id,
                record.organizationId(),
                record.organizationName(),
                record.severity(),
                record.estimatedTotalCost(),
                record.warningAmount(),
                record.criticalAmount(),
                record.channel(),
                record.target(),
                record.status(),
                record.attemptCount(),
                record.nextAttemptAt(),
                record.subject(),
                record.message(),
                record.payloadJson(),
                record.requestedBy(),
                record.reason(),
                record.createdAt(),
                record.updatedAt(),
                record.lastError()
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
