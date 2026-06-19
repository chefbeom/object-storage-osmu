package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackFinalInvoiceRecord;
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
public class MariaDbChargebackFinalInvoiceRepository implements ChargebackFinalInvoiceRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbChargebackFinalInvoiceRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public ChargebackFinalInvoiceRecord save(ChargebackFinalInvoiceRecord record) {
        ensureSchema();
        String sql = """
                INSERT INTO chargeback_final_invoices
                    (source_draft_id, invoice_number, status, payment_status, organization_id, organization_name,
                     currency, window_from, window_to, preview_generated_at, event_scan_limit, storage_gb_month_rate,
                     ingress_gb_rate, egress_gb_rate, internal_gb_rate, operation_thousand_rate, bucket_count,
                     object_count, used_bytes, storage_cost, traffic_cost, operation_cost, estimated_total_cost,
                     requested_by, approved_by, finalized_by, payment_requested_by, payment_recorded_by, reason,
                     approval_note, finalization_note, payment_request_note, payment_reference, created_at, updated_at,
                     approved_at, finalized_at, payment_requested_at, paid_at, note)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            bind(statement, record);
            statement.executeUpdate();
            return withId(record, generatedId(statement));
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<ChargebackFinalInvoiceRecord> findAll(int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_final_invoices
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """;
        return query(sql, normalizeLimit(limit));
    }

    @Override
    public List<ChargebackFinalInvoiceRecord> findByStatus(String status, int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_final_invoices
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
    public Optional<ChargebackFinalInvoiceRecord> findById(long id) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_final_invoices
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
            List<ChargebackFinalInvoiceRecord> records = mapRows(statement);
            return records.stream().findFirst();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<ChargebackFinalInvoiceRecord> findBySourceDraftId(long sourceDraftId) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_final_invoices
                WHERE source_draft_id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, sourceDraftId);
            List<ChargebackFinalInvoiceRecord> records = mapRows(statement);
            return records.stream().findFirst();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public ChargebackFinalInvoiceRecord updatePaymentRequest(
            long id,
            String status,
            String paymentStatus,
            String paymentRequestedBy,
            String paymentRequestNote
    ) {
        ensureSchema();
        OffsetDateTime now = OffsetDateTime.now();
        String sql = """
                UPDATE chargeback_final_invoices
                SET status = ?, payment_status = ?, payment_requested_by = ?, payment_request_note = ?,
                    payment_requested_at = ?, updated_at = ?, note = ?
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);
            statement.setString(2, paymentStatus);
            statement.setString(3, paymentRequestedBy);
            statement.setString(4, paymentRequestNote);
            statement.setTimestamp(5, timestamp(now));
            statement.setTimestamp(6, timestamp(now));
            statement.setString(7, "Final invoice payment request recorded for billing operations.");
            statement.setLong(8, id);
            int updated = statement.executeUpdate();
            if (updated == 0) {
                throw new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback final invoice not found.");
            }
            return findById(id).orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback final invoice not found."));
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public ChargebackFinalInvoiceRecord updatePaymentRecord(
            long id,
            String status,
            String paymentStatus,
            String paymentRecordedBy,
            String paymentReference,
            String paymentRequestNote
    ) {
        ensureSchema();
        OffsetDateTime now = OffsetDateTime.now();
        String sql = """
                UPDATE chargeback_final_invoices
                SET status = ?, payment_status = ?, payment_recorded_by = ?, payment_reference = ?,
                    payment_request_note = ?, paid_at = ?, updated_at = ?, note = ?
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);
            statement.setString(2, paymentStatus);
            statement.setString(3, paymentRecordedBy);
            statement.setString(4, paymentReference);
            statement.setString(5, paymentRequestNote);
            statement.setTimestamp(6, timestamp(now));
            statement.setTimestamp(7, timestamp(now));
            statement.setString(8, "Final invoice payment recorded for billing operations.");
            statement.setLong(9, id);
            int updated = statement.executeUpdate();
            if (updated == 0) {
                throw new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback final invoice not found.");
            }
            return findById(id).orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback final invoice not found."));
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void bind(PreparedStatement statement, ChargebackFinalInvoiceRecord record) throws SQLException {
        statement.setLong(1, record.sourceDraftId());
        statement.setString(2, record.invoiceNumber());
        statement.setString(3, record.status());
        statement.setString(4, record.paymentStatus());
        statement.setLong(5, record.organizationId());
        statement.setString(6, record.organizationName());
        statement.setString(7, record.currency());
        statement.setTimestamp(8, timestamp(record.from()));
        statement.setTimestamp(9, timestamp(record.to()));
        statement.setTimestamp(10, timestamp(record.previewGeneratedAt()));
        statement.setInt(11, record.eventScanLimit());
        statement.setBigDecimal(12, record.storageGbMonthRate());
        statement.setBigDecimal(13, record.ingressGbRate());
        statement.setBigDecimal(14, record.egressGbRate());
        statement.setBigDecimal(15, record.internalGbRate());
        statement.setBigDecimal(16, record.operationThousandRate());
        statement.setLong(17, record.bucketCount());
        statement.setLong(18, record.objectCount());
        statement.setLong(19, record.usedBytes());
        statement.setBigDecimal(20, record.storageCost());
        statement.setBigDecimal(21, record.trafficCost());
        statement.setBigDecimal(22, record.operationCost());
        statement.setBigDecimal(23, record.estimatedTotalCost());
        statement.setString(24, record.requestedBy());
        statement.setString(25, record.approvedBy());
        statement.setString(26, record.finalizedBy());
        statement.setString(27, record.paymentRequestedBy());
        statement.setString(28, record.paymentRecordedBy());
        statement.setString(29, record.reason());
        statement.setString(30, record.approvalNote());
        statement.setString(31, record.finalizationNote());
        statement.setString(32, record.paymentRequestNote());
        statement.setString(33, record.paymentReference());
        statement.setTimestamp(34, timestamp(record.createdAt()));
        statement.setTimestamp(35, timestamp(record.updatedAt()));
        statement.setTimestamp(36, timestamp(record.approvedAt()));
        statement.setTimestamp(37, timestamp(record.finalizedAt()));
        statement.setTimestamp(38, timestamp(record.paymentRequestedAt()));
        statement.setTimestamp(39, timestamp(record.paidAt()));
        statement.setString(40, record.note());
    }

    private List<ChargebackFinalInvoiceRecord> query(String sql, int limit) {
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, limit);
            return mapRows(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private List<ChargebackFinalInvoiceRecord> mapRows(PreparedStatement statement) throws SQLException {
        List<ChargebackFinalInvoiceRecord> records = new ArrayList<>();
        try (ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                records.add(mapRow(resultSet));
            }
        }
        return records;
    }

    private ChargebackFinalInvoiceRecord mapRow(ResultSet resultSet) throws SQLException {
        return new ChargebackFinalInvoiceRecord(
                resultSet.getLong("id"),
                resultSet.getLong("source_draft_id"),
                resultSet.getString("invoice_number"),
                resultSet.getString("status"),
                resultSet.getString("payment_status"),
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
                resultSet.getString("finalized_by"),
                resultSet.getString("payment_requested_by"),
                resultSet.getString("payment_recorded_by"),
                resultSet.getString("reason"),
                resultSet.getString("approval_note"),
                resultSet.getString("finalization_note"),
                resultSet.getString("payment_request_note"),
                resultSet.getString("payment_reference"),
                offsetDateTime(resultSet.getTimestamp("created_at")),
                offsetDateTime(resultSet.getTimestamp("updated_at")),
                offsetDateTime(resultSet.getTimestamp("approved_at")),
                offsetDateTime(resultSet.getTimestamp("finalized_at")),
                offsetDateTime(resultSet.getTimestamp("payment_requested_at")),
                offsetDateTime(resultSet.getTimestamp("paid_at")),
                resultSet.getString("note")
        );
    }

    private synchronized void ensureSchema() {
        if (schemaReady) {
            return;
        }
        String sql = """
                CREATE TABLE IF NOT EXISTS chargeback_final_invoices (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    source_draft_id BIGINT NOT NULL,
                    invoice_number VARCHAR(128) NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    payment_status VARCHAR(32) NOT NULL,
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
                    approved_by VARCHAR(128) NOT NULL,
                    finalized_by VARCHAR(128) NOT NULL,
                    payment_requested_by VARCHAR(128) NULL,
                    payment_recorded_by VARCHAR(128) NULL,
                    reason VARCHAR(512) NOT NULL,
                    approval_note VARCHAR(512) NULL,
                    finalization_note VARCHAR(512) NOT NULL,
                    payment_request_note VARCHAR(512) NULL,
                    payment_reference VARCHAR(512) NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    approved_at TIMESTAMP NULL,
                    finalized_at TIMESTAMP NOT NULL,
                    payment_requested_at TIMESTAMP NULL,
                    paid_at TIMESTAMP NULL,
                    note VARCHAR(512) NOT NULL,
                    UNIQUE KEY uk_chargeback_final_invoices_source_draft (source_draft_id),
                    INDEX idx_chargeback_final_invoices_status_created (status, created_at),
                    INDEX idx_chargeback_final_invoices_payment_status (payment_status, updated_at),
                    INDEX idx_chargeback_final_invoices_org_created (organization_id, created_at)
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

    private static ChargebackFinalInvoiceRecord withId(ChargebackFinalInvoiceRecord record, Long id) {
        return new ChargebackFinalInvoiceRecord(
                id,
                record.sourceDraftId(),
                record.invoiceNumber(),
                record.status(),
                record.paymentStatus(),
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
                record.finalizedBy(),
                record.paymentRequestedBy(),
                record.paymentRecordedBy(),
                record.reason(),
                record.approvalNote(),
                record.finalizationNote(),
                record.paymentRequestNote(),
                record.paymentReference(),
                record.createdAt(),
                record.updatedAt(),
                record.approvedAt(),
                record.finalizedAt(),
                record.paymentRequestedAt(),
                record.paidAt(),
                record.note()
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
