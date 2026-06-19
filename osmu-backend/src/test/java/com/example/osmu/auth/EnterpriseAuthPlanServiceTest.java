package com.example.osmu.auth;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class EnterpriseAuthPlanServiceTest {

    @Test
    void defaultPlanKeepsLocalPasswordActiveAndExternalAuthPlanned() {
        EnterpriseAuthPlanResponse plan = new EnterpriseAuthPlanService(
                "",
                "",
                false,
                false,
                "",
                "",
                "",
                "",
                false,
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                false
        ).plan();

        assertThat(plan.status()).isEqualTo("LOCAL_ONLY");
        assertThat(plan.activeLoginModes()).containsExactly("LOCAL_PASSWORD");
        assertThat(plan.plannedExternalModes()).containsExactly("OIDC", "LDAP");
        assertThat(plan.externalProviderConfigured()).isFalse();
        assertThat(plan.claimMapping().roleClaim()).isEqualTo("osmu_roles");
        assertThat(plan.claimMapping().organizationClaim()).isEqualTo("osmu_org");
        assertThat(plan.claimMapping().teamClaim()).isEqualTo("osmu_teams");
        assertThat(plan.roleMappings())
                .extracting(EnterpriseAuthPlanResponse.RoleMapping::osmuRole)
                .contains("ADMIN", "ORG_ADMIN", "AUDITOR", "USER");
        assertThat(plan.gates())
                .anyMatch(gate -> "login-cutover".equals(gate.key()) && "REVIEW".equals(gate.status()));
    }

    @Test
    void configuredOidcProviderMovesPlanToReadyWithoutActivatingExternalLogin() {
        EnterpriseAuthPlanResponse plan = new EnterpriseAuthPlanService(
                "https://idp.example.com/realms/osmu",
                "osmu-web",
                false,
                false,
                "",
                "",
                "",
                "",
                false,
                "",
                "",
                "sub",
                "email",
                "name",
                "groups",
                "department",
                "teams",
                "example.com, corp.example.com",
                false
        ).plan();

        assertThat(plan.status()).isEqualTo("PLAN_READY");
        assertThat(plan.currentLoginMode()).isEqualTo("LOCAL_PASSWORD");
        assertThat(plan.oidc().status()).isEqualTo("CONFIGURED");
        assertThat(plan.oidc().clientIdConfigured()).isTrue();
        assertThat(plan.claimMapping().roleClaim()).isEqualTo("groups");
        assertThat(plan.claimMapping().allowedDomains()).containsExactly("example.com", "corp.example.com");
        assertThat(plan.gates())
                .anyMatch(gate -> "oidc-authorization-request".equals(gate.key()) && "REVIEW".equals(gate.status()));
        assertThat(plan.gates())
                .anyMatch(gate -> "oidc-callback-validation".equals(gate.key()) && "REVIEW".equals(gate.status()));
    }

    @Test
    void configuredOidcAuthorizationRequestGateRequiresExplicitEnablementAndRedirects() {
        EnterpriseAuthPlanResponse plan = new EnterpriseAuthPlanService(
                "https://idp.example.com/realms/osmu",
                "osmu-web",
                true,
                true,
                "https://idp.example.com/realms/osmu/protocol/openid-connect/auth",
                "https://idp.example.com/realms/osmu/protocol/openid-connect/token",
                "https://idp.example.com/realms/osmu/protocol/openid-connect/certs",
                "http://localhost:5173/auth/oidc/callback",
                false,
                "",
                "",
                "sub",
                "email",
                "name",
                "groups",
                "department",
                "teams",
                "example.com",
                false
        ).plan();

        assertThat(plan.gates())
                .anyMatch(gate -> "oidc-authorization-request".equals(gate.key()) && "SUCCESS".equals(gate.status()));
        assertThat(plan.gates())
                .anyMatch(gate -> "oidc-callback-validation".equals(gate.key()) && "SUCCESS".equals(gate.status()));
    }

    @Test
    void configuredLdapLoginGateRequiresExplicitEnablement() {
        EnterpriseAuthPlanResponse plan = new EnterpriseAuthPlanService(
                "",
                "",
                false,
                false,
                "",
                "",
                "",
                "",
                true,
                "ldap://directory.example.com:389",
                "ou=people,dc=example,dc=com",
                "sub",
                "email",
                "name",
                "groups",
                "department",
                "teams",
                "example.com",
                false
        ).plan();

        assertThat(plan.ldap().status()).isEqualTo("CONFIGURED");
        assertThat(plan.gates())
                .anyMatch(gate -> "ldap-bind-search".equals(gate.key()) && "SUCCESS".equals(gate.status()));
    }
}
