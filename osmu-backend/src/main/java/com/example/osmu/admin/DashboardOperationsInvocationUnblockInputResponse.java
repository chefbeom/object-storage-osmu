package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsInvocationUnblockInputResponse(
        String placeholder,
        String parameter,
        String valueTemplate,
        List<String> workflowInputs,
        int occurrenceCount,
        boolean ambiguousRepeatedPlaceholder,
        String note
) {
}
