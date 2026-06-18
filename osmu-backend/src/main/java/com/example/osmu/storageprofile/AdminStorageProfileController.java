package com.example.osmu.storageprofile;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/storage-profile-requests")
public class AdminStorageProfileController {

    private final StorageProfileService storageProfileService;
    private final AuthContext authContext;
    private final AuditLogService auditLogService;

    public AdminStorageProfileController(
            StorageProfileService storageProfileService,
            AuthContext authContext,
            AuditLogService auditLogService
    ) {
        this.storageProfileService = storageProfileService;
        this.authContext = authContext;
        this.auditLogService = auditLogService;
    }

    @GetMapping
    public ListResponse<StorageProfileRequestResponse> list(HttpServletRequest request) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ListResponse.of(storageProfileService.listAllRequests(user));
    }

    @PatchMapping("/{requestId}/status")
    public ApiResponse<StorageProfileRequestResponse> updateStatus(
            @PathVariable long requestId,
            @RequestBody(required = false) StorageProfileStatusRequest statusRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageProfileRequestResponse response = storageProfileService.updateStatus(user, requestId, statusRequest);
        auditLogService.record(
                "STORAGE_PROFILE_REQUEST_STATUS",
                user.loginId(),
                "STORAGE_PROFILE_REQUEST",
                String.valueOf(response.id()),
                "SUCCESS",
                "Storage profile request status updated to " + response.status(),
                request
        );
        return ApiResponse.of(response);
    }

    @PostMapping("/{requestId}/apply")
    public ApiResponse<StorageProfileRequestResponse> apply(
            @PathVariable long requestId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageProfileRequestResponse response = storageProfileService.apply(user, requestId);
        auditLogService.record(
                "STORAGE_PROFILE_REQUEST_APPLY",
                user.loginId(),
                "STORAGE_PROFILE_REQUEST",
                String.valueOf(response.id()),
                "SUCCESS",
                "Storage profile applied: " + response.requestedProfile().code(),
                request
        );
        return ApiResponse.of(response);
    }
}
