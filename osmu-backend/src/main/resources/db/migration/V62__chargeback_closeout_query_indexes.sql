CREATE INDEX IF NOT EXISTS idx_chargeback_invoice_drafts_window
    ON chargeback_invoice_drafts (window_from, window_to, id);

CREATE INDEX IF NOT EXISTS idx_chargeback_final_invoices_window
    ON chargeback_final_invoices (window_from, window_to, id);

CREATE INDEX IF NOT EXISTS idx_chargeback_payment_handoffs_created
    ON chargeback_payment_provider_handoffs (created_at, id);

CREATE INDEX IF NOT EXISTS idx_chargeback_notification_deliveries_created
    ON chargeback_notification_deliveries (created_at, id);