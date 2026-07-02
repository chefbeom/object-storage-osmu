package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceHandoffBrowserDispatchChecklistResponse(
        int actionOrder,
        String name,
        String category,
        String actionType,
        String workflow,
        String dispatchUrl,
        String runsUrl,
        String runIdParameter,
        String artifactName,
        String runListJsonPath,
        String runListJsonDirectoryCommand,
        String manualArtifactCollectionCommand,
        List<String> workflowInputNames,
        List<String> operatorChecklist,
        List<String> securityFinalizerRunIdInputs,
        List<String> securityFinalizerMissingRunIdInputs,
        String securityFinalizerDependencyNote,
        List<String> steps
) {
}