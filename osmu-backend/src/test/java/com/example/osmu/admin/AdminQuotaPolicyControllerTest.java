package com.example.osmu.admin;

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
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class AdminQuotaPolicyControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanManageUserQuotaPolicy() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int userId = createUser(adminToken, "quota-policy-user-1", "quota-policy-user-1@example.com");

        mockMvc.perform(put("/api/admin/quota-policies/USER/{targetId}", userId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "quotaBytes": 4096,
                                  "reason": "initial pilot quota"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.targetType").value("USER"))
                .andExpect(jsonPath("$.data.targetId").value(userId))
                .andExpect(jsonPath("$.data.quotaBytes").value(4096))
                .andExpect(jsonPath("$.data.usedBytes").value(0))
                .andExpect(jsonPath("$.data.remainingBytes").value(4096));

        mockMvc.perform(put("/api/admin/quota-policies/USER/{targetId}", userId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "quotaBytes": 8192,
                                  "reason": "increase for media workload"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.quotaBytes").value(8192));

        mockMvc.perform(get("/api/admin/quota-policies")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].targetType").value(hasItem("USER")))
                .andExpect(jsonPath("$.items[*].targetId").value(hasItem(userId)));

        mockMvc.perform(delete("/api/admin/quota-policies/USER/{targetId}", userId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("reason", "pilot cleanup"))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/admin/quota-policies")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].targetId").value(not(hasItem(userId))));

        mockMvc.perform(get("/api/admin/quota-policies/history")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].targetType").value("USER"))
                .andExpect(jsonPath("$.items[0].targetId").value(userId))
                .andExpect(jsonPath("$.items[0].action").value("DELETE"))
                .andExpect(jsonPath("$.items[0].previousQuotaBytes").value(8192))
                .andExpect(jsonPath("$.items[0].actorId").value("admin"))
                .andExpect(jsonPath("$.items[0].reason").value("pilot cleanup"))
                .andExpect(jsonPath("$.items[1].action").value("UPDATE"))
                .andExpect(jsonPath("$.items[1].previousQuotaBytes").value(4096))
                .andExpect(jsonPath("$.items[1].newQuotaBytes").value(8192))
                .andExpect(jsonPath("$.items[1].reason").value("increase for media workload"))
                .andExpect(jsonPath("$.items[2].action").value("CREATE"))
                .andExpect(jsonPath("$.items[2].newQuotaBytes").value(4096))
                .andExpect(jsonPath("$.items[2].reason").value("initial pilot quota"));
    }

    private int createUser(String adminToken, String loginId, String email) throws Exception {
        String response = mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s",
                                  "name": "Quota Target",
                                  "password": "user-password",
                                  "role": "USER",
                                  "organizationId": null
                                }
                                """.formatted(loginId, email)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.id");
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
}
