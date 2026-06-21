package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardIamRbacEvidenceResponse(
        String result,
        String status,
        String generatedAt,
        String startedAt,
        String completedAt,
        String namespace,
        String serviceAccount,
        String powerShellCommand,
        String gradleCommand,
        boolean runBackendPolicyTests,
        boolean runKubernetesLiveAuth,
        int failedCount,
        List<String> gaps,
        List<DashboardIamRbacEvidenceCommandResponse> commands,
        List<DashboardIamRbacEvidenceStepResponse> steps,
        String decisionRule,
        String secretPolicy
) {
    public static DashboardIamRbacEvidenceResponse empty() {
        return new DashboardIamRbacEvidenceResponse(
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                false,
                false,
                0,
                List.of(),
                List.of(),
                List.of(),
                "",
                ""
        );
    }
}
