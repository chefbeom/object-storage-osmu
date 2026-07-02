package com.example.osmu.admin;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record DashboardOperationsInvocationUnblockConfirmationGroupResponse(
        String kind,
        String label,
        String flag,
        int actionCount,
        List<Integer> actionOrders,
        String note
) {
}
