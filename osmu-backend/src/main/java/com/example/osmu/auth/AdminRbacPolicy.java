package com.example.osmu.auth;

import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public class AdminRbacPolicy {

    private static final String ADMIN = "ADMIN";
    private static final String ORG_ADMIN = "ORG_ADMIN";
    private static final String AUDITOR = "AUDITOR";

    private static final List<RouteRule> ORG_ADMIN_ALLOWED_ROUTES = List.of(
            RouteRule.exact("GET", "/api/admin/users"),
            RouteRule.exact("POST", "/api/admin/users"),
            RouteRule.pattern("PATCH", "^/api/admin/users/\\d+/status$"),
            RouteRule.exact("GET", "/api/admin/organizations"),
            RouteRule.exact("GET", "/api/admin/organizations/usage"),
            RouteRule.exact("GET", "/api/admin/teams"),
            RouteRule.exact("POST", "/api/admin/teams"),
            RouteRule.pattern("PUT", "^/api/admin/teams/\\d+/members$"),
            RouteRule.pattern("DELETE", "^/api/admin/teams/\\d+$")
    );
    private static final List<RouteRule> AUDITOR_ALLOWED_ROUTES = List.of(
            RouteRule.exact("GET", "/api/admin/audit-logs"),
            RouteRule.exact("GET", "/api/admin/audit-logs/export.csv"),
            RouteRule.exact("GET", "/api/admin/usage"),
            RouteRule.exact("GET", "/api/admin/system/status"),
            RouteRule.exact("GET", "/api/admin/security/enterprise-auth-plan"),
            RouteRule.exact("GET", "/api/admin/dashboard/summary"),
            RouteRule.exact("GET", "/api/admin/dashboard/readiness"),
            RouteRule.exact("GET", "/api/admin/backup/status"),
            RouteRule.exact("GET", "/api/admin/backup/restore-drill-evidence")
    );

    public boolean isAllowed(String method, String uri, String role) {
        String normalizedRole = normalizeRole(role);
        if (ADMIN.equals(normalizedRole)) {
            return true;
        }
        if (ORG_ADMIN.equals(normalizedRole)) {
            return ORG_ADMIN_ALLOWED_ROUTES.stream()
                    .anyMatch(rule -> rule.matches(method, uri));
        }
        if (!AUDITOR.equals(normalizedRole)) {
            return false;
        }
        return AUDITOR_ALLOWED_ROUTES.stream()
                .anyMatch(rule -> rule.matches(method, uri));
    }

    private String normalizeRole(String role) {
        return role == null ? "" : role.trim().toUpperCase(Locale.ROOT);
    }

    private record RouteRule(String method, Pattern uriPattern) {

        private static RouteRule exact(String method, String uri) {
            return pattern(method, "^" + Pattern.quote(uri) + "$");
        }

        private static RouteRule pattern(String method, String uriRegex) {
            return new RouteRule(method.toUpperCase(Locale.ROOT), Pattern.compile(uriRegex));
        }

        private boolean matches(String requestMethod, String uri) {
            return method.equals(normalizeMethod(requestMethod))
                    && uri != null
                    && uriPattern.matcher(uri).matches();
        }

        private static String normalizeMethod(String requestMethod) {
            return requestMethod == null ? "" : requestMethod.trim().toUpperCase(Locale.ROOT);
        }
    }
}
