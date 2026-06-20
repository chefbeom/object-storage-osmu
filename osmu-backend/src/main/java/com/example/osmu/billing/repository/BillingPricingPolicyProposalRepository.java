package com.example.osmu.billing.repository;

import com.example.osmu.billing.BillingPricingPolicyProposalRecord;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface BillingPricingPolicyProposalRepository {

    BillingPricingPolicyProposalRecord save(BillingPricingPolicyProposalRecord record);

    List<BillingPricingPolicyProposalRecord> findAll(int limit);

    List<BillingPricingPolicyProposalRecord> findByStatus(String status, int limit);

    Optional<BillingPricingPolicyProposalRecord> findById(long id);

    BillingPricingPolicyProposalRecord updateApproval(
            long id,
            String status,
            String approvedBy,
            String approvalNote
    );

    BillingPricingPolicyProposalRecord updateCommercialApproval(
            long id,
            String status,
            String approvedBy,
            String approvalReference,
            String approvalNote,
            OffsetDateTime effectiveFrom
    );
}
