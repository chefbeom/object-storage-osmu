package com.example.osmu.organization;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class AdminTeamControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanCreateListUpdateAndDeleteTeam() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int organizationId = createOrganization(adminToken, "Team API Org 1");
        int memberId = createUser(adminToken, "team-api-member-1", "team-api-member-1@example.com", "USER", organizationId);

        String teamResponse = mockMvc.perform(post("/api/admin/teams")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "organizationId": %d,
                                  "name": "Dataset Curators",
                                  "description": "dataset access team",
                                  "memberIds": [%d]
                                }
                                """.formatted(organizationId, memberId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Dataset Curators"))
                .andExpect(jsonPath("$.data.organizationId").value(organizationId))
                .andExpect(jsonPath("$.data.memberIds[*]", hasItem(memberId)))
                .andReturn()
                .getResponse()
                .getContentAsString();
        int teamId = JsonPath.read(teamResponse, "$.data.id");

        mockMvc.perform(get("/api/admin/teams")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("Dataset Curators")));

        mockMvc.perform(put("/api/admin/teams/{teamId}/members", teamId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "memberIds": []
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.memberIds").isEmpty());

        mockMvc.perform(delete("/api/admin/teams/{teamId}", teamId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/admin/teams")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", not(hasItem("Dataset Curators"))));
    }

    @Test
    void orgAdminCanManageOnlyOwnOrganizationTeams() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int ownOrg = createOrganization(adminToken, "Team Scope Org 1");
        int hiddenOrg = createOrganization(adminToken, "Team Hidden Org 1");
        int ownMemberId = createUser(adminToken, "team-scope-member-1", "team-scope-member-1@example.com", "USER", ownOrg);
        int hiddenMemberId = createUser(adminToken, "team-hidden-member-1", "team-hidden-member-1@example.com", "USER", hiddenOrg);
        createUser(adminToken, "team-scope-org-admin-1", "team-scope-org-admin-1@example.com", "ORG_ADMIN", ownOrg);
        String orgAdminToken = loginAndReturnAccessToken("team-scope-org-admin-1", "user-password");

        mockMvc.perform(post("/api/admin/teams")
                        .header("Authorization", "Bearer " + orgAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "organizationId": %d,
                                  "name": "Own Team",
                                  "description": "own org team",
                                  "memberIds": [%d]
                                }
                                """.formatted(ownOrg, ownMemberId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Own Team"));

        mockMvc.perform(post("/api/admin/teams")
                        .header("Authorization", "Bearer " + orgAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "organizationId": %d,
                                  "name": "Blocked Team",
                                  "description": "other org",
                                  "memberIds": [%d]
                                }
                                """.formatted(hiddenOrg, hiddenMemberId)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        mockMvc.perform(get("/api/admin/teams")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("Own Team")))
                .andExpect(jsonPath("$.items[*].name", not(hasItem("Blocked Team"))));
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
                                  "description": "team test org",
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
                                  "name": "Team User",
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
