package com.example.osmu.admin;

import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
class AdminBackupStatusControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanReadBackupStatus() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/backup/status")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("DRILL_PENDING"))
                .andExpect(jsonPath("$.data.metadataStore").value("in-memory"))
                .andExpect(jsonPath("$.data.objectStore").value("in-memory"))
                .andExpect(jsonPath("$.data.databaseHealthy").value(true))
                .andExpect(jsonPath("$.data.storageHealthy").value(true))
                .andExpect(jsonPath("$.data.rpoTarget").value("24h"))
                .andExpect(jsonPath("$.data.rtoTarget").value("4h"))
                .andExpect(jsonPath("$.data.runbookAvailable").value(true))
                .andExpect(jsonPath("$.data.restoreDrillExecuted").value(false))
                .andExpect(jsonPath("$.data.pendingGates").value(hasItem("MariaDB metadata mode is not enabled.")))
                .andExpect(jsonPath("$.data.pendingGates").value(hasItem("MinIO object storage mode is not enabled.")))
                .andExpect(jsonPath("$.data.pendingGates").value(hasItem("Restore drill has not been executed in this runtime.")));
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
