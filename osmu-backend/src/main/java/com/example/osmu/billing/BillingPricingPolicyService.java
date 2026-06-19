package com.example.osmu.billing;

import com.example.osmu.billing.repository.BillingPricingPolicyRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.Locale;
import org.springframework.stereotype.Service;

@Service
public class BillingPricingPolicyService {

    public static final int DEFAULT_EVENT_SCAN_LIMIT = 10_000;
    public static final int MAX_EVENT_SCAN_LIMIT = 50_000;

    private final BillingPricingPolicyRepository repository;

    public BillingPricingPolicyService(BillingPricingPolicyRepository repository) {
        this.repository = repository;
    }

    public BillingPricingPolicy current() {
        return repository.get();
    }

    public BillingPricingPolicy save(BillingPricingPolicyRequest request) {
        if (request == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Billing pricing policy request is required.");
        }
        BillingPricingPolicy current = repository.get();
        BillingPricingPolicy next = new BillingPricingPolicy(
                normalizeCurrency(request.currency(), current.currency()),
                normalizeRate(request.storageGbMonthRate(), current.storageGbMonthRate(), "storageGbMonthRate"),
                normalizeRate(request.ingressGbRate(), current.ingressGbRate(), "ingressGbRate"),
                normalizeRate(request.egressGbRate(), current.egressGbRate(), "egressGbRate"),
                normalizeRate(request.internalGbRate(), current.internalGbRate(), "internalGbRate"),
                normalizeRate(request.operationThousandRate(), current.operationThousandRate(), "operationThousandRate"),
                normalizeThreshold(request.warningAmount(), current.warningAmount(), "warningAmount"),
                normalizeCriticalThreshold(request.criticalAmount(), current.criticalAmount(), request.warningAmount(), current.warningAmount()),
                normalizeEventScanLimit(request.eventScanLimit(), current.eventScanLimit()),
                OffsetDateTime.now()
        );
        return repository.save(next);
    }

    public static String normalizeCurrency(String value, String fallback) {
        String candidate = value == null || value.isBlank() ? fallback : value;
        if (candidate == null || candidate.isBlank()) {
            return "USD";
        }
        String normalized = candidate.trim().toUpperCase(Locale.ROOT);
        if (normalized.length() > 12) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "currency must be 12 characters or fewer.");
        }
        return normalized;
    }

    public static BigDecimal normalizeRate(BigDecimal value, BigDecimal fallback, String fieldName) {
        BigDecimal normalized = value == null ? fallback : value;
        if (normalized == null) {
            normalized = BigDecimal.ZERO;
        }
        if (normalized.compareTo(BigDecimal.ZERO) < 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must be zero or greater.");
        }
        return money(normalized);
    }

    public static BigDecimal normalizeThreshold(BigDecimal value, BigDecimal fallback, String fieldName) {
        return normalizeRate(value, fallback, fieldName);
    }

    private static BigDecimal normalizeCriticalThreshold(
            BigDecimal requestedCritical,
            BigDecimal currentCritical,
            BigDecimal requestedWarning,
            BigDecimal currentWarning
    ) {
        BigDecimal critical = normalizeThreshold(requestedCritical, currentCritical, "criticalAmount");
        BigDecimal warning = normalizeThreshold(requestedWarning, currentWarning, "warningAmount");
        if (critical.compareTo(BigDecimal.ZERO) > 0 && warning.compareTo(BigDecimal.ZERO) > 0 && critical.compareTo(warning) < 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "criticalAmount must be zero or greater than or equal to warningAmount.");
        }
        return critical;
    }

    public static int normalizeEventScanLimit(Integer value, int fallback) {
        int normalized = value == null || value <= 0 ? fallback : value;
        if (normalized <= 0) {
            normalized = DEFAULT_EVENT_SCAN_LIMIT;
        }
        return Math.min(MAX_EVENT_SCAN_LIMIT, normalized);
    }

    private static BigDecimal money(BigDecimal value) {
        return value.setScale(6, RoundingMode.HALF_UP);
    }
}
