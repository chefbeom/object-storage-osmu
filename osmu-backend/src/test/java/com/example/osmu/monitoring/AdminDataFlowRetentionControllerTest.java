package com.example.osmu.monitoring;

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
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class AdminDataFlowRetentionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanReadDataFlowRetentionStatus() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/retention/status")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DATA_FLOW_RETENTION"))
                .andExpect(jsonPath("$.data.eventRetention.enabled").value(true))
                .andExpect(jsonPath("$.data.eventRetention.jobAvailable").value(true))
                .andExpect(jsonPath("$.data.eventRetention.retentionDays").value(90))
                .andExpect(jsonPath("$.data.eventRetention.batchSize").value(1000))
                .andExpect(jsonPath("$.data.eventRetention.deletedCount").isNumber())
                .andExpect(jsonPath("$.data.eventRetention.failedRunCount").isNumber())
                .andExpect(jsonPath("$.data.dailyRollupRetention.enabled").value(true))
                .andExpect(jsonPath("$.data.dailyRollupRetention.jobAvailable").value(true))
                .andExpect(jsonPath("$.data.dailyRollupRetention.retentionDays").value(1095))
                .andExpect(jsonPath("$.data.dailyRollupRetention.batchSize").value(1000))
                .andExpect(jsonPath("$.data.dailyRollupRetention.deletedCount").isNumber())
                .andExpect(jsonPath("$.data.dailyRollupRetention.failedRunCount").isNumber())
                .andExpect(jsonPath("$.data.monthlyRollupRetention.enabled").value(true))
                .andExpect(jsonPath("$.data.monthlyRollupRetention.jobAvailable").value(true))
                .andExpect(jsonPath("$.data.monthlyRollupRetention.retentionDays").value(1825))
                .andExpect(jsonPath("$.data.monthlyRollupRetention.batchSize").value(1000))
                .andExpect(jsonPath("$.data.monthlyRollupRetention.deletedCount").isNumber())
                .andExpect(jsonPath("$.data.monthlyRollupRetention.failedRunCount").isNumber())
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanRunDataFlowRetention() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/monitoring/data-flow/retention/run")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DATA_FLOW_RETENTION"))
                .andExpect(jsonPath("$.data.deletedEventCount").isNumber())
                .andExpect(jsonPath("$.data.deletedDailyRollupCount").isNumber())
                .andExpect(jsonPath("$.data.deletedMonthlyRollupCount").isNumber())
                .andExpect(jsonPath("$.data.status.mode").value("DATA_FLOW_RETENTION"))
                .andExpect(jsonPath("$.data.status.eventRetention.enabled").value(true))
                .andExpect(jsonPath("$.data.status.dailyRollupRetention.enabled").value(true))
                .andExpect(jsonPath("$.data.status.monthlyRollupRetention.enabled").value(true))
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanRunOnlyDailyRollupRetention() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/monitoring/data-flow/retention/run")
                        .param("includeEvents", "false")
                        .param("includeDailyRollups", "true")
                        .param("includeMonthlyRollups", "false")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deletedEventCount").value(0))
                .andExpect(jsonPath("$.data.deletedMonthlyRollupCount").value(0))
                .andExpect(jsonPath("$.data.deletedDailyRollupCount").isNumber())
                .andExpect(jsonPath("$.data.status.dailyRollupRetention.jobAvailable").value(true));
    }

    @Test
    void adminCanRunOnlyMonthlyRollupRetention() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/monitoring/data-flow/retention/run")
                        .param("includeEvents", "false")
                        .param("includeDailyRollups", "false")
                        .param("includeMonthlyRollups", "true")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deletedEventCount").value(0))
                .andExpect(jsonPath("$.data.deletedDailyRollupCount").value(0))
                .andExpect(jsonPath("$.data.deletedMonthlyRollupCount").isNumber())
                .andExpect(jsonPath("$.data.status.monthlyRollupRetention.jobAvailable").value(true));
    }

    @Test
    void retentionRunRequiresAtLeastOneTarget() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/monitoring/data-flow/retention/run")
                        .param("includeEvents", "false")
                        .param("includeDailyRollups", "false")
                        .param("includeMonthlyRollups", "false")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
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
