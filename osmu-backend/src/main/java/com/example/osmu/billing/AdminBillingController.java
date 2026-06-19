package com.example.osmu.billing;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/billing")
public class AdminBillingController {

    private final ChargebackPreviewService chargebackPreviewService;
    private final BillingPricingPolicyService pricingPolicyService;
    private final AuditLogService auditLogService;
    private final AuthContext authContext;

    public AdminBillingController(
            ChargebackPreviewService chargebackPreviewService,
            BillingPricingPolicyService pricingPolicyService,
            AuditLogService auditLogService,
            AuthContext authContext
    ) {
        this.chargebackPreviewService = chargebackPreviewService;
        this.pricingPolicyService = pricingPolicyService;
        this.auditLogService = auditLogService;
        this.authContext = authContext;
    }

    @GetMapping("/pricing-policy")
    public ApiResponse<BillingPricingPolicy> pricingPolicy() {
        return ApiResponse.of(pricingPolicyService.current());
    }

    @PutMapping("/pricing-policy")
    public ApiResponse<BillingPricingPolicy> savePricingPolicy(
            @RequestBody BillingPricingPolicyRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser actor = authContext.currentUser(httpRequest);
        BillingPricingPolicy saved = pricingPolicyService.save(request);
        auditLogService.record(
                "BILLING_PRICING_POLICY_SAVE",
                actor.loginId(),
                "BILLING_PRICING_POLICY",
                "global",
                "SUCCESS",
                request == null || request.reason() == null || request.reason().isBlank()
                        ? "Billing pricing policy saved"
                        : request.reason().trim(),
                httpRequest
        );
        return ApiResponse.of(saved);
    }

    @PostMapping("/pricing-policy-proposals")
    public ApiResponse<BillingPricingPolicyProposalCreateResponse> createPricingPolicyProposal(
            @RequestBody BillingPricingPolicyRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser actor = authContext.currentUser(httpRequest);
        BillingPricingPolicyProposalCreateResponse created = pricingPolicyService.createProposal(request, actor.loginId());
        auditLogService.record(
                "BILLING_PRICING_POLICY_PROPOSAL_CREATE",
                actor.loginId(),
                "BILLING_PRICING_POLICY_PROPOSAL",
                String.valueOf(created.proposal().id()),
                "SUCCESS",
                request == null || request.reason() == null || request.reason().isBlank()
                        ? "Billing pricing policy proposal created"
                        : request.reason().trim(),
                httpRequest
        );
        return ApiResponse.of(created);
    }

    @GetMapping("/pricing-policy-proposals")
    public ApiResponse<BillingPricingPolicyProposalListResponse> pricingPolicyProposals(
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        return ApiResponse.of(pricingPolicyService.proposals(status, limit == null ? 50 : limit));
    }

    @PostMapping("/pricing-policy-proposals/{proposalId}/approve")
    public ApiResponse<BillingPricingPolicyProposalApprovalResponse> approvePricingPolicyProposal(
            @PathVariable long proposalId,
            @RequestParam(name = "approvalNote", required = false) String approvalNote,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser actor = authContext.currentUser(httpRequest);
        BillingPricingPolicyProposalApprovalResponse approved =
                pricingPolicyService.approveProposal(proposalId, actor.loginId(), approvalNote);
        auditLogService.record(
                "BILLING_PRICING_POLICY_PROPOSAL_APPROVE",
                actor.loginId(),
                "BILLING_PRICING_POLICY_PROPOSAL",
                String.valueOf(proposalId),
                "SUCCESS",
                approvalNote == null || approvalNote.isBlank()
                        ? "Billing pricing policy proposal approved"
                        : approvalNote.trim(),
                httpRequest
        );
        return ApiResponse.of(approved);
    }

