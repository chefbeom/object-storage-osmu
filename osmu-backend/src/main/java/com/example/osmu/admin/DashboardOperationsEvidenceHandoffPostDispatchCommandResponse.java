package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsEvidenceHandoffPostDispatchCommandResponse(
        String name,
        String command,
        String note
) {
}
