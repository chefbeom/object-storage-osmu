package com.example.osmu.billing;

import com.example.osmu.billing.repository.BillingPricingPolicyRepository;
import com.example.osmu.billing.repository.BillingPricingPolicyProposalRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;
import org.springframework.stereotype.Service;

@Service
public class BillingPricingPolicyService {

    public static final int DEFAULT_EVENT_SCAN_LIMIT = 10_000;
    public static final int MAX_EVENT_SCAN_LIMIT = 50_000;
    public static final String PROPOSAL_STATUS_PENDING_APPROVAL = "PENDING_APPROVAL";
    public static final String PROPOSAL_STATUS_APPROVED_APPLIED = "APPROVED_APPLIED";

    private final BillingPricingPolicyRepository repository;
    private final BillingPricingPolicyProposalRepository proposalRepository;

    public BillingPricingPolicyService(
            BillingPricingPolicyRepository repository,
            BillingPricingPolicyProposalRepository proposalRepository
    ) {
        this.repository = repository;
        this.proposalRepository = proposalRepository;
    }

    public BillingPricingPolicy current() {
        return repository.get();
    }

    public BillingPricingPolicy save(BillingPricingPolicyRequest request) {
        if (request == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Billing pricing policy request is required.");
        }
        return repository.save(buildPolicy(request, repository.get(), OffsetDateTime.now()));
    }

    public BillingPricingPolicyProposalCreateResponse createProposal(
            BillingPricingPolicyRequest request,
            String requestedBy
    ) {
        if (request == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Billing pricing policy proposal request is required.");
        }
        OffsetDateTime now = OffsetDateTime.now();
        BillingPricingPolicy proposed = buildPolicy(request, repository.get(), now);
        BillingPricingPolicyProposalRecord saved = proposalRepository.save(new BillingPricingPolicyProposalRecord(
                null,
                PROPOSAL_STATUS_PENDING_APPROVAL,
                proposed.currency(),
                proposed.storageGbMonthRate(),
                proposed.ingressGbRate(),
                proposed.egressGbRate(),
                proposed.internalGbRate(),
                proposed.operationThousandRate(),
                proposed.warningAmount(),
                proposed.criticalAmount(),
                proposed.eventScanLimit(),
                normalizeActor(requestedBy),
                null,
                normalizeReason(request.reason(), "Billing pricing policy proposal"),
                null,
                now,
                now,
                null,
                null
        ));
        return new BillingPricingPolicyProposalCreateResponse(
                PROPOSAL_STATUS_PENDING_APPROVAL,
                false,
                proposalResponse(saved),
                now,
                "Pricing policy proposal is waiting for internal approval and is not an approved external price list."
        );
    }

    public BillingPricingPolicyProposalListResponse proposals(String status, int limit) {
        String normalizedStatus = normalizeProposalStatusFilter(status);
        List<BillingPricingPolicyProposalRecord> records = normalizedStatus == null
                ? proposalRepository.findAll(limit)
                : proposalRepository.findByStatus(normalizedStatus, limit);
        return new BillingPricingPolicyProposalListResponse(
                records.size(),
                records.stream().map(BillingPricingPolicyService::proposalResponse).toList(),
                OffsetDateTime.now()
        );
    }

    public BillingPricingPolicyProposalApprovalResponse approveProposal(
            long proposalId,
            String approvedBy,
            String approvalNote
    ) {
        BillingPricingPolicyProposalRecord proposal = proposalRepository.findById(proposalId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Billing pricing policy proposal not found."));
        if (!PROPOSAL_STATUS_PENDING_APPROVAL.equals(proposal.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Only pending billing pricing policy proposals can be approved.");
        }
        OffsetDateTime now = OffsetDateTime.now();
        BillingPricingPolicy applied = repository.save(new BillingPricingPolicy(
                proposal.currency(),
                proposal.storageGbMonthRate(),
                proposal.ingressGbRate(),
                proposal.egressGbRate(),
                proposal.internalGbRate(),
                proposal.operationThousandRate(),
                proposal.warningAmount(),
                proposal.criticalAmount(),
                proposal.eventScanLimit(),
                now
        ));
        BillingPricingPolicyProposalRecord approved = proposalRepository.updateApproval(
                proposalId,
                PROPOSAL_STATUS_APPROVED_APPLIED,
                normalizeActor(approvedBy),
                normalizeOptionalNote(approvalNote)
        );
        return new BillingPricingPolicyProposalApprovalResponse(
                PROPOSAL_STATUS_APPROVED_APPLIED,
                false,
                proposalResponse(approved),
                applied,
                now,
                "Pricing policy proposal was approved for internal chargeback calculation only; it is not a final legal price list."
        );
    }

    private static BillingPricingPolicy buildPolicy(
            BillingPricingPolicyRequest request,
            BillingPricingPolicy current,
            OffsetDateTime updatedAt
    ) {
        return new BillingPricingPolicy(
                normalizeCurrency(request.currency(), current.currency()),
                normalizeRate(request.storageGbMonthRate(), current.storageGbMonthRate(), "storageGbMonthRate"),
                normalizeRate(request.ingressGbRate(), current.ingressGbRate(), "ingressGbRate"),
                normalizeRate(request.egressGbRate(), current.egressGbRate(), "egressGbRate"),
                normalizeRate(request.internalGbRate(), current.internalGbRate(), "internalGbRate"),
                normalizeRate(request.operationThousandRate(), current.operationThousandRate(), "operationThousandRate"),
                normalizeThreshold(request.warningAmount(), current.warningAmount(), "warningAmount"),
                normalizeCriticalThreshold(request.criticalAmount(), current.criticalAmount(), request.warningAmount(), current.warningAmount()),
                normalizeEventScanLimit(request.eventScanLimit(), current.eventScanLimit()),
                updatedAt
        );
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

    private static String normalizeProposalStatusFilter(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String normalized = value.trim().toUpperCase(Locale.ROOT);
        if (!PROPOSAL_STATUS_PENDING_APPROVAL.equals(normalized)
                && !PROPOSAL_STATUS_APPROVED_APPLIED.equals(normalized)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Unsupported billing pricing policy proposal status.");
        }
        return normalized;
    }

    private static String normalizeActor(String value) {
        String normalized = value == null || value.isBlank() ? "system" : value.trim();
        if (normalized.length() > 128) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "actor must be 128 characters or fewer.");
        }
        return normalized;
    }

    private static String normalizeReason(String value, String fallback) {
        String normalized = value == null || value.isBlank() ? fallback : value.trim();
        if (normalized.length() > 512) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "reason must be 512 characters or fewer.");
        }
        return normalized;
    }

    private static String normalizeOptionalNote(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        String normalized = value.trim();
        if (normalized.length() > 512) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "approvalNote must be 512 characters or fewer.");
        }
        return normalized;
    }

    private static BillingPricingPolicyProposalResponse proposalResponse(BillingPricingPolicyProposalRecord record) {
        return new BillingPricingPolicyProposalResponse(
                record.id() == null ? 0L : record.id(),
                record.status(),
                false,
                record.currency(),
                record.storageGbMonthRate(),
                record.ingressGbRate(),
                record.egressGbRate(),
                record.internalGbRate(),
                record.operationThousandRate(),
                record.warningAmount(),
                record.criticalAmount(),
                record.eventScanLimit(),
                record.requestedBy(),
                record.approvedBy() == null ? "" : record.approvedBy(),
                record.reason(),
                record.approvalNote() == null ? "" : record.approvalNote(),
                record.createdAt(),
                record.updatedAt(),
                record.approvedAt(),
                record.appliedAt()
        );
    }
}
