package com.example.osmu.admin;

import com.example.osmu.object.ObjectLifecycleRule;
import java.time.OffsetDateTime;
import java.util.List;

public record ObjectLifecycleRuleDryRunResponse(
        ObjectLifecycleRule rule,
        OffsetDateTime cutoff,
        int previewLimit,
        int purgeBatchSize,
        int candidateCount,
        long candidateBytes,
        boolean truncated,
        List<ObjectLifecycleRuleDryRunCandidateResponse> candidates
) {
}
