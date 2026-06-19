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
);
