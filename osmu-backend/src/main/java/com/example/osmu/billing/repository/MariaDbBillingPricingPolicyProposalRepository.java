package com.example.osmu.billing.repository;

import com.example.osmu.billing.BillingPricingPolicyProposalRecord;
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
public class MariaDbBillingPricingPolicyProposalRepository implements BillingPricingPolicyProposalRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbBillingPricingPolicyProposalRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public BillingPricingPolicyProposalRecord save(BillingPricingPolicyProposalRecord record) {
        ensureSchema();
        String sql = """
                INSERT INTO billing_pricing_policy_proposals
                    (status, currency, storage_gb_month_rate, ingress_gb_rate, egress_gb_rate,
                     internal_gb_rate, operation_thousand_rate, warning_amount, critical_amount,
                     event_scan_limit, requested_by, approved_by, approved_price_list, reason, approval_note,
                     commercial_approved_by, commercial_approval_reference, commercial_approval_note,
                     created_at, updated_at, approved_at, applied_at, commercial_approved_at, commercial_effective_from)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
    public List<BillingPricingPolicyProposalRecord> findAll(int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM billing_pricing_policy_proposals
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """;
        return query(sql, normalizeLimit(limit));
    }

    @Override
    public List<BillingPricingPolicyProposalRecord> findByStatus(String status, int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM billing_pricing_policy_proposals
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
    public Optional<BillingPricingPolicyProposalRecord> findById(long id) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM billing_pricing_policy_proposals
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
            return mapRows(statement).stream().findFirst();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public BillingPricingPolicyProposalRecord updateApproval(
            long id,
            String status,
            String approvedBy,
            String approvalNote
    ) {
        ensureSchema();
        OffsetDateTime now = OffsetDateTime.now();
        String sql = """
                UPDATE billing_pricing_policy_proposals
                SET status = ?, approved_by = ?, approved_price_list = FALSE, approval_note = ?, approved_at = ?, applied_at = ?, updated_at = ?
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);
            statement.setString(2, approvedBy);
            statement.setString(3, approvalNote);
            statement.setTimestamp(4, timestamp(now));
            statement.setTimestamp(5, timestamp(now));
            statement.setTimestamp(6, timestamp(now));
            statement.setLong(7, id);
            int updated = statement.executeUpdate();
            if (updated == 0) {
                throw new ApiException(ApiErrorCode.NOT_FOUND, "Billing pricing policy proposal not found.");
            }
            return findById(id).orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Billing pricing policy proposal not found."));
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public BillingPricingPolicyProposalRecord updateCommercialApproval(
            long id,
            String status,
            String approvedBy,
            String approvalReference,
            String approvalNote,
            OffsetDateTime effectiveFrom
    ) {
        ensureSchema();
        OffsetDateTime now = OffsetDateTime.now();
        String sql = """
                UPDATE billing_pricing_policy_proposals
                SET status = ?,
                    approved_price_list = TRUE,
                    commercial_approved_by = ?,
                    commercial_approval_reference = ?,
                    commercial_approval_note = ?,
                    commercial_approved_at = ?,
                    commercial_effective_from = ?,
                    updated_at = ?
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, status);
            statement.setString(2, approvedBy);
            statement.setString(3, approvalReference);
            statement.setString(4, approvalNote);
            statement.setTimestamp(5, timestamp(now));
            statement.setTimestamp(6, timestamp(effectiveFrom));
            statement.setTimestamp(7, timestamp(now));
            statement.setLong(8, id);
            int updated = statement.executeUpdate();
            if (updated == 0) {
                throw new ApiException(ApiErrorCode.NOT_FOUND, "Billing pricing policy proposal not found.");
            }
            return findById(id).orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Billing pricing policy proposal not found."));
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void bind(PreparedStatement statement, BillingPricingPolicyProposalRecord record) throws SQLException {
        statement.setString(1, record.status());
        statement.setString(2, record.currency());
        statement.setBigDecimal(3, record.storageGbMonthRate());
        statement.setBigDecimal(4, record.ingressGbRate());
        statement.setBigDecimal(5, record.egressGbRate());
        statement.setBigDecimal(6, record.internalGbRate());
        statement.setBigDecimal(7, record.operationThousandRate());
        statement.setBigDecimal(8, record.warningAmount());
        statement.setBigDecimal(9, record.criticalAmount());
        statement.setInt(10, record.eventScanLimit());
        statement.setString(11, record.requestedBy());
        statement.setString(12, record.approvedBy());
        statement.setBoolean(13, record.approvedPriceList());
        statement.setString(14, record.reason());
        statement.setString(15, record.approvalNote());
        statement.setString(16, record.commercialApprovedBy());
        statement.setString(17, record.commercialApprovalReference());
        statement.setString(18, record.commercialApprovalNote());
        statement.setTimestamp(19, timestamp(record.createdAt()));
        statement.setTimestamp(20, timestamp(record.updatedAt()));
        statement.setTimestamp(21, timestamp(record.approvedAt()));
        statement.setTimestamp(22, timestamp(record.appliedAt()));
        statement.setTimestamp(23, timestamp(record.commercialApprovedAt()));
        statement.setTimestamp(24, timestamp(record.commercialEffectiveFrom()));
    }

    private List<BillingPricingPolicyProposalRecord> query(String sql, int limit) {
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, limit);
            return mapRows(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private List<BillingPricingPolicyProposalRecord> mapRows(PreparedStatement statement) throws SQLException {
        List<BillingPricingPolicyProposalRecord> records = new ArrayList<>();
        try (ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                records.add(mapRow(resultSet));
            }
        }
        return records;
    }

    private BillingPricingPolicyProposalRecord mapRow(ResultSet resultSet) throws SQLException {
        return new BillingPricingPolicyProposalRecord(
                resultSet.getLong("id"),
                resultSet.getString("status"),
                resultSet.getString("currency"),
                decimal(resultSet, "storage_gb_month_rate"),
                decimal(resultSet, "ingress_gb_rate"),
                decimal(resultSet, "egress_gb_rate"),
                decimal(resultSet, "internal_gb_rate"),
                decimal(resultSet, "operation_thousand_rate"),
                decimal(resultSet, "warning_amount"),
                decimal(resultSet, "critical_amount"),
                resultSet.getInt("event_scan_limit"),
                resultSet.getString("requested_by"),
                resultSet.getString("approved_by"),
                resultSet.getBoolean("approved_price_list"),
                resultSet.getString("reason"),
                resultSet.getString("approval_note"),
                resultSet.getString("commercial_approved_by"),
                resultSet.getString("commercial_approval_reference"),
                resultSet.getString("commercial_approval_note"),
                offsetDateTime(resultSet.getTimestamp("created_at")),
                offsetDateTime(resultSet.getTimestamp("updated_at")),
                offsetDateTime(resultSet.getTimestamp("approved_at")),
                offsetDateTime(resultSet.getTimestamp("applied_at")),
                offsetDateTime(resultSet.getTimestamp("commercial_approved_at")),
                offsetDateTime(resultSet.getTimestamp("commercial_effective_from"))
        );
    }

    private synchronized void ensureSchema() {
        if (schemaReady) {
            return;
        }
        String sql = """
                CREATE TABLE IF NOT EXISTS billing_pricing_policy_proposals (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    status VARCHAR(32) NOT NULL,
                    currency VARCHAR(12) NOT NULL,
                    storage_gb_month_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    ingress_gb_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    egress_gb_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    internal_gb_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    operation_thousand_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    warning_amount DECIMAL(18,6) NOT NULL DEFAULT 0,
                    critical_amount DECIMAL(18,6) NOT NULL DEFAULT 0,
                    event_scan_limit INT NOT NULL DEFAULT 10000,
                    requested_by VARCHAR(128) NOT NULL,
                    approved_by VARCHAR(128) NULL,
                    approved_price_list BOOLEAN NOT NULL DEFAULT FALSE,
                    reason VARCHAR(512) NOT NULL,
                    approval_note VARCHAR(512) NULL,
                    commercial_approved_by VARCHAR(128) NULL,
                    commercial_approval_reference VARCHAR(128) NULL,
                    commercial_approval_note VARCHAR(512) NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    approved_at TIMESTAMP NULL,
                    applied_at TIMESTAMP NULL,
                    commercial_approved_at TIMESTAMP NULL,
                    commercial_effective_from TIMESTAMP NULL,
                    INDEX idx_billing_pricing_policy_proposals_status_created (status, created_at),
                    INDEX idx_billing_pricing_policy_proposals_price_list (approved_price_list, commercial_approved_at)
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

    private static BillingPricingPolicyProposalRecord withId(BillingPricingPolicyProposalRecord record, Long id) {
        return new BillingPricingPolicyProposalRecord(
                id,
                record.status(),
                record.currency(),
                record.storageGbMonthRate(),
                record.ingressGbRate(),
                record.egressGbRate(),
                record.internalGbRate(),
                record.operationThousandRate(),
                record.warningAmount(),
                record.criticalAmount(),
                record.eventScanLimit(),
                record.requestedBy(),
                record.approvedBy(),
                record.approvedPriceList(),
                record.reason(),
                record.approvalNote(),
                record.commercialApprovedBy(),
                record.commercialApprovalReference(),
                record.commercialApprovalNote(),
                record.createdAt(),
                record.updatedAt(),
                record.approvedAt(),
                record.appliedAt(),
                record.commercialApprovedAt(),
                record.commercialEffectiveFrom()
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
