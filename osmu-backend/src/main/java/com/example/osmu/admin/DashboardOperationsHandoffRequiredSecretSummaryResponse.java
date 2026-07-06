package com.example.osmu.admin;

import java.util.List;

public record DashboardOperationsHandoffRequiredSecretSummaryResponse(
        String secretName,
        int actionCount,
        List<Integer> actionOrders,
        int inputFreeBlockedActionCount,
        List<Integer> inputFreeBlockedActionOrders
) {
}