package com.example.osmu.auth;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.UserProfile;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthContext authContext;
    private final AuditLogService auditLogService;
    private final JwtTokenService jwtTokenService;
    private final PasswordService passwordService;
    private final RefreshTokenService refreshTokenService;
    private final UserRepository userRepository;

    public AuthController(
            AuthContext authContext,
            AuditLogService auditLogService,
            JwtTokenService jwtTokenService,
            PasswordService passwordService,
            RefreshTokenService refreshTokenService,
            UserRepository userRepository
    ) {
        this.authContext = authContext;
        this.auditLogService = auditLogService;
        this.jwtTokenService = jwtTokenService;
        this.passwordService = passwordService;
        this.refreshTokenService = refreshTokenService;
        this.userRepository = userRepository;
    }

    @PostMapping("/login")
    public ApiResponse<LoginResponse> login(@Valid @RequestBody LoginRequest request, HttpServletRequest httpRequest) {
        UserAccount user = userRepository.findByLoginId(request.loginId())
                .filter(account -> "ACTIVE".equals(account.status()))
                .filter(account -> passwordService.matches(request.password(), account.passwordHash()))
                .orElseThrow(() -> {
                    auditLogService.record("LOGIN", "anonymous", "USER", request.loginId(), "FAIL", "Invalid credentials", httpRequest);
                    return new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid loginId or password.");
                });

        UserProfile profile = user.toProfile();
        auditLogService.record("LOGIN", profile.loginId(), "USER", profile.loginId(), "SUCCESS", "User login", httpRequest);
        return ApiResponse.of(new LoginResponse(
                jwtTokenService.createAccessToken(profile),
                refreshTokenService.issue(profile),
                profile
        ));
    }

    @PostMapping("/refresh")
    public ApiResponse<LoginResponse> refresh(
            @Valid @RequestBody RefreshTokenRequest request,
            HttpServletRequest httpRequest
    ) {
        JwtClaims claims = jwtTokenService.verifyRefreshToken(request.refreshToken());
        UserAccount user = userRepository.findById(parseUserId(claims.subject()))
                .filter(account -> "ACTIVE".equals(account.status()))
                .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid refresh token."));
        UserProfile profile = refreshTokenService.verifyAndLoadUser(request.refreshToken(), user.toProfile());
        refreshTokenService.revoke(request.refreshToken());
        auditLogService.record("TOKEN_REFRESH", profile.loginId(), "USER", profile.loginId(), "SUCCESS", "Token refreshed", httpRequest);
        return ApiResponse.of(new LoginResponse(
                jwtTokenService.createAccessToken(profile),
                refreshTokenService.issue(profile),
                profile
        ));
    }

    @PostMapping("/logout")
    public ApiResponse<Map<String, Boolean>> logout(
            @RequestBody(required = false) RefreshTokenRequest refreshTokenRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        if (refreshTokenRequest != null) {
            refreshTokenService.revoke(refreshTokenRequest.refreshToken());
        }
        auditLogService.record("LOGOUT", user.loginId(), "USER", user.loginId(), "SUCCESS", "User logout", request);
        return ApiResponse.of(Map.of("success", true));
    }

    private long parseUserId(String subject) {
        try {
            return Long.parseLong(subject);
        } catch (NumberFormatException exception) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid refresh token.");
        }
    }
}
