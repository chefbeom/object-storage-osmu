package com.example.osmu.organization;

import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class AdminOrganizationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanCreateListAndAssignOrganizationToUser() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        String organizationResponse = mockMvc.perform(post("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "AI Research Team 1",
                                  "description": "AI dataset storage team",
                                  "defaultQuotaBytes": 1099511627776
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("AI Research Team 1"))
                .andExpect(jsonPath("$.data.defaultQuotaBytes").value(1099511627776L))
                .andReturn()
                .getResponse()
                .getContentAsString();

        int organizationId = JsonPath.read(organizationResponse, "$.data.id");

        mockMvc.perform(get("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("AI Research Team 1")));

        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "org-user-1",
                                  "email": "org-user-1@example.com",
                                  "name": "Org User One",
                                  "password": "user-password",
                                  "role": "USER",
                                  "organizationId": %d
                                }
                                """.formatted(organizationId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.loginId").value("org-user-1"))
                .andExpect(jsonPath("$.data.organizationId").value(organizationId));
    }

    @Test
    void createOrganizationRejectsDuplicateName() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Duplicate Org 1",
                                  "description": "first",
                                  "defaultQuotaBytes": 1048576
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Duplicate Org 1",
                                  "description": "second",
                                  "defaultQuotaBytes": 1048576
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("CONFLICT"));
    }

    @Test
    void adminCanDeleteEmptyOrganization() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int organizationId = createOrganization(adminToken, "Delete Empty Org 1");

        mockMvc.perform(put("/api/dashboard/layout/defaults")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "targetType": "ORGANIZATION",
                                  "targetId": "%d",
                                  "presetId": "compact"
                                }
                                """.formatted(organizationId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.targetType").value("ORGANIZATION"))
                .andExpect(jsonPath("$.data.targetId").value(String.valueOf(organizationId)));

        mockMvc.perform(put("/api/admin/quota-policies/ORGANIZATION/{targetId}", organizationId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "quotaBytes": 4096,
                                  "reason": "organization cleanup test"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.targetType").value("ORGANIZATION"))
                .andExpect(jsonPath("$.data.targetId").value(organizationId));

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "org-cleanup-permission-bucket",
                                  "quotaBytes": 1024,
                                  "ownerType": "USER"
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/buckets/{bucketName}/permissions", "org-cleanup-permission-bucket")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "subjectType": "ORGANIZATION",
                                  "subjectId": %d,
                                  "permissions": ["READ", "WRITE"]
                                }
                                """.formatted(organizationId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.subjectType == 'ORGANIZATION' && @.subjectId == %d)]".formatted(organizationId)).exists());

        mockMvc.perform(delete("/api/admin/organizations/{organizationId}", organizationId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", org.hamcrest.Matchers.not(hasItem("Delete Empty Org 1"))));

        mockMvc.perform(get("/api/dashboard/layout/defaults")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[?(@.targetType == 'ORGANIZATION' && @.targetId == '%d')]".formatted(organizationId)).isEmpty());

        mockMvc.perform(get("/api/admin/quota-policies")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.targetType == 'ORGANIZATION' && @.targetId == %d)]".formatted(organizationId)).isEmpty());

        mockMvc.perform(get("/api/admin/quota-policies/history")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.targetType == 'ORGANIZATION' && @.targetId == %d && @.action == 'DELETE')]".formatted(organizationId)).exists());

        mockMvc.perform(get("/api/buckets/{bucketName}/permissions", "org-cleanup-permission-bucket")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.subjectType == 'ORGANIZATION' && @.subjectId == %d)]".formatted(organizationId)).isEmpty());
    }

    @Test
    void deleteOrganizationRejectsAssignedUsersAndBuckets() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int userOrgId = createOrganization(adminToken, "Delete User Blocked Org 1");
        createUser(adminToken, "delete-block-user-1", "delete-block-user-1@example.com", "USER", userOrgId);

        mockMvc.perform(delete("/api/admin/organizations/{organizationId}", userOrgId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("CONFLICT"));

        int bucketOrgId = createOrganization(adminToken, "Delete Bucket Blocked Org 1");
        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "delete-blocked-org-bucket",
                                  "quotaBytes": 1024,
                                  "ownerType": "ORG",
                                  "ownerId": %d
                                }
                                """.formatted(bucketOrgId)))
                .andExpect(status().isOk());

        mockMvc.perform(delete("/api/admin/organizations/{organizationId}", bucketOrgId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("CONFLICT"));
    }

    @Test
    void organizationUsageAggregatesOrgBuckets() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        String organizationResponse = mockMvc.perform(post("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Usage Org 1",
                                  "description": "usage target",
                                  "defaultQuotaBytes": 2048
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        int organizationId = JsonPath.read(organizationResponse, "$.data.id");

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "usage-org-bucket",
                                  "quotaBytes": 1024,
                                  "ownerType": "ORG",
                                  "ownerId": %d
                                }
                                """.formatted(organizationId)))
                .andExpect(status().isOk());

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "usage.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "usage-data".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "usage-org-bucket")
                        .file(file)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("key", "usage.txt"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/admin/organizations/usage")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.name == 'Usage Org 1')].bucketCount", hasItem(1)))
                .andExpect(jsonPath("$.items[?(@.name == 'Usage Org 1')].objectCount", hasItem(1)))
                .andExpect(jsonPath("$.items[?(@.name == 'Usage Org 1')].usedBytes", hasItem(10)))
                .andExpect(jsonPath("$.items[?(@.name == 'Usage Org 1')].bucketQuotaBytes", hasItem(1024)));
    }

    @Test
    void orgAdminSeesOnlyOwnOrganizationAndUsage() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int ownOrg = createOrganization(adminToken, "Visible Org 1");
        createOrganization(adminToken, "Hidden Org 1");
        createUser(adminToken, "visible-org-admin-1", "visible-org-admin-1@example.com", "ORG_ADMIN", ownOrg);
        String orgAdminToken = loginAndReturnAccessToken("visible-org-admin-1", "user-password");

        mockMvc.perform(get("/api/admin/organizations")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("Visible Org 1")))
                .andExpect(jsonPath("$.items[*].name", org.hamcrest.Matchers.not(hasItem("Hidden Org 1"))));

        mockMvc.perform(get("/api/admin/organizations/usage")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("Visible Org 1")))
                .andExpect(jsonPath("$.items[*].name", org.hamcrest.Matchers.not(hasItem("Hidden Org 1"))));

        mockMvc.perform(post("/api/admin/organizations")
                        .header("Authorization", "Bearer " + orgAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Blocked Org Create 1",
                                  "description": "blocked",
                                  "defaultQuotaBytes": 1024
                                }
                                """))
                .andExpect(status().isForbidden());
    }

    private String loginAndReturnAccessToken(String loginId, String password) throws Exception {
        String response = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "password": "%s"
                                }
                                """.formatted(loginId, password)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(response, "$.data.accessToken");
    }

    private int createOrganization(String adminToken, String name) throws Exception {
        String response = mockMvc.perform(post("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "description": "org scope",
                                  "defaultQuotaBytes": 1099511627776
                                }
                                """.formatted(name)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.id");
    }

    private void createUser(String adminToken, String loginId, String email, String role, int organizationId) throws Exception {
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s",
                                  "name": "Org Scoped User",
                                  "password": "user-password",
                                  "role": "%s",
                                  "organizationId": %d
                                }
                                """.formatted(loginId, email, role, organizationId)))
                .andExpect(status().isOk());
    }
}
