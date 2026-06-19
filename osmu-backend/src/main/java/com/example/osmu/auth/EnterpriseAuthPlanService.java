package com.example.osmu.auth;

import com.example.osmu.auth.EnterpriseAuthPlanResponse.ClaimMapping;
import com.example.osmu.auth.EnterpriseAuthPlanResponse.LdapProvider;
import com.example.osmu.auth.EnterpriseAuthPlanResponse.OidcProvider;
import com.example.osmu.auth.EnterpriseAuthPlanResponse.PlanGate;
import com.example.osmu.auth.EnterpriseAuthPlanResponse.RoleMapping;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class EnterpriseAuthPlanService {

    private final String oidcIssuerUri;
    private final String oidcClientId;
    private final boolean oidcAuthorizationEnabled;
    private final boolean oidcCallbackEnabled;
    private final String oidcAuthorizationUri;
    private final String oidcTokenUri;
    private final String oidcJwksUri;
    private final String oidcRedirectUri;
    private final boolean ldapLoginEnabled;
    private final String ldapUrl;
    private final String ldapBaseDn;
    private final String subjectClaim;
    private final String emailClaim;
    private final String nameClaim;
    private final String roleClaim;
    private final String organizationClaim;
    private final String teamClaim;
    private final List<String> allowedDomains;
    private final boolean jitProvisioningEnabled;

    public EnterpriseAuthPlanService(
            @Value("${osmu.enterprise-auth.oidc.issuer-uri:}") String oidcIssuerUri,
            @Value("${osmu.enterprise-auth.oidc.client-id:}") String oidcClientId,
            @Value("${osmu.enterprise-auth.oidc.authorization-enabled:false}") boolean oidcAuthorizationEnabled,
            @Value("${osmu.enterprise-auth.oidc.callback-enabled:false}") boolean oidcCallbackEnabled,
            @Value("${osmu.enterprise-auth.oidc.authorization-uri:}") String oidcAuthorizationUri,
            @Value("${osmu.enterprise-auth.oidc.token-uri:}") String oidcTokenUri,
            @Value("${osmu.enterprise-auth.oidc.jwks-uri:}") String oidcJwksUri,
            @Value("${osmu.enterprise-auth.oidc.redirect-uri:}") String oidcRedirectUri,
            @Value("${osmu.enterprise-auth.ldap.login-enabled:false}") boolean ldapLoginEnabled,
            @Value("${osmu.enterprise-auth.ldap.url:}") String ldapUrl,
            @Value("${osmu.enterprise-auth.ldap.base-dn:}") String ldapBaseDn,
            @Value("${osmu.enterprise-auth.claims.subject:sub}") String subjectClaim,
            @Value("${osmu.enterprise-auth.claims.email:email}") String emailClaim,
            @Value("${osmu.enterprise-auth.claims.name:name}") String nameClaim,
            @Value("${osmu.enterprise-auth.claims.roles:osmu_roles}") String roleClaim,
            @Value("${osmu.enterprise-auth.claims.organization:osmu_org}") String organizationClaim,
            @Value("${osmu.enterprise-auth.claims.teams:osmu_teams}") String teamClaim,
            @Value("${osmu.enterprise-auth.allowed-domains:}") String allowedDomains,
            @Value("${osmu.enterprise-auth.jit-provisioning.enabled:false}") boolean jitProvisioningEnabled
    ) {
        this.oidcIssuerUri = clean(oidcIssuerUri);
        this.oidcClientId = clean(oidcClientId);
        this.oidcAuthorizationEnabled = oidcAuthorizationEnabled;
        this.oidcCallbackEnabled = oidcCallbackEnabled;
        this.oidcAuthorizationUri = clean(oidcAuthorizationUri);
        this.oidcTokenUri = clean(oidcTokenUri);
        this.oidcJwksUri = clean(oidcJwksUri);
        this.oidcRedirectUri = clean(oidcRedirectUri);
        this.ldapLoginEnabled = ldapLoginEnabled;
        this.ldapUrl = clean(ldapUrl);
        this.ldapBaseDn = clean(ldapBaseDn);
        this.subjectClaim = fallback(subjectClaim, "sub");
        this.emailClaim = fallback(emailClaim, "email");
        this.nameClaim = fallback(nameClaim, "name");
        this.roleClaim = fallback(roleClaim, "osmu_roles");
        this.organizationClaim = fallback(organizationClaim, "osmu_org");
        this.teamClaim = fallback(teamClaim, "osmu_teams");
        this.allowedDomains = splitCsv(allowedDomains);
        this.jitProvisioningEnabled = jitProvisioningEnabled;
    }

    public EnterpriseAuthPlanResponse plan() {
        boolean oidcConfigured = hasText(oidcIssuerUri) && hasText(oidcClientId);
        boolean ldapConfigured = hasText(ldapUrl) && hasText(ldapBaseDn);
        boolean externalConfigured = oidcConfigured || ldapConfigured;
        return new EnterpriseAuthPlanResponse(
                externalConfigured ? "PLAN_READY" : "LOCAL_ONLY",
                "LOCAL_PASSWORD",
                List.of("LOCAL_PASSWORD"),
                List.of("OIDC", "LDAP"),
                externalConfigured,
                new OidcProvider(oidcConfigured ? "CONFIGURED" : "NOT_CONFIGURED", oidcIssuerUri, hasText(oidcClientId)),
                new LdapProvider(ldapConfigured ? "CONFIGURED" : "NOT_CONFIGURED", ldapUrl, ldapBaseDn),
                new ClaimMapping(
                        subjectClaim,
                        emailClaim,
                        nameClaim,
                        roleClaim,
                        organizationClaim,
                        teamClaim,
                        allowedDomains,
                        jitProvisioningEnabled
                ),
                roleMappings(),
                gates(oidcConfigured, ldapConfigured),
                nextImplementationSteps(),
                OffsetDateTime.now()
        );
    }

    private List<RoleMapping> roleMappings() {
        return List.of(
                new RoleMapping("osmu-admins", "ADMIN", "Global administration"),
                new RoleMapping("osmu-org-admins", "ORG_ADMIN", "Organization claim must match managed organization"),
                new RoleMapping("osmu-auditors", "AUDITOR", "Read-only audit and status routes"),
                new RoleMapping("*", "USER", "Default role when no privileged mapping matches")
        );
    }

    private List<PlanGate> gates(boolean oidcConfigured, boolean ldapConfigured) {
        boolean oidcAuthorizationReady = oidcConfigured
                && oidcAuthorizationEnabled
                && hasText(oidcAuthorizationUri)
                && hasText(oidcRedirectUri);
        boolean oidcCallbackReady = oidcAuthorizationReady
                && oidcCallbackEnabled
                && hasText(oidcTokenUri)
                && hasText(oidcJwksUri);
        return List.of(
                new PlanGate(
                        "provider-metadata",
                        oidcConfigured || ldapConfigured ? "SUCCESS" : "REVIEW",
                        "Configure either OIDC issuer/client or LDAP URL/base DN before pilot login."
                ),
                new PlanGate(
                        "oidc-authorization-request",
                        oidcAuthorizationReady ? "SUCCESS" : "REVIEW",
                        "Enable the OIDC authorization-code start endpoint only after issuer, client, authorization URI, and redirect URI are configured."
                ),
                new PlanGate(
                        "oidc-callback-validation",
                        oidcCallbackReady ? "SUCCESS" : "REVIEW",
                        "Enable OIDC callback only after token URI and JWKS URI are configured and existing local user mapping is ready."
                ),
                new PlanGate(
                        "ldap-bind-search",
                        ldapConfigured && ldapLoginEnabled ? "SUCCESS" : "REVIEW",
                        "Enable LDAP bind/search only after URL, base DN, search filter, and existing local user email mapping are ready."
                ),
                new PlanGate(
                        "claim-mapping",
                        "SUCCESS",
                        "Role, organization, and team claims are named and mapped to existing OSMU RBAC subjects."
                ),
                new PlanGate(
                        "jit-provisioning",
                        jitProvisioningEnabled ? "REVIEW" : "SUCCESS",
                        "Automatic callback JIT provisioning is disabled by default; admin-approved claim preview and apply flow are available."
                ),
                new PlanGate(
                        "session-boundary",
                        "SUCCESS",
                        "External identity will still issue OSMU JWT and refresh tokens after successful callback validation."
                ),
                new PlanGate(
                        "login-cutover",
                        "REVIEW",
                        "Local password login remains the only active login mode until callback, state, nonce, and PKCE tests exist."
                )
        );
    }

    private List<String> nextImplementationSteps() {
        return List.of(
                "Run IdP pilot smoke for OIDC authorization-code callback, token exchange, JWKS issuer validation, and existing user mapping.",
                "Keep callback auto-JIT disabled until admin-approved provisioning audit and rollback evidence pass in a real IdP pilot.",
                "Run LDAP bind/search pilot smoke against the target enterprise directory before enabling login cutover.",
                "Run IdP pilot smoke and update security evidence before replacing local-only login."
        );
    }

    private static List<String> splitCsv(String value) {
        if (!hasText(value)) {
            return List.of();
        }
        return Arrays.stream(value.split(","))
                .map(EnterpriseAuthPlanService::clean)
                .filter(EnterpriseAuthPlanService::hasText)
                .distinct()
                .toList();
    }

    private static String fallback(String value, String fallback) {
        String cleaned = clean(value);
        return cleaned.isBlank() ? fallback : cleaned;
    }

    private static String clean(String value) {
        return value == null ? "" : value.trim();
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
