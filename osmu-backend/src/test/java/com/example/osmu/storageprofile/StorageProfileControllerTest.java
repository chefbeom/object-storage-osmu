package com.example.osmu.storageprofile;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class StorageProfileControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void bucketOwnerCanRequestAndAdminCanApplyStorageProfile() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        String suffix = String.valueOf(System.nanoTime());
        String loginId = "profile-owner-" + suffix;
        String bucketName = "profile-bucket-" + suffix;

        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s@example.com",
                                  "name": "Profile Owner",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """.formatted(loginId, loginId)))
                .andExpect(status().isOk());

        String userToken = loginAndReturnAccessToken(loginId, "user-password");

        mockMvc.perform(get("/api/storage-profiles")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].code", hasItem("PERFORMANCE")))
                .andExpect(jsonPath("$.items[*].code", hasItem("STANDARD")))
                .andExpect(jsonPath("$.items[*].code", hasItem("DURABLE")))
                .andExpect(jsonPath("$.items[?(@.code == 'PERFORMANCE')].alias", hasItem("RAID0-like")))
                .andExpect(jsonPath("$.items[?(@.code == 'DURABLE')].alias", hasItem("High Parity")));

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "quotaBytes": 1073741824
                                }
                                """.formatted(bucketName)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/buckets/{bucketName}/storage-profile", bucketName)
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.assignment.profile.code").value("STANDARD"))
                .andExpect(jsonPath("$.data.assignment.defaultProfile").value(true))
                .andExpect(jsonPath("$.data.latestRequest").value(nullValue()));

        mockMvc.perform(post("/api/buckets/{bucketName}/storage-profile-requests", bucketName)
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "requestedProfile": "PERFORMANCE",
                                  "reason": "video ingest needs RAID0-like throughput"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.bucketName").value(bucketName))
                .andExpect(jsonPath("$.data.currentProfile.code").value("STANDARD"))
                .andExpect(jsonPath("$.data.requestedProfile.code").value("PERFORMANCE"))
                .andExpect(jsonPath("$.data.requestedProfile.riskLevel").value("HIGH"))
                .andExpect(jsonPath("$.data.status").value("PENDING"))
                .andExpect(jsonPath("$.data.requestedBy").value(loginId));

        String listResponse = mockMvc.perform(get("/api/admin/storage-profile-requests")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].bucketName", hasItem(bucketName)))
                .andReturn()
                .getResponse()
                .getContentAsString();
        List<Integer> requestIds = JsonPath.read(listResponse, "$.items[?(@.bucketName == '" + bucketName + "')].id");
        int requestId = requestIds.get(0);

        mockMvc.perform(patch("/api/admin/storage-profile-requests/{requestId}/status", requestId)
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "APPROVED"
                                }
                                """))
                .andExpect(status().isForbidden());

        mockMvc.perform(patch("/api/admin/storage-profile-requests/{requestId}/status", requestId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "APPROVED",
                                  "adminNote": "approved for temporary media pool"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(requestId))
                .andExpect(jsonPath("$.data.status").value("APPROVED"))
                .andExpect(jsonPath("$.data.approvedBy").value("admin"))
                .andExpect(jsonPath("$.data.adminNote").value("approved for temporary media pool"));

        mockMvc.perform(post("/api/admin/storage-profile-requests/{requestId}/apply", requestId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(requestId))
                .andExpect(jsonPath("$.data.status").value("APPLIED"))
                .andExpect(jsonPath("$.data.appliedBy").value("admin"));

        mockMvc.perform(get("/api/buckets/{bucketName}/storage-profile", bucketName)
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.assignment.profile.code").value("PERFORMANCE"))
                .andExpect(jsonPath("$.data.assignment.profile.alias").value("RAID0-like"))
                .andExpect(jsonPath("$.data.assignment.defaultProfile").value(false))
                .andExpect(jsonPath("$.data.latestRequest.status").value("APPLIED"));

        mockMvc.perform(post("/api/buckets/{bucketName}/storage-profile-requests", bucketName)
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "requestedProfile": "PERFORMANCE",
                                  "reason": "same profile"
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
