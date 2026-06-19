package com.example.osmu.billing;

import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/billing")
public class AdminBillingController {

    private final ChargebackPreviewService chargebackPreviewService;
    private final AuthContext authContext;

    public AdminBillingController(ChargebackPreviewService chargebackPreviewService, AuthContext authContext) {
        this.chargebackPreviewService = chargebackPreviewService;
        this.authContext = authContext;
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
        return ApiResponse.of(chargebackPreviewService.preview(actor, new ChargebackPreviewRequest(
                parseOptionalOffsetDateTime(from, "from"),
                parseOptionalOffsetDateTime(to, "to"),
                currency,
                storageGbMonthRate,
                ingressGbRate,
                egressGbRate,
                internalGbRate,
                operationThousandRate,
                eventScanLimit == null ? 0 : eventScanLimit
        )));
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
