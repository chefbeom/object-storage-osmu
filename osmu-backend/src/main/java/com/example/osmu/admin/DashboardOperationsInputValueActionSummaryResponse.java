package com.example.osmu.admin;

import java.util.List;

public record DashboardOperationsInputValueActionSummaryResponse(
        int actionOrder,
        String actionName,
        String category,
        String workflow,
        boolean inputFree,
        String status,
        int valueCount,
        int readyValueCount,
        int missingValueCount,
        int unsafeValueCount,
        int invalidValueCount,
        List<String> nonReadyValueKeys
) {
}
