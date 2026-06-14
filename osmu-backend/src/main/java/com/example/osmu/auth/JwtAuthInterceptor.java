package com.example.osmu.auth;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class JwtAuthInterceptor implements HandlerInterceptor {

    public static final String CLAIMS_ATTRIBUTE = "osmu.jwt.claims";

    private final JwtTokenService jwtTokenService;

    public JwtAuthInterceptor(JwtTokenService jwtTokenService) {
        this.jwtTokenService = jwtTokenService;
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
        if (isAdminPath(request.getRequestURI()) && !isAdminRequestAllowed(request.getMethod(), request.getRequestURI(), claims.role())) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Admin role required.");
        }
        request.setAttribute(CLAIMS_ATTRIBUTE, claims);
        return true;
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

    private boolean isAdminRequestAllowed(String method, String uri, String role) {
        if ("ADMIN".equals(role)) {
            return true;
        }
        if (!"ORG_ADMIN".equals(role)) {
            return false;
        }
        return isOrgAdminPath(method, uri);
    }

    private boolean isOrgAdminPath(String method, String uri) {
        if ("GET".equalsIgnoreCase(method) && "/api/admin/users".equals(uri)) {
            return true;
        }
        if ("POST".equalsIgnoreCase(method) && "/api/admin/users".equals(uri)) {
            return true;
        }
        if ("PATCH".equalsIgnoreCase(method) && uri.matches("^/api/admin/users/\\d+/status$")) {
            return true;
        }
        if ("GET".equalsIgnoreCase(method) && "/api/admin/organizations".equals(uri)) {
            return true;
        }
        return "GET".equalsIgnoreCase(method) && "/api/admin/organizations/usage".equals(uri);
    }
}
