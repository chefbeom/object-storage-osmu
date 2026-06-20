package com.example.osmu.auth;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class AdminRbacPolicyTest {

    private final AdminRbacPolicy policy = new AdminRbacPolicy();

    @Test
    void adminCanAccessEveryAdminRoute() {
        assertTrue(policy.isAllowed("GET", "/api/admin/backup/status", "ADMIN"));
        assertTrue(policy.isAllowed("POST", "/api/admin/storage-expansion/requests/1/apply-runner", "ADMIN"));
        assertTrue(policy.isAllowed("DELETE", "/api/admin/organizations/1", "ADMIN"));
    }

    @Test
    void orgAdminCanAccessOnlyScopedIdentityAndOrganizationReadRoutes() {
        assertTrue(policy.isAllowed("GET", "/api/admin/users", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("POST", "/api/admin/users", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("PATCH", "/api/admin/users/123/status", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("GET", "/api/admin/organizations", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("GET", "/api/admin/organizations/usage", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("GET", "/api/admin/billing/pricing-policy", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("GET", "/api/admin/billing/chargeback-alerts", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("GET", "/api/admin/billing/chargeback-alert-notifications/preview", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("GET", "/api/admin/billing/chargeback-alert-notifications/outbox", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("POST", "/api/admin/billing/chargeback-alert-notifications/outbox", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("GET", "/api/admin/billing/chargeback-preview", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("GET", "/api/admin/billing/chargeback-preview/export.csv", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("GET", "/api/admin/billing/chargeback-invoice-draft/export.csv", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("GET", "/api/admin/teams", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("POST", "/api/admin/teams", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("PUT", "/api/admin/teams/123/members", "ORG_ADMIN"));
        assertTrue(policy.isAllowed("DELETE", "/api/admin/teams/123", "ORG_ADMIN"));

        assertFalse(policy.isAllowed("GET", "/api/admin/audit-logs", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("GET", "/api/admin/backup/status", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("GET", "/api/admin/backup/restore-drill-evidence", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/backup/restore-drill-evidence", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("GET", "/api/admin/storage-expansion/summary", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/storage-expansion/requests", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("PUT", "/api/admin/quota-policies/USER/1", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("PUT", "/api/admin/billing/pricing-policy", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-invoice-drafts", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoice-drafts", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoice-drafts/123/approve", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoice-drafts/123/finalize", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-alert-notifications/outbox/123/adapter-result", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-invoices", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoices/123/payment-request", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-invoices/123/payment-provider-handoff/preview", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoices/123/payment-provider-handoff", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-payment-provider-handoffs", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-payment-provider-handoffs/123/adapter-result", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoices/123/payment-record", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/pricing-policy-proposals", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/pricing-policy-proposals", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/pricing-policy-proposals/123/approve", "ORG_ADMIN"));
        assertFalse(policy.isAllowed("DELETE", "/api/admin/organizations/1", "ORG_ADMIN"));
    }

    @Test
    void auditorCanAccessOnlyReadOnlyAuditAndStatusRoutes() {
        assertTrue(policy.isAllowed("GET", "/api/admin/audit-logs", "AUDITOR"));
        assertTrue(policy.isAllowed("GET", "/api/admin/audit-logs/export.csv", "AUDITOR"));
        assertTrue(policy.isAllowed("GET", "/api/admin/usage", "AUDITOR"));
        assertTrue(policy.isAllowed("GET", "/api/admin/system/status", "AUDITOR"));
        assertTrue(policy.isAllowed("GET", "/api/admin/security/enterprise-auth-plan", "AUDITOR"));
        assertTrue(policy.isAllowed("GET", "/api/admin/dashboard/summary", "AUDITOR"));
        assertTrue(policy.isAllowed("GET", "/api/admin/dashboard/readiness", "AUDITOR"));
        assertTrue(policy.isAllowed("GET", "/api/admin/backup/status", "AUDITOR"));
        assertTrue(policy.isAllowed("GET", "/api/admin/backup/restore-drill-evidence", "AUDITOR"));

        assertFalse(policy.isAllowed("POST", "/api/admin/users", "AUDITOR"));
        assertFalse(policy.isAllowed("PATCH", "/api/admin/users/123/status", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/backup/restore-drill-evidence", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/security/enterprise-auth-plan", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/security/enterprise-auth/claim-preview", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/security/enterprise-auth/jit-provision", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/storage-expansion/summary", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/storage-expansion/requests", "AUDITOR"));
        assertFalse(policy.isAllowed("PUT", "/api/admin/quota-policies/USER/1", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/pricing-policy", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-alerts", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-alert-notifications/preview", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-alert-notifications/outbox", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-alert-notifications/outbox", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-alert-notifications/outbox/123/adapter-result", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-invoice-drafts", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoice-drafts", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoice-drafts/123/approve", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoice-drafts/123/finalize", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-invoices", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoices/123/payment-request", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-invoices/123/payment-provider-handoff/preview", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoices/123/payment-provider-handoff", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-payment-provider-handoffs", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-payment-provider-handoffs/123/adapter-result", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/chargeback-invoices/123/payment-record", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/pricing-policy-proposals", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/pricing-policy-proposals", "AUDITOR"));
        assertFalse(policy.isAllowed("POST", "/api/admin/billing/pricing-policy-proposals/123/approve", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-preview/export.csv", "AUDITOR"));
        assertFalse(policy.isAllowed("GET", "/api/admin/billing/chargeback-invoice-draft/export.csv", "AUDITOR"));
        assertFalse(policy.isAllowed("DELETE", "/api/admin/organizations/1", "AUDITOR"));
    }

    @Test
    void nonAdminRolesCannotAccessAdminRoutes() {
        assertFalse(policy.isAllowed("GET", "/api/admin/users", "USER"));
        assertFalse(policy.isAllowed("GET", "/api/admin/users", "DEVELOPER"));
        assertFalse(policy.isAllowed("GET", "/api/admin/users", ""));
        assertFalse(policy.isAllowed("GET", "/api/admin/users", null));
    }
}
