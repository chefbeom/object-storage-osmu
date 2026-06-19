package com.example.osmu.auth;

import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "osmu.enterprise-auth.oidc.issuer-uri=https://idp.example.com/realms/osmu",
        "osmu.enterprise-auth.oidc.client-id=osmu-web",
        "osmu.enterprise-auth.claims.roles=groups",
        "osmu.enterprise-auth.claims.organization=department",
        "osmu.enterprise-auth.claims.teams=teams",
        "osmu.enterprise-auth.allowed-domains=example.com,corp.example.com"
})
@AutoConfigureMockMvc
class AdminEnterpriseAuthPlanControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanReadEnterpriseAuthPlan() throws Exception {
        String accessToken = loginAndReturnAccessToken();

        mockMvc.perform(get("/api/admin/security/enterprise-auth-plan")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PLAN_READY"))
                .andExpect(jsonPath("$.data.currentLoginMode").value("LOCAL_PASSWORD"))
                .andExpect(jsonPath("$.data.activeLoginModes[*]", hasItem("LOCAL_PASSWORD")))
                .andExpect(jsonPath("$.data.plannedExternalModes[*]", hasItem("OIDC")))
                .andExpect(jsonPath("$.data.oidc.status").value("CONFIGURED"))
                .andExpect(jsonPath("$.data.claimMapping.roleClaim").value("groups"))
                .andExpect(jsonPath("$.data.claimMapping.organizationClaim").value("department"))
                .andExpect(jsonPath("$.data.claimMapping.teamClaim").value("teams"))
                .andExpect(jsonPath("$.data.claimMapping.allowedDomains[*]", hasItem("example.com")))
                .andExpect(jsonPath("$.data.roleMappings[*].osmuRole", hasItem("ADMIN")))
                .andExpect(jsonPath("$.data.gates[*].key", hasItem("login-cutover")));
    }

    @Test
    void enterpriseAuthPlanRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/api/admin/security/enterprise-auth-plan"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"));
    }

    @Test
    void adminCanPreviewOidcClaimsAndAuditSummaryIsRecorded() throws Exception {
        String accessToken = loginAndReturnAccessToken();

        mockMvc.perform(post("/api/admin/security/enterprise-auth/claim-preview")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "claims": {
                                    "sub": "oidc-admin-1",
                                    "email": "admin@example.com",
                                    "name": "Admin From IdP",
                                    "groups": ["osmu-admins"],
                                    "department": "platform",
                                    "teams": ["media", "ai"]
                                  }
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("MATCHED_EXISTING_USER"))
                .andExpect(jsonPath("$.data.email").value("admin@example.com"))
                .andExpect(jsonPath("$.data.roleClaimValues[*]", hasItem("osmu-admins")))
                .andExpect(jsonPath("$.data.mappedRoles[*]", hasItem("ADMIN")))
                .andExpect(jsonPath("$.data.primaryRole").value("ADMIN"))
                .andExpect(jsonPath("$.data.organizationClaimValue").value("platform"))
                .andExpect(jsonPath("$.data.teamClaimValues[*]", hasItem("media")))
                .andExpect(jsonPath("$.data.allowedDomainMatched").value(true))
                .andExpect(jsonPath("$.data.existingUser.loginId").value("admin"))
                .andExpect(jsonPath("$.data.jitProvisioningRequired").value(false))
                .andExpect(jsonPath("$.data.auditLogId").isNumber());

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + accessToken)
                        .param("eventType", "OIDC_CLAIM_PREVIEW"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.eventType == 'OIDC_CLAIM_PREVIEW' && @.targetId == 'admin@example.com')].result", hasItem("SUCCESS")));
    }

    @Test
    void adminCanProvisionOidcUserAndAuditSummaryIsRecorded() throws Exception {
        String accessToken = loginAndReturnAccessToken();

        mockMvc.perform(post("/api/admin/security/enterprise-auth/jit-provision")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "claims": {
                                    "sub": "oidc-user-2",
                                    "email": "jit.user@example.com",
                                    "name": "JIT User",
                                    "groups": ["external-users"]
                                  },
                                  "approvedRole": "USER",
                                  "approvePrivilegedRole": false,
                                  "reason": "pilot onboarding"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PROVISIONED"))
                .andExpect(jsonPath("$.data.user.loginId").value("jit.user"))
                .andExpect(jsonPath("$.data.user.email").value("jit.user@example.com"))
                .andExpect(jsonPath("$.data.user.role").value("USER"))
                .andExpect(jsonPath("$.data.preview.status").value("REQUIRES_ADMIN_APPROVAL"))
                .andExpect(jsonPath("$.data.approvedRole").value("USER"))
                .andExpect(jsonPath("$.data.auditLogId").isNumber());

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + accessToken)
                        .param("eventType", "OIDC_JIT_PROVISION"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.eventType == 'OIDC_JIT_PROVISION' && @.targetId == 'jit.user')].result", hasItem("SUCCESS")));
    }

    @Test
    void adminCannotProvisionPrivilegedOidcRoleWithoutExplicitApproval() throws Exception {
        String accessToken = loginAndReturnAccessToken();

        mockMvc.perform(post("/api/admin/security/enterprise-auth/jit-provision")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "claims": {
                                    "sub": "oidc-admin-2",
                                    "email": "jit.admin@example.com",
                                    "name": "JIT Admin",
                                    "groups": ["osmu-admins"]
                                  },
                                  "approvedRole": "ADMIN",
                                  "approvePrivilegedRole": false,
                                  "reason": "privileged import"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
    }

    private String loginAndReturnAccessToken() throws Exception {
        String response = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "admin",
                                  "password": "password"
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.accessToken");
    }
}
