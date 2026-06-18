package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsReadinessFinalizeStepResponse(
        String name,
        String script,
        List<String> arguments,
        String command,
        String result,
        int exitCode,
        String output,
        String notes
) {
}
