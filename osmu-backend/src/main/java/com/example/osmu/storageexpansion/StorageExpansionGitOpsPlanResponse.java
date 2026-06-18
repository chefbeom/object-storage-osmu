package com.example.osmu.storageexpansion;

import java.util.List;

public record StorageExpansionGitOpsPlanResponse(
        long requestId,
        String poolName,
        String status,
        boolean ready,
        boolean referenceOnly,
        String branchName,
        String commitMessage,
        String pullRequestTitle,
        String pullRequestBody,
        String manifestPath,
        String valuesPath,
        String artifactSha256,
        List<String> changedFiles,
        List<String> reviewChecklist
) {
}
