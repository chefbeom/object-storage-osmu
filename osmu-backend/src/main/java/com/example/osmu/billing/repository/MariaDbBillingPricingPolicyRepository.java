package com.example.osmu.billing.repository;

import com.example.osmu.billing.BillingPricingPolicy;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.ZoneOffset;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbBillingPricingPolicyRepository implements BillingPricingPolicyRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbBillingPricingPolicyRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public BillingPricingPolicy get() {
        ensureSchema();
        String sql = """
                SELECT currency, storage_gb_month_rate, ingress_gb_rate, egress_gb_rate,
                       internal_gb_rate, operation_thousand_rate, event_scan_limit, updated_at
                FROM billing_pricing_policy
                WHERE id = 1
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            return resultSet.next() ? mapRow(resultSet) : BillingPricingPolicy.defaults();
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public BillingPricingPolicy save(BillingPricingPolicy policy) {
        ensureSchema();
        String sql = """
                INSERT INTO billing_pricing_policy
                    (id, currency, storage_gb_month_rate, ingress_gb_rate, egress_gb_rate,
                     internal_gb_rate, operation_thousand_rate, event_scan_limit, updated_at)
                VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    currency = VALUES(currency),
                    storage_gb_month_rate = VALUES(storage_gb_month_rate),
                    ingress_gb_rate = VALUES(ingress_gb_rate),
                    egress_gb_rate = VALUES(egress_gb_rate),
                    internal_gb_rate = VALUES(internal_gb_rate),
                    operation_thousand_rate = VALUES(operation_thousand_rate),
                    event_scan_limit = VALUES(event_scan_limit),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, policy.currency());
            statement.setBigDecimal(2, policy.storageGbMonthRate());
            statement.setBigDecimal(3, policy.ingressGbRate());
            statement.setBigDecimal(4, policy.egressGbRate());
            statement.setBigDecimal(5, policy.internalGbRate());
            statement.setBigDecimal(6, policy.operationThousandRate());
            statement.setInt(7, policy.eventScanLimit());
            statement.setTimestamp(8, Timestamp.from(policy.updatedAt().toInstant()));
            statement.executeUpdate();
            return policy;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private synchronized void ensureSchema() {
        if (schemaReady) {
            return;
        }
        String sql = """
                CREATE TABLE IF NOT EXISTS billing_pricing_policy (
                    id TINYINT NOT NULL PRIMARY KEY,
                    currency VARCHAR(12) NOT NULL DEFAULT 'USD',
                    storage_gb_month_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    ingress_gb_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    egress_gb_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    internal_gb_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    operation_thousand_rate DECIMAL(18,6) NOT NULL DEFAULT 0,
                    event_scan_limit INT NOT NULL DEFAULT 10000,
                    updated_at TIMESTAMP NULL,
                    CONSTRAINT chk_billing_pricing_policy_singleton CHECK (id = 1),
                    CONSTRAINT chk_billing_pricing_policy_event_scan_limit CHECK (event_scan_limit >= 1)
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

    private BillingPricingPolicy mapRow(ResultSet resultSet) throws SQLException {
        Timestamp updatedAt = resultSet.getTimestamp("updated_at");
        return new BillingPricingPolicy(
                resultSet.getString("currency"),
                decimal(resultSet, "storage_gb_month_rate"),
                decimal(resultSet, "ingress_gb_rate"),
                decimal(resultSet, "egress_gb_rate"),
                decimal(resultSet, "internal_gb_rate"),
                decimal(resultSet, "operation_thousand_rate"),
                resultSet.getInt("event_scan_limit"),
                updatedAt == null ? null : updatedAt.toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private BigDecimal decimal(ResultSet resultSet, String columnName) throws SQLException {
        BigDecimal value = resultSet.getBigDecimal(columnName);
        return value == null ? BigDecimal.ZERO : value;
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
