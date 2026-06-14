package com.example.osmu.accesskey;

import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import jakarta.validation.Valid;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/access-keys")
public class AccessKeyController {

    private final AccessKeyService accessKeyService;
    private final AuditLogService auditLogService;
    private final AuthContext authContext;

    public AccessKeyController(
            AccessKeyService accessKeyService,
            AuditLogService auditLogService,
            AuthContext authContext
    ) {
        this.accessKeyService = accessKeyService;
        this.auditLogService = auditLogService;
        this.authContext = authContext;
    }

    @GetMapping
    public ListResponse<AccessKeyRecord> listAccessKeys(HttpServletRequest request) {
        return ListResponse.of(accessKeyService.list(authContext.currentUser(request)));
    }

    @PostMapping
    public ApiResponse<CreateAccessKeyResponse> createAccessKey(
            @Valid @RequestBody CreateAccessKeyRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        CreateAccessKeyResponse response = accessKeyService.create(request, user);
        auditLogService.record("ACCESS_KEY_CREATE", user.loginId(), "ACCESS_KEY", response.accessKey(), "SUCCESS", "Access key created", httpRequest);
        return ApiResponse.of(response);
    }

    @DeleteMapping("/{keyId}")
    public ResponseEntity<Void> deleteAccessKey(@PathVariable("keyId") long keyId, HttpServletRequest request) {
        AuthenticatedUser user = authContext.currentUser(request);
        accessKeyService.delete(keyId, user);
        auditLogService.record("ACCESS_KEY_DELETE", user.loginId(), "ACCESS_KEY", String.valueOf(keyId), "SUCCESS", "Access key disabled", request);
        return ResponseEntity.noContent().build();
    }
}
