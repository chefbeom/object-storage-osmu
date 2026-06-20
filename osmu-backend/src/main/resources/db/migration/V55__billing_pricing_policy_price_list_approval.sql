ALTER TABLE billing_pricing_policy_proposals
    ADD COLUMN approved_price_list BOOLEAN NOT NULL DEFAULT FALSE AFTER approved_by,
    ADD COLUMN commercial_approved_by VARCHAR(128) NULL AFTER approval_note,
    ADD COLUMN commercial_approval_reference VARCHAR(128) NULL AFTER commercial_approved_by,
    ADD COLUMN commercial_approval_note VARCHAR(512) NULL AFTER commercial_approval_reference,
    ADD COLUMN commercial_approved_at TIMESTAMP NULL AFTER applied_at,
    ADD COLUMN commercial_effective_from TIMESTAMP NULL AFTER commercial_approved_at;

CREATE INDEX idx_billing_pricing_policy_proposals_price_list
    ON billing_pricing_policy_proposals (approved_price_list, commercial_approved_at);