    @GetMapping("/chargeback-preview")
    public ApiResponse<ChargebackPreviewResponse> chargebackPreview(
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "currency", required = false) String currency,
            @RequestParam(name = "storageGbMonthRate", required = false) BigDecimal storageGbMonthRate,
            @RequestParam(name = "ingressGbRate", required = false) BigDecimal ingressGbRate,
            @RequestParam(name = "egressGbRate", required = false) BigDecimal egressGbRate,
            @RequestParam(name = "internalGbRate", required = false) BigDecimal internalGbRate,
            @RequestParam(name = "operationThousandRate", required = false) BigDecimal operationThousandRate,
            @RequestParam(name = "eventScanLimit", required = false) Integer eventScanLimit,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        return ApiResponse.of(chargebackPreviewService.preview(actor, chargebackRequest(
                from,
                to,
                currency,
                storageGbMonthRate,
                ingressGbRate,
                egressGbRate,
                internalGbRate,
                operationThousandRate,
                eventScanLimit
        )));
    }

    @GetMapping("/chargeback-alerts")
    public ApiResponse<ChargebackAlertResponse> chargebackAlerts(
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "currency", required = false) String currency,
            @RequestParam(name = "storageGbMonthRate", required = false) BigDecimal storageGbMonthRate,
            @RequestParam(name = "ingressGbRate", required = false) BigDecimal ingressGbRate,
            @RequestParam(name = "egressGbRate", required = false) BigDecimal egressGbRate,
            @RequestParam(name = "internalGbRate", required = false) BigDecimal internalGbRate,
            @RequestParam(name = "operationThousandRate", required = false) BigDecimal operationThousandRate,
            @RequestParam(name = "eventScanLimit", required = false) Integer eventScanLimit,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        return ApiResponse.of(chargebackPreviewService.alerts(actor, chargebackRequest(
                from,
                to,
                currency,
                storageGbMonthRate,
                ingressGbRate,
                egressGbRate,
                internalGbRate,
                operationThousandRate,
                eventScanLimit
        )));
    }

    @GetMapping("/chargeback-alert-notifications/preview")
    public ApiResponse<ChargebackAlertNotificationPreviewResponse> chargebackAlertNotificationPreview(
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "currency", required = false) String currency,
            @RequestParam(name = "storageGbMonthRate", required = false) BigDecimal storageGbMonthRate,
            @RequestParam(name = "ingressGbRate", required = false) BigDecimal ingressGbRate,
            @RequestParam(name = "egressGbRate", required = false) BigDecimal egressGbRate,
            @RequestParam(name = "internalGbRate", required = false) BigDecimal internalGbRate,
            @RequestParam(name = "operationThousandRate", required = false) BigDecimal operationThousandRate,
            @RequestParam(name = "eventScanLimit", required = false) Integer eventScanLimit,
            @RequestParam(name = "notificationChannel", required = false) String notificationChannel,
            @RequestParam(name = "notificationTarget", required = false) String notificationTarget,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        return ApiResponse.of(chargebackPreviewService.alertNotificationPreview(actor, chargebackRequest(
                from,
                to,
                currency,
                storageGbMonthRate,
                ingressGbRate,
                egressGbRate,
                internalGbRate,
                operationThousandRate,
                eventScanLimit
        ), notificationChannel, notificationTarget));
    }

    @PostMapping("/chargeback-alert-notifications/outbox")
    public ApiResponse<ChargebackAlertNotificationDispatchResponse> queueChargebackAlertNotifications(
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "currency", required = false) String currency,
            @RequestParam(name = "storageGbMonthRate", required = false) BigDecimal storageGbMonthRate,
            @RequestParam(name = "ingressGbRate", required = false) BigDecimal ingressGbRate,
            @RequestParam(name = "egressGbRate", required = false) BigDecimal egressGbRate,
            @RequestParam(name = "internalGbRate", required = false) BigDecimal internalGbRate,
            @RequestParam(name = "operationThousandRate", required = false) BigDecimal operationThousandRate,
            @RequestParam(name = "eventScanLimit", required = false) Integer eventScanLimit,
            @RequestParam(name = "notificationChannel", required = false) String notificationChannel,
            @RequestParam(name = "notificationTarget", required = false) String notificationTarget,
            @RequestParam(name = "reason", required = false) String reason,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        return ApiResponse.of(chargebackPreviewService.queueAlertNotifications(actor, chargebackRequest(
                from,
                to,
                currency,
                storageGbMonthRate,
                ingressGbRate,
                egressGbRate,
                internalGbRate,
                operationThousandRate,
                eventScanLimit
        ), notificationChannel, notificationTarget, reason));
    }

    @GetMapping("/chargeback-alert-notifications/outbox")
    public ApiResponse<ChargebackAlertNotificationOutboxResponse> chargebackAlertNotificationOutbox(
            @RequestParam(name = "limit", required = false) Integer limit,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        return ApiResponse.of(chargebackPreviewService.notificationOutbox(actor, limit == null ? 50 : limit));
    }

    @PostMapping("/chargeback-invoice-drafts")
    public ApiResponse<ChargebackInvoiceDraftCreateResponse> persistChargebackInvoiceDrafts(
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "currency", required = false) String currency,
            @RequestParam(name = "storageGbMonthRate", required = false) BigDecimal storageGbMonthRate,
            @RequestParam(name = "ingressGbRate", required = false) BigDecimal ingressGbRate,
            @RequestParam(name = "egressGbRate", required = false) BigDecimal egressGbRate,
            @RequestParam(name = "internalGbRate", required = false) BigDecimal internalGbRate,
            @RequestParam(name = "operationThousandRate", required = false) BigDecimal operationThousandRate,
            @RequestParam(name = "eventScanLimit", required = false) Integer eventScanLimit,
            @RequestParam(name = "reason", required = false) String reason,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        return ApiResponse.of(chargebackPreviewService.persistInvoiceDrafts(actor, chargebackRequest(
                from,
                to,
                currency,
                storageGbMonthRate,
                ingressGbRate,
                egressGbRate,
                internalGbRate,
                operationThousandRate,
                eventScanLimit
        ), reason));
    }

    @GetMapping("/chargeback-invoice-drafts")
    public ApiResponse<ChargebackInvoiceDraftListResponse> chargebackInvoiceDrafts(
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "limit", required = false) Integer limit,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        return ApiResponse.of(chargebackPreviewService.invoiceDrafts(actor, status, limit == null ? 50 : limit));
    }

    @PostMapping("/chargeback-invoice-drafts/{invoiceId}/approve")
    public ApiResponse<ChargebackInvoiceDraftApprovalResponse> approveChargebackInvoiceDraft(
            @PathVariable long invoiceId,
            @RequestParam(name = "approvalNote", required = false) String approvalNote,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        ChargebackInvoiceDraftApprovalResponse approved =
                chargebackPreviewService.approveInvoiceDraft(actor, invoiceId, approvalNote);
        auditLogService.record(
                "CHARGEBACK_INVOICE_DRAFT_APPROVE",
                actor.loginId(),
                "CHARGEBACK_INVOICE_DRAFT",
                String.valueOf(invoiceId),
                "SUCCESS",
                approvalNote == null || approvalNote.isBlank()
                        ? "Chargeback invoice draft approved"
                        : approvalNote.trim(),
                request
        );
        return ApiResponse.of(approved);
    }

    @PostMapping("/chargeback-invoice-drafts/{invoiceId}/finalize")
    public ApiResponse<ChargebackFinalInvoiceActionResponse> finalizeChargebackInvoiceDraft(
            @PathVariable long invoiceId,
            @RequestParam(name = "finalizationNote", required = false) String finalizationNote,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        ChargebackFinalInvoiceActionResponse finalized =
                chargebackPreviewService.finalizeInvoiceDraft(actor, invoiceId, finalizationNote);
        auditLogService.record(
                "CHARGEBACK_FINAL_INVOICE_CREATE",
                actor.loginId(),
                "CHARGEBACK_INVOICE_DRAFT",
                String.valueOf(invoiceId),
                "SUCCESS",
                finalizationNote == null || finalizationNote.isBlank()
                        ? "Chargeback final invoice created"
                        : finalizationNote.trim(),
                request
        );
        return ApiResponse.of(finalized);
    }

    @GetMapping("/chargeback-invoices")
    public ApiResponse<ChargebackFinalInvoiceListResponse> chargebackFinalInvoices(
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "limit", required = false) Integer limit,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        return ApiResponse.of(chargebackPreviewService.finalInvoices(actor, status, limit == null ? 50 : limit));
    }

    @PostMapping("/chargeback-invoices/{invoiceId}/payment-request")
    public ApiResponse<ChargebackFinalInvoiceActionResponse> requestChargebackInvoicePayment(
            @PathVariable long invoiceId,
            @RequestParam(name = "paymentRequestNote", required = false) String paymentRequestNote,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        ChargebackFinalInvoiceActionResponse payment =
                chargebackPreviewService.requestFinalInvoicePayment(actor, invoiceId, paymentRequestNote);
        auditLogService.record(
                "CHARGEBACK_FINAL_INVOICE_PAYMENT_REQUEST",
                actor.loginId(),
                "CHARGEBACK_FINAL_INVOICE",
                String.valueOf(invoiceId),
                "SUCCESS",
                paymentRequestNote == null || paymentRequestNote.isBlank()
                        ? "Chargeback final invoice payment requested"
                        : paymentRequestNote.trim(),
                request
        );
        return ApiResponse.of(payment);
    }

    @PostMapping("/chargeback-invoices/{invoiceId}/payment-record")
    public ApiResponse<ChargebackFinalInvoiceActionResponse> recordChargebackInvoicePayment(
            @PathVariable long invoiceId,
            @RequestParam(name = "paymentReference") String paymentReference,
            @RequestParam(name = "paymentNote", required = false) String paymentNote,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        ChargebackFinalInvoiceActionResponse paid =
                chargebackPreviewService.recordFinalInvoicePayment(actor, invoiceId, paymentReference, paymentNote);
        auditLogService.record(
                "CHARGEBACK_FINAL_INVOICE_PAYMENT_RECORD",
                actor.loginId(),
                "CHARGEBACK_FINAL_INVOICE",
                String.valueOf(invoiceId),
                "SUCCESS",
                paymentReference,
                request
        );
        return ApiResponse.of(paid);
    }

    @GetMapping(value = "/chargeback-preview/export.csv", produces = "text/csv")
    public ResponseEntity<String> exportChargebackPreviewCsv(
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "currency", required = false) String currency,
            @RequestParam(name = "storageGbMonthRate", required = false) BigDecimal storageGbMonthRate,
            @RequestParam(name = "ingressGbRate", required = false) BigDecimal ingressGbRate,
            @RequestParam(name = "egressGbRate", required = false) BigDecimal egressGbRate,
            @RequestParam(name = "internalGbRate", required = false) BigDecimal internalGbRate,
            @RequestParam(name = "operationThousandRate", required = false) BigDecimal operationThousandRate,
            @RequestParam(name = "eventScanLimit", required = false) Integer eventScanLimit,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        String csv = chargebackPreviewService.exportCsv(actor, chargebackRequest(
                from,
                to,
                currency,
                storageGbMonthRate,
                ingressGbRate,
                egressGbRate,
                internalGbRate,
                operationThousandRate,
                eventScanLimit
        ));
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/csv"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-chargeback-preview.csv\"")
                .body(csv);
    }

    @GetMapping(value = "/chargeback-invoice-draft/export.csv", produces = "text/csv")
    public ResponseEntity<String> exportChargebackInvoiceDraftCsv(
            @RequestParam(name = "from", required = false) String from,
            @RequestParam(name = "to", required = false) String to,
            @RequestParam(name = "currency", required = false) String currency,
            @RequestParam(name = "storageGbMonthRate", required = false) BigDecimal storageGbMonthRate,
            @RequestParam(name = "ingressGbRate", required = false) BigDecimal ingressGbRate,
            @RequestParam(name = "egressGbRate", required = false) BigDecimal egressGbRate,
            @RequestParam(name = "internalGbRate", required = false) BigDecimal internalGbRate,
            @RequestParam(name = "operationThousandRate", required = false) BigDecimal operationThousandRate,
            @RequestParam(name = "eventScanLimit", required = false) Integer eventScanLimit,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        String csv = chargebackPreviewService.exportInvoiceDraftCsv(actor, chargebackRequest(
                from,
                to,
                currency,
                storageGbMonthRate,
                ingressGbRate,
                egressGbRate,
                internalGbRate,
                operationThousandRate,
                eventScanLimit
        ));
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/csv"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-chargeback-invoice-draft.csv\"")
                .body(csv);
    }

    private ChargebackPreviewRequest chargebackRequest(
            String from,
            String to,
            String currency,
            BigDecimal storageGbMonthRate,
            BigDecimal ingressGbRate,
            BigDecimal egressGbRate,
            BigDecimal internalGbRate,
            BigDecimal operationThousandRate,
            Integer eventScanLimit
    ) {
        return new ChargebackPreviewRequest(
                parseOptionalOffsetDateTime(from, "from"),
                parseOptionalOffsetDateTime(to, "to"),
                currency,
                storageGbMonthRate,
                ingressGbRate,
                egressGbRate,
                internalGbRate,
                operationThousandRate,
                eventScanLimit == null ? 0 : eventScanLimit
        );
    }

    private OffsetDateTime parseOptionalOffsetDateTime(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return OffsetDateTime.parse(value.trim());
        } catch (DateTimeParseException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must be an ISO-8601 offset datetime.");
        }
    }
}
