package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackInvoiceDraftRecord;
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
public class MariaDbChargebackInvoiceDraftRepository implements ChargebackInvoiceDraftRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbChargebackInvoiceDraftRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<ChargebackInvoiceDraftRecord> saveAll(List<ChargebackInvoiceDraftRecord> records) {
        ensureSchema();
        String sql = """
                INSERT INTO chargeback_invoice_drafts
                    (invoice_number, status, organization_id, organization_name, currency, window_from,
                     window_to, preview_generated_at, event_scan_limit, storage_gb_month_rate, ingress_gb_rate,
                     egress_gb_rate, internal_gb_rate, operation_thousand_rate, bucket_count, object_count,
                     used_bytes, storage_cost, traffic_cost, operation_cost, estimated_total_cost, requested_by,
                     approved_by, reason, approval_note, created_at, updated_at, approved_at, note)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;
        List<ChargebackInvoiceDraftRecord> saved = new ArrayList<>();
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            for (ChargebackInvoiceDraftRecord record : records) {
                bind(statement, record);
                statement.executeUpdate();
                saved.add(withId(record, generatedId(statement)));
            }
            return saved;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<ChargebackInvoiceDraftRecord> findAll(int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_invoice_drafts
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """;
        return query(sql, normalizeLimit(limit));
    }

    @Override
    public List<ChargebackInvoiceDraftRecord> findByStatus(String status, int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_invoice_drafts
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
    public Optional<ChargebackInvoiceDraftRecord> findById(long id) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_invoice_drafts
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
            List<ChargebackInvoiceDraftRecord> records = mapRows(statement);
            return records.stream().findFirst();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public ChargebackInvoiceDraftRecord updateApproval(
            long id,
            String status,
            String approvedBy,
            String approvalNote
    ) {
        ensureSchema();
        OffsetDateTime now = OffsetDateTime.now();
        String sql = """
                UPDATE chargeback_invoice_drafts
                SET status = ?, approved_by = ?, approval_note = ?, approved_at = ?, updated_at = ?
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);
            statement.setString(2, approvedBy);
            statement.setString(3, approvalNote);
            statement.setTimestamp(4, timestamp(now));
            statement.setTimestamp(5, timestamp(now));
            statement.setLong(6, id);
            int updated = statement.executeUpdate();
            if (updated == 0) {
                throw new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback invoice draft not found.");
            }
            return findById(id).orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback invoice draft not found."));
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void bind(PreparedStatement statement, ChargebackInvoiceDraftRecord record) throws SQLException {
        statement.setString(1, record.invoiceNumber());
        statement.setString(2, record.status());
        statement.setLong(3, record.organizationId());
        statement.setString(4, record.organizationName());
        statement.setString(5, record.currency());
        statement.setTimestamp(6, timestamp(record.from()));
        statement.setTimestamp(7, timestamp(record.to()));
        statement.setTimestamp(8, timestamp(record.previewGeneratedAt()));
        statement.setInt(9, record.eventScanLimit());
        statement.setBigDecimal(10, record.storageGbMonthRate());
        statement.setBigDecimal(11, record.ingressGbRate());
        statement.setBigDecimal(12, record.egressGbRate());
        statement.setBigDecimal(13, record.internalGbRate());
        statement.setBigDecimal(14, record.operationThousandRate());
        statement.setLong(15, record.bucketCount());
        statement.setLong(16, record.objectCount());
        statement.setLong(17, record.usedBytes());
        statement.setBigDecimal(18, record.storageCost());
        statement.setBigDecimal(19, record.trafficCost());
        statement.setBigDecimal(20, record.operationCost());
        statement.setBigDecimal(21, record.estimatedTotalCost());
        statement.setString(22, record.requestedBy());
        statement.setString(23, record.approvedBy());
        statement.setString(24, record.reason());
        statement.setString(25, record.approvalNote());
        statement.setTimestamp(26, timestamp(record.createdAt()));
        statement.setTimestamp(27, timestamp(record.updatedAt()));
        statement.setTimestamp(28, timestamp(record.approvedAt()));
        statement.setString(29, record.note());
    }

    private List<ChargebackInvoiceDraftRecord> query(String sql, int limit) {
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, limit);
            return mapRows(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private List<ChargebackInvoiceDraftRecord> mapRows(PreparedStatement statement) throws SQLException {
        List<ChargebackInvoiceDraftRecord> records = new ArrayList<>();
        try (ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                records.add(mapRow(resultSet));
            }
        }
        return records;
    }

    private ChargebackInvoiceDraftRecord mapRow(ResultSet resultSet) throws SQLException {
        return new ChargebackInvoiceDraftRecord(
                resultSet.getLong("id"),
                resultSet.getString("invoice_number"),
                resultSet.getString("status"),
                resultSet.getLong("organization_id"),
                resultSet.getString("organization_name"),
                resultSet.getString("currency"),
                offsetDateTime(resultSet.getTimestamp("window_from")),
                offsetDateTime(resultSet.getTimestamp("window_to")),
                offsetDateTime(resultSet.getTimestamp("preview_generated_at")),
                resultSet.getInt("event_scan_limit"),
                decimal(resultSet, "storage_gb_month_rate"),
                decimal(resultSet, "ingress_gb_rate"),
                decimal(resultSet, "egress_gb_rate"),
                decimal(resultSet, "internal_gb_rate"),
                decimal(resultSet, "operation_thousand_rate"),
                resultSet.getLong("bucket_count"),
                resultSet.getLong("object_count"),
                resultSet.getLong("used_bytes"),
                decimal(resultSet, "storage_cost"),
                decimal(resultSet, "traffic_cost"),
                decimal(resultSet, "operation_cost"),
                decimal(resultSet, "estimated_total_cost"),
                resultSet.getString("requested_by"),
                resultSet.getString("approved_by"),
                resultSet.getString("reason"),
                resultSet.getString("approval_note"),
                offsetDateTime(resultSet.getTimestamp("created_at")),
                offsetDateTime(resultSet.getTimestamp("updated_at")),
                offsetDateTime(resultSet.getTimestamp("approved_at")),
                resultSet.getString("note")
        );
    }

    private synchronized void ensureSchema() {
        if (schemaReady) {
            return;
        }
        String sql = """
                CREATE TABLE IF NOT EXISTS chargeback_invoice_drafts (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    invoice_number VARCHAR(128) NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    organization_id BIGINT NOT NULL,
                    organization_name VARCHAR(255) NOT NULL,
                    currency VARCHAR(12) NOT NULL,
                    window_from TIMESTAMP NULL,
                    window_to TIMESTAMP NULL,
                    preview_generated_at TIMESTAMP NOT NULL,
                    event_scan_limit INT NOT NULL,
                    storage_gb_month_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    ingress_gb_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    egress_gb_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    internal_gb_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    operation_thousand_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    bucket_count BIGINT NOT NULL DEFAULT 0,
                    object_count BIGINT NOT NULL DEFAULT 0,
                    used_bytes BIGINT NOT NULL DEFAULT 0,
                    storage_cost DECIMAL(18,6) NOT NULL DEFAULT 0,
                    traffic_cost DECIMAL(18,6) NOT NULL DEFAULT 0,
                    operation_cost DECIMAL(18,6) NOT NULL DEFAULT 0,
                    estimated_total_cost DECIMAL(18,6) NOT NULL DEFAULT 0,
                    requested_by VARCHAR(128) NOT NULL,
                    approved_by VARCHAR(128) NULL,
                    reason VARCHAR(512) NOT NULL,
                    approval_note VARCHAR(512) NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    approved_at TIMESTAMP NULL,
                    note VARCHAR(512) NOT NULL,
                    INDEX idx_chargeback_invoice_drafts_status_created (status, created_at),
                    INDEX idx_chargeback_invoice_drafts_org_created (organization_id, created_at)
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

    private static ChargebackInvoiceDraftRecord withId(ChargebackInvoiceDraftRecord record, Long id) {
        return new ChargebackInvoiceDraftRecord(
                id,
                record.invoiceNumber(),
                record.status(),
                record.organizationId(),
                record.organizationName(),
                record.currency(),
                record.from(),
                record.to(),
                record.previewGeneratedAt(),
                record.eventScanLimit(),
                record.storageGbMonthRate(),
                record.ingressGbRate(),
                record.egressGbRate(),
                record.internalGbRate(),
                record.operationThousandRate(),
                record.bucketCount(),
                record.objectCount(),
                record.usedBytes(),
                record.storageCost(),
                record.trafficCost(),
                record.operationCost(),
                record.estimatedTotalCost(),
                record.requestedBy(),
                record.approvedBy(),
                record.reason(),
                record.approvalNote(),
                record.createdAt(),
                record.updatedAt(),
                record.approvedAt(),
                record.note()
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
