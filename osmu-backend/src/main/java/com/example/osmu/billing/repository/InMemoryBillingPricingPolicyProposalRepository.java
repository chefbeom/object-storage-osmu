package com.example.osmu.billing.repository;

import com.example.osmu.billing.BillingPricingPolicyProposalRecord;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryBillingPricingPolicyProposalRepository implements BillingPricingPolicyProposalRepository {

    private final AtomicLong sequence = new AtomicLong(1);
    private final List<BillingPricingPolicyProposalRecord> records = new CopyOnWriteArrayList<>();

    @Override
    public BillingPricingPolicyProposalRecord save(BillingPricingPolicyProposalRecord record) {
        BillingPricingPolicyProposalRecord withId = withId(record, sequence.getAndIncrement());
        records.add(withId);
        return withId;
    }

    @Override
    public List<BillingPricingPolicyProposalRecord> findAll(int limit) {
        return records.stream()
                .sorted(Comparator.comparing(BillingPricingPolicyProposalRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public List<BillingPricingPolicyProposalRecord> findByStatus(String status, int limit) {
        String normalized = status == null ? "" : status.trim().toUpperCase();
        return records.stream()
                .filter(record -> record.status().equals(normalized))
                .sorted(Comparator.comparing(BillingPricingPolicyProposalRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public Optional<BillingPricingPolicyProposalRecord> findById(long id) {
        return records.stream()
                .filter(record -> record.id() != null && record.id() == id)
                .findFirst();
    }

    @Override
    public BillingPricingPolicyProposalRecord updateApproval(
            long id,
            String status,
            String approvedBy,
            String approvalNote
    ) {
        OffsetDateTime now = OffsetDateTime.now();
        for (int index = 0; index < records.size(); index += 1) {
            BillingPricingPolicyProposalRecord current = records.get(index);
            if (current.id() != null && current.id() == id) {
                BillingPricingPolicyProposalRecord updated = new BillingPricingPolicyProposalRecord(
                        current.id(),
                        status,
                        current.currency(),
                        current.storageGbMonthRate(),
                        current.ingressGbRate(),
                        current.egressGbRate(),
                        current.internalGbRate(),
                        current.operationThousandRate(),
                        current.warningAmount(),
                        current.criticalAmount(),
                        current.eventScanLimit(),
                        current.requestedBy(),
                        approvedBy,
                        false,
                        current.reason(),
                        approvalNote,
                        current.commercialApprovedBy(),
                        current.commercialApprovalReference(),
                        current.commercialApprovalNote(),
                        current.createdAt(),
                        now,
                        now,
                        now,
                        current.commercialApprovedAt(),
                        current.commercialEffectiveFrom()
                );
                records.set(index, updated);
                return updated;
            }
        }
        throw new ApiException(ApiErrorCode.NOT_FOUND, "Billing pricing policy proposal not found.");
    }

    @Override
    public BillingPricingPolicyProposalRecord updateCommercialApproval(
            long id,
            String status,
            String approvedBy,
            String approvalReference,
            String approvalNote,
            OffsetDateTime effectiveFrom
    ) {
        OffsetDateTime now = OffsetDateTime.now();
        for (int index = 0; index < records.size(); index += 1) {
            BillingPricingPolicyProposalRecord current = records.get(index);
            if (current.id() != null && current.id() == id) {
                BillingPricingPolicyProposalRecord updated = new BillingPricingPolicyProposalRecord(
                        current.id(),
                        status,
                        current.currency(),
                        current.storageGbMonthRate(),
                        current.ingressGbRate(),
                        current.egressGbRate(),
                        current.internalGbRate(),
                        current.operationThousandRate(),
                        current.warningAmount(),
                        current.criticalAmount(),
                        current.eventScanLimit(),
                        current.requestedBy(),
                        current.approvedBy(),
                        true,
                        current.reason(),
                        current.approvalNote(),
                        approvedBy,
                        approvalReference,
                        approvalNote,
                        current.createdAt(),
                        now,
                        current.approvedAt(),
                        current.appliedAt(),
                        now,
                        effectiveFrom
                );
                records.set(index, updated);
                return updated;
            }
        }
        throw new ApiException(ApiErrorCode.NOT_FOUND, "Billing pricing policy proposal not found.");
    }

    private static int normalizeLimit(int limit) {
        return Math.max(1, Math.min(limit <= 0 ? 50 : limit, 200));
    }

    private static BillingPricingPolicyProposalRecord withId(
            BillingPricingPolicyProposalRecord record,
            long id
    ) {
        return new BillingPricingPolicyProposalRecord(
                id,
                record.status(),
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
                record.approvedBy(),
                record.approvedPriceList(),
                record.reason(),
                record.approvalNote(),
                record.commercialApprovedBy(),
                record.commercialApprovalReference(),
                record.commercialApprovalNote(),
                record.createdAt(),
                record.updatedAt(),
                record.approvedAt(),
                record.appliedAt(),
                record.commercialApprovedAt(),
                record.commercialEffectiveFrom()
        );
    }
}
