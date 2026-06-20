package com.example.osmu.billing;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class AdminBillingControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanPreviewChargebackFromOrganizationUsageAndDataFlow() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int organizationId = createOrganization(adminToken, "Billing Org 1");
        createOrganizationBucket(adminToken, organizationId, "billing-org-bucket-1");

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "billing.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "billing-data".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "billing-org-bucket-1")
                        .file(file)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("key", "billing.txt"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/admin/billing/chargeback-preview")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("storageGbMonthRate", "1073741824")
                        .param("ingressGbRate", "1073741824")
                        .param("operationThousandRate", "1000")
                        .param("currency", "krw"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.currency").value("KRW"))
                .andExpect(jsonPath("$.data.organizations[?(@.organizationName == 'Billing Org 1')].usedBytes", hasItem(12)))
                .andExpect(jsonPath("$.data.organizations[?(@.organizationName == 'Billing Org 1')].ingressBytes", hasItem(12)))
                .andExpect(jsonPath("$.data.organizations[?(@.organizationName == 'Billing Org 1')].billableOperationCount", hasItem(1)))
                .andExpect(jsonPath("$.data.organizations[?(@.organizationName == 'Billing Org 1')].estimatedTotalCost", hasItem(25.0)));
    }

    @Test
    void adminCanSavePricingPolicyAndPreviewUsesStoredRates() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int organizationId = createOrganization(adminToken, "Billing Policy Org 1");
        createOrganizationBucket(adminToken, organizationId, "billing-policy-bucket-1");

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "billing-policy.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "billing-data".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "billing-policy-bucket-1")
                        .file(file)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("key", "billing-policy.txt"))
                .andExpect(status().isOk());

        mockMvc.perform(put("/api/admin/billing/pricing-policy")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "currency": "krw",
                                  "storageGbMonthRate": 1073741824,
                                  "ingressGbRate": 1073741824,
                                  "operationThousandRate": 1000,
                                  "warningAmount": 20,
                                  "criticalAmount": 25,
                                  "eventScanLimit": 5000,
                                  "reason": "billing policy test"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.currency").value("KRW"))
                .andExpect(jsonPath("$.data.warningAmount").value(20.0))
                .andExpect(jsonPath("$.data.criticalAmount").value(25.0))
                .andExpect(jsonPath("$.data.eventScanLimit").value(5000))
                .andExpect(jsonPath("$.data.updatedAt").exists());

        String pricingPolicyProposalResponse = mockMvc.perform(post("/api/admin/billing/pricing-policy-proposals")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "currency": "krw",
                                  "storageGbMonthRate": 1073741824,
                                  "ingressGbRate": 1073741824,
                                  "operationThousandRate": 1000,
                                  "warningAmount": 20,
                                  "criticalAmount": 25,
                                  "eventScanLimit": 5000,
                                  "reason": "billing policy proposal test"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PENDING_APPROVAL"))
                .andExpect(jsonPath("$.data.approvedPriceList").value(false))
                .andExpect(jsonPath("$.data.proposal.status").value("PENDING_APPROVAL"))
                .andExpect(jsonPath("$.data.proposal.requestedBy").value("admin"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        Integer pricingPolicyProposalId = JsonPath.read(pricingPolicyProposalResponse, "$.data.proposal.id");

        mockMvc.perform(get("/api/admin/billing/pricing-policy-proposals")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("status", "PENDING_APPROVAL")
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.proposals[*].id", hasItem(pricingPolicyProposalId)));

        mockMvc.perform(post("/api/admin/billing/pricing-policy-proposals/{proposalId}/approve", pricingPolicyProposalId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("approvalNote", "approved for internal chargeback policy"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED_APPLIED"))
                .andExpect(jsonPath("$.data.approvedPriceList").value(false))
                .andExpect(jsonPath("$.data.proposal.status").value("APPROVED_APPLIED"))
                .andExpect(jsonPath("$.data.proposal.approvedBy").value("admin"))
                .andExpect(jsonPath("$.data.appliedPolicy.currency").value("KRW"))
                .andExpect(jsonPath("$.data.appliedPolicy.eventScanLimit").value(5000));

        mockMvc.perform(get("/api/admin/billing/pricing-policy-proposals")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("status", "APPROVED_APPLIED")
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.proposals[*].id", hasItem(pricingPolicyProposalId)));

        mockMvc.perform(get("/api/admin/billing/chargeback-preview")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.currency").value("KRW"))
                .andExpect(jsonPath("$.data.eventScanLimit").value(5000))
                .andExpect(jsonPath("$.data.organizations[?(@.organizationName == 'Billing Policy Org 1')].estimatedTotalCost", hasItem(25.0)));

        mockMvc.perform(get("/api/admin/billing/chargeback-alerts")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.currency").value("KRW"))
                .andExpect(jsonPath("$.data.warningAmount").value(20.0))
                .andExpect(jsonPath("$.data.criticalAmount").value(25.0))
                .andExpect(jsonPath("$.data.alertCount").value(1))
                .andExpect(jsonPath("$.data.criticalCount").value(1))
                .andExpect(jsonPath("$.data.organizations[0].organizationName").value("Billing Policy Org 1"))
                .andExpect(jsonPath("$.data.organizations[0].severity").value("CRITICAL"));

        mockMvc.perform(get("/api/admin/billing/chargeback-alert-notifications/preview")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("notificationChannel", "slack")
                        .param("notificationTarget", "ops-webhook"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("PREVIEW"))
                .andExpect(jsonPath("$.data.channel").value("SLACK"))
                .andExpect(jsonPath("$.data.target").value("ops-webhook"))
                .andExpect(jsonPath("$.data.externalDeliveryEnabled").value(false))
                .andExpect(jsonPath("$.data.notificationCount").value(1))
                .andExpect(jsonPath("$.data.notifications[0].organizationName").value("Billing Policy Org 1"))
                .andExpect(jsonPath("$.data.notifications[0].severity").value("CRITICAL"))
                .andExpect(jsonPath("$.data.notifications[0].subject", containsString("CRITICAL chargeback alert")))
                .andExpect(jsonPath("$.data.notifications[0].payload.eventType").value("chargeback.threshold"));

        String queuedNotificationResponse = mockMvc.perform(post("/api/admin/billing/chargeback-alert-notifications/outbox")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("notificationChannel", "slack")
                        .param("notificationTarget", "ops-webhook")
                        .param("reason", "billing notification test"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("OUTBOX"))
                .andExpect(jsonPath("$.data.status").value("PENDING_DELIVERY_ADAPTER"))
                .andExpect(jsonPath("$.data.externalDeliveryEnabled").value(false))
                .andExpect(jsonPath("$.data.queuedCount").value(1))
                .andExpect(jsonPath("$.data.deliveries[0].organizationName").value("Billing Policy Org 1"))
                .andExpect(jsonPath("$.data.deliveries[0].payloadJson", containsString("chargeback.threshold")))
                .andReturn()
                .getResponse()
                .getContentAsString();

        Integer deliveryId = JsonPath.read(queuedNotificationResponse, "$.data.deliveries[0].id");

        mockMvc.perform(post("/api/admin/billing/chargeback-alert-notifications/outbox/{deliveryId}/adapter-result", deliveryId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("result", "BLOCKED_CREDENTIAL"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("ADAPTER_RESULT"))
                .andExpect(jsonPath("$.data.status").value("DELIVERY_ADAPTER_BLOCKED_CREDENTIAL"))
                .andExpect(jsonPath("$.data.externalDeliveryEnabled").value(false))
                .andExpect(jsonPath("$.data.delivery.attemptCount").value(1))
                .andExpect(jsonPath("$.data.delivery.lastError", containsString("credential/configuration")));

        mockMvc.perform(get("/api/admin/billing/chargeback-alert-notifications/outbox")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deliveries[*].organizationName", hasItem("Billing Policy Org 1")));

        String invoiceDraftResponse = mockMvc.perform(post("/api/admin/billing/chargeback-invoice-drafts")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("reason", "billing invoice draft test"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DRAFT_REVIEW"))
                .andExpect(jsonPath("$.data.status").value("DRAFT_REVIEW"))
                .andExpect(jsonPath("$.data.finalInvoice").value(false))
                .andExpect(jsonPath("$.data.paymentRequest").value(false))
                .andExpect(jsonPath("$.data.persistedCount").value(1))
                .andExpect(jsonPath("$.data.invoices[0].organizationName").value("Billing Policy Org 1"))
                .andExpect(jsonPath("$.data.invoices[0].status").value("DRAFT_REVIEW"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        Integer invoiceId = JsonPath.read(invoiceDraftResponse, "$.data.invoices[0].id");

        mockMvc.perform(get("/api/admin/billing/chargeback-invoice-drafts")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("status", "DRAFT_REVIEW")
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.invoices[*].organizationName", hasItem("Billing Policy Org 1")));

        mockMvc.perform(post("/api/admin/billing/chargeback-invoice-drafts/{invoiceId}/approve", invoiceId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("approvalNote", "approved for internal review"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED_INTERNAL"))
                .andExpect(jsonPath("$.data.finalInvoice").value(false))
                .andExpect(jsonPath("$.data.paymentRequest").value(false))
                .andExpect(jsonPath("$.data.invoice.approvedBy").value("admin"));

        String finalInvoiceResponse = mockMvc.perform(post("/api/admin/billing/chargeback-invoice-drafts/{invoiceId}/finalize", invoiceId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("finalizationNote", "finalize pilot invoice"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("FINAL_INVOICE"))
                .andExpect(jsonPath("$.data.status").value("FINALIZED"))
                .andExpect(jsonPath("$.data.paymentStatus").value("NOT_REQUESTED"))
                .andExpect(jsonPath("$.data.finalInvoice").value(true))
                .andExpect(jsonPath("$.data.paymentRequest").value(false))
                .andExpect(jsonPath("$.data.invoice.invoiceNumber", containsString("OSMU-FINAL-")))
                .andExpect(jsonPath("$.data.invoice.sourceDraftId").value(invoiceId))
                .andExpect(jsonPath("$.data.invoice.finalizedBy").value("admin"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        Integer finalInvoiceId = JsonPath.read(finalInvoiceResponse, "$.data.invoice.id");

        mockMvc.perform(get("/api/admin/billing/chargeback-invoices")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("status", "FINALIZED")
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.invoices[*].id", hasItem(finalInvoiceId)));

        mockMvc.perform(post("/api/admin/billing/chargeback-invoices/{invoiceId}/payment-request", finalInvoiceId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("paymentRequestNote", "send payment request"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("PAYMENT_REQUEST"))
                .andExpect(jsonPath("$.data.status").value("PAYMENT_REQUESTED"))
                .andExpect(jsonPath("$.data.paymentStatus").value("REQUESTED"))
                .andExpect(jsonPath("$.data.paymentRequest").value(true))
                .andExpect(jsonPath("$.data.invoice.paymentRequestedBy").value("admin"));

        mockMvc.perform(get("/api/admin/billing/chargeback-invoices/{invoiceId}/payment-provider-handoff/preview", finalInvoiceId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("paymentProvider", "manual_ap")
                        .param("paymentTargetAccount", "finance-ap"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("PREVIEW"))
                .andExpect(jsonPath("$.data.provider").value("MANUAL_AP"))
                .andExpect(jsonPath("$.data.targetAccount").value("finance-ap"))
                .andExpect(jsonPath("$.data.externalPaymentEnabled").value(false))
                .andExpect(jsonPath("$.data.invoice.id").value(finalInvoiceId))
                .andExpect(jsonPath("$.data.payload.eventType").value("chargeback.payment_provider.handoff"));

        String queuedHandoffResponse = mockMvc.perform(post("/api/admin/billing/chargeback-invoices/{invoiceId}/payment-provider-handoff", finalInvoiceId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("paymentProvider", "manual_ap")
                        .param("paymentTargetAccount", "finance-ap")
                        .param("reason", "billing payment handoff test"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("OUTBOX"))
                .andExpect(jsonPath("$.data.status").value("PENDING_PAYMENT_PROVIDER_ADAPTER"))
                .andExpect(jsonPath("$.data.externalPaymentEnabled").value(false))
                .andExpect(jsonPath("$.data.handoff.invoiceNumber", containsString("OSMU-FINAL-")))
                .andExpect(jsonPath("$.data.handoff.payloadJson", containsString("chargeback.payment_provider.handoff")))
                .andReturn()
                .getResponse()
                .getContentAsString();

        Integer handoffId = JsonPath.read(queuedHandoffResponse, "$.data.handoff.id");

        mockMvc.perform(post("/api/admin/billing/chargeback-payment-provider-handoffs/{handoffId}/adapter-result", handoffId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("result", "RETRY")
                        .param("retryDelayMinutes", "45")
                        .param("lastError", "Payment adapter configuration pending."))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("ADAPTER_RESULT"))
                .andExpect(jsonPath("$.data.status").value("PAYMENT_PROVIDER_ADAPTER_RETRY_SCHEDULED"))
                .andExpect(jsonPath("$.data.externalPaymentEnabled").value(false))
                .andExpect(jsonPath("$.data.handoff.attemptCount").value(1))
                .andExpect(jsonPath("$.data.handoff.nextAttemptAt").exists());

        mockMvc.perform(get("/api/admin/billing/chargeback-payment-provider-handoffs")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("status", "PAYMENT_PROVIDER_ADAPTER_RETRY_SCHEDULED")
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.handoffs[*].invoiceNumber", hasItem(containsString("OSMU-FINAL-"))));

        mockMvc.perform(post("/api/admin/billing/chargeback-invoices/{invoiceId}/payment-record", finalInvoiceId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("paymentReference", "PAY-2026-0001")
                        .param("paymentNote", "manual payment confirmed"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("PAYMENT_RECORD"))
                .andExpect(jsonPath("$.data.status").value("PAID"))
                .andExpect(jsonPath("$.data.paymentStatus").value("PAID"))
                .andExpect(jsonPath("$.data.invoice.paymentRecordedBy").value("admin"))
                .andExpect(jsonPath("$.data.invoice.paymentReference").value("PAY-2026-0001"));
    }

    @Test
    void adminCanExportChargebackPreviewCsv() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int organizationId = createOrganization(adminToken, "Billing Export Org 1");
        createOrganizationBucket(adminToken, organizationId, "billing-export-bucket-1");

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "billing-export.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "billing-data".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "billing-export-bucket-1")
                        .file(file)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("key", "billing-export.txt"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/admin/billing/chargeback-preview/export.csv")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("storageGbMonthRate", "1073741824")
                        .param("ingressGbRate", "1073741824")
                        .param("operationThousandRate", "1000")
                        .param("currency", "krw"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-chargeback-preview.csv\""))
                .andExpect(content().string(containsString("rowType,currency,from,to,generatedAt,eventScanLimit,scannedEventCount")))
                .andExpect(content().string(containsString("\"TOTAL\",\"KRW\"")))
                .andExpect(content().string(containsString("\"ORGANIZATION\",\"KRW\"")))
                .andExpect(content().string(containsString("\"Billing Export Org 1\"")))
                .andExpect(content().string(containsString("\"25.000000\"")));

        mockMvc.perform(get("/api/admin/billing/chargeback-invoice-draft/export.csv")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("storageGbMonthRate", "1073741824")
                        .param("ingressGbRate", "1073741824")
                        .param("operationThousandRate", "1000")
                        .param("currency", "krw"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-chargeback-invoice-draft.csv\""))
                .andExpect(content().string(containsString("rowType,invoiceNumber,invoiceStatus,currency")))
                .andExpect(content().string(containsString("\"DRAFT_INVOICE\"")))
                .andExpect(content().string(containsString("\"DRAFT\"")))
                .andExpect(content().string(containsString("\"OSMU-DRAFT-")))
                .andExpect(content().string(containsString("\"Billing Export Org 1\"")))
                .andExpect(content().string(containsString("\"25.000000\"")))
                .andExpect(content().string(containsString("Preview only - not a final invoice")));
    }

    @Test
    void orgAdminSeesOnlyOwnChargebackPreview() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int visibleOrg = createOrganization(adminToken, "Billing Visible Org 1");
        int hiddenOrg = createOrganization(adminToken, "Billing Hidden Org 1");
        createOrganizationBucket(adminToken, visibleOrg, "billing-visible-bucket-1");
        createOrganizationBucket(adminToken, hiddenOrg, "billing-hidden-bucket-1");
        uploadTextObject(adminToken, "billing-visible-bucket-1", "visible-billing.txt");
        uploadTextObject(adminToken, "billing-hidden-bucket-1", "hidden-billing.txt");
        mockMvc.perform(put("/api/admin/billing/pricing-policy")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "currency": "krw",
                                  "storageGbMonthRate": 1073741824,
                                  "ingressGbRate": 1073741824,
                                  "operationThousandRate": 1000,
                                  "warningAmount": 20,
                                  "criticalAmount": 25,
                                  "eventScanLimit": 5000,
                                  "reason": "billing scope test"
                                }
                                """))
                .andExpect(status().isOk());
        createUser(adminToken, "billing-org-admin-1", "billing-org-admin-1@example.com", "ORG_ADMIN", visibleOrg);
        String orgAdminToken = loginAndReturnAccessToken("billing-org-admin-1", "user-password");

        mockMvc.perform(get("/api/admin/billing/chargeback-preview")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.organizations[*].organizationName", hasItem("Billing Visible Org 1")))
                .andExpect(jsonPath("$.data.organizations[*].organizationName", not(hasItem("Billing Hidden Org 1"))));

        mockMvc.perform(get("/api/admin/billing/chargeback-preview/export.csv")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Billing Visible Org 1")))
                .andExpect(content().string(not(containsString("Billing Hidden Org 1"))));

        mockMvc.perform(get("/api/admin/billing/chargeback-invoice-draft/export.csv")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Billing Visible Org 1")))
                .andExpect(content().string(not(containsString("Billing Hidden Org 1"))));

        mockMvc.perform(get("/api/admin/billing/chargeback-alerts")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.organizations[*].organizationName", hasItem("Billing Visible Org 1")))
                .andExpect(jsonPath("$.data.organizations[*].organizationName", not(hasItem("Billing Hidden Org 1"))));

        mockMvc.perform(get("/api/admin/billing/chargeback-alert-notifications/preview")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.notifications[*].organizationName", hasItem("Billing Visible Org 1")))
                .andExpect(jsonPath("$.data.notifications[*].organizationName", not(hasItem("Billing Hidden Org 1"))));

        mockMvc.perform(post("/api/admin/billing/chargeback-alert-notifications/outbox")
                        .header("Authorization", "Bearer " + orgAdminToken)
                        .param("notificationChannel", "webhook")
                        .param("notificationTarget", "org-webhook"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deliveries[*].organizationName", hasItem("Billing Visible Org 1")))
                .andExpect(jsonPath("$.data.deliveries[*].organizationName", not(hasItem("Billing Hidden Org 1"))));

        mockMvc.perform(get("/api/admin/billing/chargeback-alert-notifications/outbox")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deliveries[*].organizationName", hasItem("Billing Visible Org 1")))
                .andExpect(jsonPath("$.data.deliveries[*].organizationName", not(hasItem("Billing Hidden Org 1"))));
    }

    private String loginAndReturnAccessToken(String loginId, String password) throws Exception {
        String response = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "password": "%s"
                                }
                                """.formatted(loginId, password)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(response, "$.data.accessToken");
    }

    private int createOrganization(String adminToken, String name) throws Exception {
        String response = mockMvc.perform(post("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "description": "billing test",
                                  "defaultQuotaBytes": 2048
                                }
                                """.formatted(name)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(response, "$.data.id");
    }

    private void createOrganizationBucket(String adminToken, int organizationId, String bucketName) throws Exception {
        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "quotaBytes": 1024,
                                  "ownerType": "ORG",
                                  "ownerId": %d
                                }
                                """.formatted(bucketName, organizationId)))
                .andExpect(status().isOk());
    }

    private void uploadTextObject(String token, String bucketName, String key) throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                key,
                MediaType.TEXT_PLAIN_VALUE,
                "billing-data".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", bucketName)
                        .file(file)
                        .header("Authorization", "Bearer " + token)
                        .param("key", key))
                .andExpect(status().isOk());
    }

    private void createUser(String adminToken, String loginId, String email, String role, int organizationId) throws Exception {
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s",
                                  "name": "%s",
                                  "password": "user-password",
                                  "role": "%s",
                                  "organizationId": %d
                                }
                                """.formatted(loginId, email, loginId, role, organizationId)))
                .andExpect(status().isOk());
    }
}
