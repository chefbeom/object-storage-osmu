package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsDispatchPreflightGitRefSafetyResponse(
        boolean checked,
        String status,
        String githubRef,
        String currentBranch,
        String commitSha,
        String shortCommitSha,
        String upstreamRef,
        String upstreamCommitSha,
        int aheadCount,
        int behindCount,
        boolean workingTreeDirty,
        boolean githubRefMatchesCurrentBranch,
        boolean githubRefLikelyContainsCommit,
        String suggestedGitHubRef,
        String suggestedPushCommand,
        String note
) {
}