package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsInvocationUnblockInputResponse(
        String placeholder,
        String parameter,
        String valueTemplate,
        int occurrenceCount,
        boolean ambiguousRepeatedPlaceholder,
        String note
) {
}
