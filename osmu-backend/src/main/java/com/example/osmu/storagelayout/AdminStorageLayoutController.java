package com.example.osmu.storagelayout;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/storage-layouts")
public class AdminStorageLayoutController {

    private final StorageLayoutService storageLayoutService;
    private final AuthContext authContext;
    private final AuditLogService auditLogService;

    public AdminStorageLayoutController(
            StorageLayoutService storageLayoutService,
            AuthContext authContext,
            AuditLogService auditLogService
    ) {
        this.storageLayoutService = storageLayoutService;
        this.authContext = authContext;
        this.auditLogService = auditLogService;
    }

    @GetMapping("/capabilities")
    public ApiResponse<List<StorageLayoutDefinition>> capabilities(HttpServletRequest request) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(storageLayoutService.capabilities(user));
    }

    @GetMapping("/plans")
    public ListResponse<StorageLayoutPlanResponse> list(
            @RequestParam(value = "status", required = false) String status,
            @RequestParam(value = "cursor", required = false) String cursor,
            @RequestParam(value = "limit", required = false) Integer limit,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        return storageLayoutService.list(user, status, cursor, limit);
    }

    @PostMapping("/plans")
    public ApiResponse<StorageLayoutPlanResponse> create(
            @RequestBody(required = false) StorageLayoutPlanPayload payload,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageLayoutPlanResponse response = storageLayoutService.create(user, payload);
        auditLogService.record(
                "STORAGE_LAYOUT_PLAN_CREATE",
                user.loginId(),
                "STORAGE_LAYOUT_PLAN",
                String.valueOf(response.id()),
                "SUCCESS",
                "Storage layout plan created: " + response.layout().code(),
                request
        );
        return ApiResponse.of(response);
    }

    @PatchMapping("/plans/{planId}/status")
    public ApiResponse<StorageLayoutPlanResponse> updateStatus(
            @PathVariable long planId,
            @RequestBody(required = false) StorageLayoutStatusRequest statusRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageLayoutPlanResponse response = storageLayoutService.updateStatus(user, planId, statusRequest);
        auditLogService.record(
                "STORAGE_LAYOUT_PLAN_STATUS",
                user.loginId(),
                "STORAGE_LAYOUT_PLAN",
                String.valueOf(response.id()),
                "SUCCESS",
                "Storage layout plan status updated to " + response.status(),
                request
        );
        return ApiResponse.of(response);
    }

    @PostMapping("/plans/{planId}/simulate")
    public ApiResponse<StorageLayoutSimulationResponse> simulate(
            @PathVariable long planId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageLayoutSimulationResponse response = storageLayoutService.simulate(user, planId);
        auditLogService.record(
                "STORAGE_LAYOUT_PLAN_SIMULATE",
                user.loginId(),
                "STORAGE_LAYOUT_PLAN",
                String.valueOf(response.plan().id()),
                "SUCCESS",
                "Storage layout simulation completed without cluster mutation",
                request
        );
        return ApiResponse.of(response);
    }
}
