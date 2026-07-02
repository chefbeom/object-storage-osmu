package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsDispatchPreflightWorkflowFileResponse(
        int actionOrder,
        String workflow,
        String path,
        boolean exists,
        String dispatchUrl,
        List<String> requiredSecrets
) {
}
