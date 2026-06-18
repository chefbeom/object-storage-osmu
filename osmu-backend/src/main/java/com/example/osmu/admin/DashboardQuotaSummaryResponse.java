package com.example.osmu.admin;

import com.example.osmu.quota.QuotaPolicyResponse;
import java.util.List;

public record DashboardQuotaSummaryResponse(
        long policyCount,
        long warningPolicyCount,
        long exhaustedPolicyCount,
        long totalQuotaBytes,
        long totalUsedBytes,
        long totalRemainingBytes,
        List<QuotaPolicyResponse> topPolicies
) {
}
