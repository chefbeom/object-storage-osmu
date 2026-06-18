package com.example.osmu.auth;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class JwtAuthInterceptor implements HandlerInterceptor {

    public static final String CLAIMS_ATTRIBUTE = "osmu.jwt.claims";

    private final JwtTokenService jwtTokenService;
    private final UserRepository userRepository;
    private final AdminRbacPolicy adminRbacPolicy;

    public JwtAuthInterceptor(
            JwtTokenService jwtTokenService,
            UserRepository userRepository,
            AdminRbacPolicy adminRbacPolicy
    ) {
        this.jwtTokenService = jwtTokenService;
        this.userRepository = userRepository;
        this.adminRbacPolicy = adminRbacPolicy;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if ("OPTIONS".equalsIgnoreCase(request.getMethod()) || isPublicPath(request.getRequestURI())) {
            return true;
        }

        String authorization = request.getHeader("Authorization");
        if (isS3Path(request.getRequestURI()) && !hasBearerToken(authorization) && (hasAccessKeyHeaders(request) || hasAwsSigV4Authorization(authorization) || hasAwsSigV4Query(request))) {
            return true;
        }

        String token = extractBearerToken(authorization);
        JwtClaims claims = jwtTokenService.verifyAccessToken(token);
        UserAccount user = activeUser(claims);
        if (isAdminPath(request.getRequestURI()) && !adminRbacPolicy.isAllowed(request.getMethod(), request.getRequestURI(), user.role())) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Admin role required.");
        }
        request.setAttribute(CLAIMS_ATTRIBUTE, claims);
        return true;
    }

    private UserAccount activeUser(JwtClaims claims) {
        return userRepository.findById(parseUserId(claims.subject()))
                .filter(account -> "ACTIVE".equals(account.status()))
                .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid authenticated user."));
    }

    private long parseUserId(String subject) {
        try {
            return Long.parseLong(subject);
        } catch (NumberFormatException exception) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid authenticated user.");
        }
    }

    private String extractBearerToken(String authorization) {
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Authentication required.");
        }
        String token = authorization.substring("Bearer ".length()).trim();
        if (token.isEmpty()) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Authentication required.");
        }
        return token;
    }

    private boolean hasBearerToken(String authorization) {
        return authorization != null && authorization.startsWith("Bearer ");
    }

    private boolean hasAwsSigV4Authorization(String authorization) {
        return authorization != null && authorization.startsWith("AWS4-HMAC-SHA256 ");
    }

    private boolean hasAwsSigV4Query(HttpServletRequest request) {
        return "AWS4-HMAC-SHA256".equals(request.getParameter("X-Amz-Algorithm"));
    }

    private boolean hasAccessKeyHeaders(HttpServletRequest request) {
        return hasText(request.getHeader("X-OSMU-Access-Key"))
                || hasText(request.getHeader("X-OSMU-Secret-Key"));
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private boolean isPublicPath(String uri) {
        return "/api/health".equals(uri)
                || "/api/storage/health".equals(uri)
                || "/api/database/health".equals(uri)
                || "/api/auth/login".equals(uri)
                || "/api/auth/refresh".equals(uri)
                || uri.startsWith("/api/public/share-links/");
    }

    private boolean isS3Path(String uri) {
        return "/api/s3".equals(uri) || uri.startsWith("/api/s3/");
    }

    private boolean isAdminPath(String uri) {
        return uri.startsWith("/api/admin/");
    }

}
