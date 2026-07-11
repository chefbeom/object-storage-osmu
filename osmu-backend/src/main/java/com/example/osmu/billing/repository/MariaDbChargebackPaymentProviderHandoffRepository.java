package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackPaymentProviderHandoffRecord;
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
public class MariaDbChargebackPaymentProviderHandoffRepository implements ChargebackPaymentProviderHandoffRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbChargebackPaymentProviderHandoffRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public ChargebackPaymentProviderHandoffRecord save(ChargebackPaymentProviderHandoffRecord record) {
        ensureSchema();
        String sql = """
                INSERT INTO chargeback_payment_provider_handoffs
                    (final_invoice_id, invoice_number, organization_id, organization_name, currency, amount,
                     provider, target_account, status, attempt_count, next_attempt_at, payload_json, requested_by,
                     reason, created_at, updated_at, last_error)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
    public Optional<ChargebackPaymentProviderHandoffRecord> findById(long id) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_payment_provider_handoffs
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
            List<ChargebackPaymentProviderHandoffRecord> records = mapRows(statement);
            return records.stream().findFirst();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<ChargebackPaymentProviderHandoffRecord> findAll(int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_payment_provider_handoffs
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """;
        return query(sql, normalizeLimit(limit));
    }

    @Override
    public List<ChargebackPaymentProviderHandoffRecord> findByStatus(String status, int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_payment_provider_handoffs
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
    public List<ChargebackPaymentProviderHandoffRecord> findForCloseout(
            List<Long> finalInvoiceIds,
            OffsetDateTime from,
            OffsetDateTime to,
            int limit
    ) {
        ensureSchema();
        List<Long> invoiceIds = finalInvoiceIds == null
                ? List.of()
                : finalInvoiceIds.stream().filter(java.util.Objects::nonNull).distinct().toList();
        StringBuilder sql = new StringBuilder(
                "SELECT * FROM chargeback_payment_provider_handoffs WHERE 1 = 1"
        );
        if (!invoiceIds.isEmpty()) {
            sql.append(" AND final_invoice_id IN (")
                    .append(String.join(", ", java.util.Collections.nCopies(invoiceIds.size(), "?")))
                    .append(")");
        } else {
            if (from != null) {
                sql.append(" AND created_at >= ?");
            }
            if (to != null) {
                sql.append(" AND created_at < ?");
            }
        }
        sql.append(" ORDER BY created_at DESC, id DESC LIMIT ?");
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            int parameterIndex = 1;
            if (!invoiceIds.isEmpty()) {
                for (Long invoiceId : invoiceIds) {
                    statement.setLong(parameterIndex++, invoiceId);
                }
            } else {
                if (from != null) {
                    statement.setTimestamp(parameterIndex++, timestamp(from));
                }
                if (to != null) {
                    statement.setTimestamp(parameterIndex++, timestamp(to));
                }
            }
            statement.setInt(parameterIndex, Math.max(1, limit));
            return mapRows(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<ChargebackPaymentProviderHandoffRecord> findDueAdapterRetries(OffsetDateTime now, int limit) {
        ensureSchema();
        String sql = """
                SELECT *
                FROM chargeback_payment_provider_handoffs
                WHERE status IN ('PENDING_PAYMENT_PROVIDER_ADAPTER', 'PAYMENT_PROVIDER_ADAPTER_RETRY_SCHEDULED')
                  AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
                ORDER BY updated_at ASC, id ASC
                LIMIT ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setTimestamp(1, timestamp(now));
            statement.setInt(2, normalizeLimit(limit));
            return mapRows(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public ChargebackPaymentProviderHandoffRecord update(ChargebackPaymentProviderHandoffRecord record) {
        ensureSchema();
        String sql = """
                UPDATE chargeback_payment_provider_handoffs
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
                throw new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback payment handoff not found.");
            }
            return findById(record.id())
                    .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback payment handoff not found."));
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private void bind(PreparedStatement statement, ChargebackPaymentProviderHandoffRecord record) throws SQLException {
        statement.setLong(1, record.finalInvoiceId());
        statement.setString(2, record.invoiceNumber());
        statement.setLong(3, record.organizationId());
        statement.setString(4, record.organizationName());
        statement.setString(5, record.currency());
        statement.setBigDecimal(6, record.amount());
        statement.setString(7, record.provider());
        statement.setString(8, record.targetAccount());
        statement.setString(9, record.status());
        statement.setInt(10, record.attemptCount());
        statement.setTimestamp(11, timestamp(record.nextAttemptAt()));
        statement.setString(12, record.payloadJson());
        statement.setString(13, record.requestedBy());
        statement.setString(14, record.reason());
        statement.setTimestamp(15, timestamp(record.createdAt()));
        statement.setTimestamp(16, timestamp(record.updatedAt()));
        statement.setString(17, record.lastError());
    }

    private List<ChargebackPaymentProviderHandoffRecord> query(String sql, int limit) {
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, limit);
            return mapRows(statement);
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private List<ChargebackPaymentProviderHandoffRecord> mapRows(PreparedStatement statement) throws SQLException {
        List<ChargebackPaymentProviderHandoffRecord> records = new ArrayList<>();
        try (ResultSet resultSet = statement.executeQuery()) {
            while (resultSet.next()) {
                records.add(mapRow(resultSet));
            }
        }
        return records;
    }

    private ChargebackPaymentProviderHandoffRecord mapRow(ResultSet resultSet) throws SQLException {
        return new ChargebackPaymentProviderHandoffRecord(
                resultSet.getLong("id"),
                resultSet.getLong("final_invoice_id"),
                resultSet.getString("invoice_number"),
                resultSet.getLong("organization_id"),
                resultSet.getString("organization_name"),
                resultSet.getString("currency"),
                decimal(resultSet, "amount"),
                resultSet.getString("provider"),
                resultSet.getString("target_account"),
                resultSet.getString("status"),
                resultSet.getInt("attempt_count"),
                offsetDateTime(resultSet.getTimestamp("next_attempt_at")),
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
                CREATE TABLE IF NOT EXISTS chargeback_payment_provider_handoffs (
                    id BIGINT AUTO_INCREMENT PRIMARY KEY,
                    final_invoice_id BIGINT NOT NULL,
                    invoice_number VARCHAR(128) NOT NULL,
                    organization_id BIGINT NOT NULL,
                    organization_name VARCHAR(255) NOT NULL,
                    currency VARCHAR(12) NOT NULL,
                    amount DECIMAL(18,6) NOT NULL DEFAULT 0,
                    provider VARCHAR(64) NOT NULL,
                    target_account VARCHAR(512) NOT NULL,
                    status VARCHAR(64) NOT NULL,
                    attempt_count INT NOT NULL DEFAULT 0,
                    next_attempt_at TIMESTAMP NULL,
                    payload_json TEXT NOT NULL,
                    requested_by VARCHAR(128) NOT NULL,
                    reason VARCHAR(512) NOT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    last_error VARCHAR(512) NULL,
                    INDEX idx_chargeback_payment_handoffs_invoice_created (final_invoice_id, created_at),
                    INDEX idx_chargeback_payment_handoffs_status_next (status, next_attempt_at),
                    INDEX idx_chargeback_payment_handoffs_org_created (organization_id, created_at),
                    INDEX idx_chargeback_payment_handoffs_created (created_at, id)
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

    private static ChargebackPaymentProviderHandoffRecord withId(
            ChargebackPaymentProviderHandoffRecord record,
            Long id
    ) {
        return new ChargebackPaymentProviderHandoffRecord(
                id,
                record.finalInvoiceId(),
                record.invoiceNumber(),
                record.organizationId(),
                record.organizationName(),
                record.currency(),
                record.amount(),
                record.provider(),
                record.targetAccount(),
                record.status(),
                record.attemptCount(),
                record.nextAttemptAt(),
                record.payloadJson(),
                record.requestedBy(),
                record.reason(),
                record.createdAt(),
                record.updatedAt(),
                record.lastError()
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.STORAGE_ERROR, "Chargeback payment handoff metadata store error: " + exception.getMessage());
    }
}
