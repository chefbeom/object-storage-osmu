package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsDispatchPreflightInputResponse(
        int actionOrder,
        String placeholder,
        String parameter,
        String valueTemplate,
        List<String> workflowInputs,
        boolean supplied,
        boolean safeValue,
        boolean validValue,
        String valuePreview,
        boolean ambiguousRepeatedPlaceholder,
        String note
) {
}
