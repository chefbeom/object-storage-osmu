package com.example.osmu.storageprofile;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class StorageProfileController {

    private final StorageProfileService storageProfileService;
    private final AuthContext authContext;
    private final AuditLogService auditLogService;

    public StorageProfileController(
            StorageProfileService storageProfileService,
            AuthContext authContext,
            AuditLogService auditLogService
    ) {
        this.storageProfileService = storageProfileService;
        this.authContext = authContext;
        this.auditLogService = auditLogService;
    }

    @GetMapping("/storage-profiles")
    public ListResponse<StorageProfileResponse> profiles() {
        return ListResponse.of(storageProfileService.profiles());
    }

    @GetMapping("/storage-profile-requests")
    public ListResponse<StorageProfileRequestResponse> listRequests(
            @RequestParam(value = "bucketName", required = false) String bucketName,
            @RequestParam(value = "cursor", required = false) String cursor,
            @RequestParam(value = "limit", required = false) Integer limit,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        return storageProfileService.listVisibleRequests(user, bucketName, cursor, limit);
    }

    @GetMapping("/buckets/{bucketName}/storage-profile")
    public ApiResponse<StorageProfileCurrentResponse> current(
            @PathVariable String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(storageProfileService.current(user, bucketName));
    }

    @PostMapping("/buckets/{bucketName}/storage-profile-requests")
    public ApiResponse<StorageProfileRequestResponse> createRequest(
            @PathVariable String bucketName,
            @RequestBody(required = false) StorageProfileRequestPayload payload,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StorageProfileRequestResponse response = storageProfileService.createRequest(user, bucketName, payload);
        auditLogService.record(
                "STORAGE_PROFILE_REQUEST_CREATE",
                user.loginId(),
                "STORAGE_PROFILE_REQUEST",
                String.valueOf(response.id()),
                "SUCCESS",
                "Storage profile request created for " + response.bucketName(),
                request
        );
        return ApiResponse.of(response);
    }
}
