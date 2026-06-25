package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsDispatchPreflightInputResponse(
        int actionOrder,
        String placeholder,
        String parameter,
        String valueTemplate,
        boolean supplied,
        boolean safeValue,
        boolean validValue,
        String valuePreview,
        boolean ambiguousRepeatedPlaceholder,
        String note
) {
}
