package com.example.osmu.admin;

import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.quota.QuotaPolicyHistoryResponse;
import com.example.osmu.quota.QuotaPolicyRequest;
import com.example.osmu.quota.QuotaPolicyResponse;
import com.example.osmu.quota.QuotaPolicyService;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/quota-policies")
public class AdminQuotaPolicyController {

    private final QuotaPolicyService quotaPolicyService;
    private final AuthContext authContext;

    public AdminQuotaPolicyController(QuotaPolicyService quotaPolicyService, AuthContext authContext) {
        this.quotaPolicyService = quotaPolicyService;
        this.authContext = authContext;
    }

    @GetMapping
    public ListResponse<QuotaPolicyResponse> list() {
        return ListResponse.of(quotaPolicyService.list());
    }

    @GetMapping("/history")
    public ListResponse<QuotaPolicyHistoryResponse> history(@RequestParam(name = "limit", defaultValue = "50") int limit) {
        return ListResponse.of(quotaPolicyService.history(limit));
    }

    @PutMapping("/{targetType}/{targetId}")
    public ApiResponse<QuotaPolicyResponse> save(
            @PathVariable("targetType") String targetType,
            @PathVariable("targetId") long targetId,
            @RequestBody QuotaPolicyRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        return ApiResponse.of(quotaPolicyService.save(targetType, targetId, request, user.loginId()));
    }

    @DeleteMapping("/{targetType}/{targetId}")
    public ResponseEntity<Void> delete(
            @PathVariable("targetType") String targetType,
            @PathVariable("targetId") long targetId,
            @RequestParam(name = "reason", required = false) String reason,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        quotaPolicyService.delete(targetType, targetId, user.loginId(), reason);
        return ResponseEntity.noContent().build();
    }
}
