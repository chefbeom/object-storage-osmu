package com.example.osmu.storagelayout;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
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
class AdminStorageLayoutControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanPlanApproveAndSimulatePvcStorageLayout() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/storage-layouts/capabilities")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[*].code", hasItem("JBOD")))
                .andExpect(jsonPath("$.data[*].code", hasItem("RAID6")))
                .andExpect(jsonPath("$.data[*].code", hasItem("RAID10")));

        String createdResponse = mockMvc.perform(post("/api/admin/storage-layouts/plans")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "layoutCode": "RAID6",
                                  "storageClassName": "osmu-storage",
                                  "serverCount": 4,
                                  "volumesPerServer": 1,
                                  "volumeSizeGiB": 1024,
                                  "reason": "durable PVC pool plan"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.layout.code").value("RAID6"))
                .andExpect(jsonPath("$.data.pvcCount").value(4))
                .andExpect(jsonPath("$.data.status").value("PLANNED"))
                .andExpect(jsonPath("$.data.simulationOnly").value(true))
                .andExpect(jsonPath("$.data.preflight.result").value("SIMULATION_READY"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        int planId = JsonPath.read(createdResponse, "$.data.id");
        mockMvc.perform(patch("/api/admin/storage-layouts/plans/{planId}/status", planId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "APPROVED"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-layouts/plans/{planId}/simulate", planId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.plan.preflight.checks[?(@.code == 'STORAGE_CLASS')].result", hasItem("UNVERIFIED")))
                .andExpect(jsonPath("$.data.plan.preflight.checks[?(@.code == 'MINIO_POOL')].result", hasItem("PLANNED")))
                .andExpect(jsonPath("$.data.manifestPreview", containsString("clusterMutation: disabled")));


        mockMvc.perform(patch("/api/admin/storage-layouts/plans/{planId}/status", planId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "APPROVED",
                                  "adminNote": "target StorageClass validation remains required"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"))
                .andExpect(jsonPath("$.data.approvedBy").value("admin"));

        mockMvc.perform(post("/api/admin/storage-layouts/plans/{planId}/simulate", planId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DEVELOPMENT_SIMULATION"))
                .andExpect(jsonPath("$.data.plan.simulatedBy").value("admin"))
                .andExpect(jsonPath("$.data.plan.preflight.checks[?(@.code == 'CLUSTER_MUTATION')].result", hasItem("SIMULATED")))
                .andExpect(jsonPath("$.data.manifestPreview", containsString("clusterMutation: disabled")));
    }

    @Test
    void invalidStorageLayoutTopologyIsRejected() throws Exception {
        mockMvc.perform(get("/api/admin/storage-layouts/capabilities"))
                .andExpect(status().isUnauthorized());

        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/storage-layouts/plans")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "layoutCode": "RAID10",
                                  "storageClassName": "osmu-storage",
                                  "serverCount": 3,
                                  "volumesPerServer": 1,
                                  "volumeSizeGiB": 100
                                }
                                """))
                .andExpect(status().isBadRequest());
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
