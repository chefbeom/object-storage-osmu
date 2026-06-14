package com.example.osmu.user;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class AdminUserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanCreateListAndDisableUser() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        String createResponse = mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "api-user-1",
                                  "email": "api-user-1@example.com",
                                  "name": "API User One",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.loginId").value("api-user-1"))
                .andExpect(jsonPath("$.data.passwordHash").doesNotExist())
                .andReturn()
                .getResponse()
                .getContentAsString();

        int userId = JsonPath.read(createResponse, "$.data.id");

        mockMvc.perform(get("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()", greaterThanOrEqualTo(2)))
                .andExpect(jsonPath("$.items[*].loginId", hasItem("api-user-1")));

        String userLoginResponse = loginAndReturnResponse("api-user-1", "user-password");
        String userToken = JsonPath.read(userLoginResponse, "$.data.accessToken");
        String userRefreshToken = JsonPath.read(userLoginResponse, "$.data.refreshToken");
        createBucket(userToken, "inactive-user-bucket");
        mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "disabled-user-key",
                                  "allowedBuckets": ["inactive-user-bucket"],
                                  "permissions": ["READ"],
                                  "expiresAt": null
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(patch("/api/admin/users/{userId}/status", userId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "INACTIVE"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("INACTIVE"));

        mockMvc.perform(get("/api/access-keys")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.name == 'disabled-user-key')].status", hasItem("INACTIVE")));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "api-user-1",
                                  "password": "user-password"
                                }
                                """))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "%s"
                                }
                                """.formatted(userRefreshToken)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void createUserRejectsDuplicateLoginId() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "admin",
                                  "email": "duplicate-admin@example.com",
                                  "name": "Duplicate Admin",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("CONFLICT"));
    }

    @Test
    void adminApiRejectsUserRole() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "limited-user-1",
                                  "email": "limited-user-1@example.com",
                                  "name": "Limited User One",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """))
                .andExpect(status().isOk());

        String userToken = loginAndReturnAccessToken("limited-user-1", "user-password");

        mockMvc.perform(get("/api/admin/users")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));
    }

    @Test
    void orgAdminCanManageOnlyOwnOrganizationUsers() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int orgA = createOrganization(adminToken, "Org Admin Scope A");
        int orgB = createOrganization(adminToken, "Org Admin Scope B");
        createUser(adminToken, "scope-org-admin-a", "scope-org-admin-a@example.com", "ORG_ADMIN", orgA);
        int orgUserA = createUser(adminToken, "scope-user-a", "scope-user-a@example.com", "USER", orgA);
        int orgUserB = createUser(adminToken, "scope-user-b", "scope-user-b@example.com", "USER", orgB);
        String orgAdminToken = loginAndReturnAccessToken("scope-org-admin-a", "user-password");

        mockMvc.perform(get("/api/admin/users")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].loginId", hasItem("scope-user-a")))
                .andExpect(jsonPath("$.items[*].loginId", hasItem("scope-org-admin-a")))
                .andExpect(jsonPath("$.items[*].loginId", org.hamcrest.Matchers.not(hasItem("scope-user-b"))));

        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + orgAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "scope-created-by-org-admin",
                                  "email": "scope-created-by-org-admin@example.com",
                                  "name": "Scoped Created User",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.organizationId").value(orgA));

        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + orgAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "scope-invalid-role",
                                  "email": "scope-invalid-role@example.com",
                                  "name": "Invalid Role",
                                  "password": "user-password",
                                  "role": "ORG_ADMIN"
                                }
                                """))
                .andExpect(status().isForbidden());

        mockMvc.perform(patch("/api/admin/users/{userId}/status", orgUserA)
                        .header("Authorization", "Bearer " + orgAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "INACTIVE"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("INACTIVE"));

        mockMvc.perform(patch("/api/admin/users/{userId}/status", orgUserB)
                        .header("Authorization", "Bearer " + orgAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "INACTIVE"
                                }
                                """))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void userAuditLogUsesAuthenticatedAdminActor() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "audit-admin-1",
                                  "email": "audit-admin-1@example.com",
                                  "name": "Audit Admin One",
                                  "password": "admin-password",
                                  "role": "ADMIN"
                                }
                                """))
                .andExpect(status().isOk());

        String auditAdminToken = loginAndReturnAccessToken("audit-admin-1", "admin-password");
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + auditAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "audit-created-user-1",
                                  "email": "audit-created-user-1@example.com",
                                  "name": "Audit Created User One",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + auditAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.eventType == 'USER_CREATE' && @.actorId == 'audit-admin-1' && @.targetId == 'audit-created-user-1')].result", hasItem("SUCCESS")));
    }

    @Test
    void auditLogsCanBeFilteredByEventTypeActorAndLimit() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        MvcResult createUserResult = mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .header("X-Request-Id", "req-audit-filter-user-1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "audit-filter-user-1",
                                  "email": "audit-filter-user-1@example.com",
                                  "name": "Audit Filter User One",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn();
        String requestId = createUserResult.getResponse().getHeader("X-Request-Id");

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("eventType", "USER_CREATE")
                        .param("actorId", "admin")
                        .param("requestId", requestId)
                        .param("targetType", "USER")
                        .param("targetId", "audit-filter-user-1")
                        .param("result", "SUCCESS")
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()", is(1)))
                .andExpect(jsonPath("$.items[*].eventType", everyItem(is("USER_CREATE"))))
                .andExpect(jsonPath("$.items[*].actorId", everyItem(is("admin"))))
                .andExpect(jsonPath("$.items[*].requestId", everyItem(is(requestId))))
                .andExpect(jsonPath("$.items[*].targetType", everyItem(is("USER"))))
                .andExpect(jsonPath("$.items[*].targetId", everyItem(is("audit-filter-user-1"))))
                .andExpect(jsonPath("$.items[*].result", everyItem(is("SUCCESS"))));
    }

    @Test
    void auditLogsCanBeExportedAsCsvWithFilters() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "audit-export-user-1",
                                  "email": "audit-export-user-1@example.com",
                                  "name": "Audit Export, User",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/admin/audit-logs/export.csv")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("eventType", "USER_CREATE")
                        .param("actorId", "admin")
                        .param("targetType", "USER")
                        .param("targetId", "audit-export-user-1")
                        .param("result", "SUCCESS")
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Disposition", "attachment; filename=\"osmu-audit-logs.csv\""))
                .andExpect(content().contentTypeCompatibleWith(MediaType.parseMediaType("text/csv")))
                .andExpect(content().string(containsString("id,eventType,actorId,targetType,targetId,result,message,ipAddress,userAgent,requestId,createdAt")))
                .andExpect(content().string(containsString("USER_CREATE,admin,USER,audit-export-user-1,SUCCESS")));
    }

    @Test
    void auditLogsReturnNextCursorForPagination() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "audit-cursor-user-1",
                                  "email": "audit-cursor-user-1@example.com",
                                  "name": "Audit Cursor User One",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "audit-cursor-user-2",
                                  "email": "audit-cursor-user-2@example.com",
                                  "name": "Audit Cursor User Two",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """))
                .andExpect(status().isOk());

        String firstPage = mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("eventType", "USER_CREATE")
                        .param("actorId", "admin")
                        .param("targetType", "USER")
                        .param("result", "SUCCESS")
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()", is(1)))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String nextCursor = JsonPath.read(firstPage, "$.nextCursor");
        int firstPageId = JsonPath.read(firstPage, "$.items[0].id");
        assertNotNull(nextCursor);

        String secondPage = mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("eventType", "USER_CREATE")
                        .param("actorId", "admin")
                        .param("targetType", "USER")
                        .param("result", "SUCCESS")
                        .param("cursor", nextCursor)
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()", is(1)))
                .andReturn()
                .getResponse()
                .getContentAsString();

        int secondPageId = JsonPath.read(secondPage, "$.items[0].id");
        assertTrue(secondPageId < firstPageId);
    }

    private String loginAndReturnAccessToken(String loginId, String password) throws Exception {
        return JsonPath.read(loginAndReturnResponse(loginId, password), "$.data.accessToken");
    }

    private String loginAndReturnResponse(String loginId, String password) throws Exception {
        return mockMvc.perform(post("/api/auth/login")
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
    }

    private void createBucket(String accessToken, String name) throws Exception {
        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "quotaBytes": 1048576
                                }
                                """.formatted(name)))
                .andExpect(status().isOk());
    }

    private int createOrganization(String adminToken, String name) throws Exception {
        String response = mockMvc.perform(post("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "description": "scope test",
                                  "defaultQuotaBytes": 1099511627776
                                }
                                """.formatted(name)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.id");
    }

    private int createUser(String adminToken, String loginId, String email, String role, int organizationId) throws Exception {
        String response = mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s",
                                  "name": "Scoped User",
                                  "password": "user-password",
                                  "role": "%s",
                                  "organizationId": %d
                                }
                                """.formatted(loginId, email, role, organizationId)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.id");
    }
}
