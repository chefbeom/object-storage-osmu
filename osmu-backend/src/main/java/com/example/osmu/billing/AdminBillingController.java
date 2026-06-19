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
