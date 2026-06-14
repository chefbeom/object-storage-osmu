package com.example.osmu.admin;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class AdminObjectSharePolicyControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanManageObjectSharePolicyAndPolicyIsEnforced() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/object-share-policy")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requirePassword").value(false))
                .andExpect(jsonPath("$.data.requireIpAllowlist").value(false))
                .andExpect(jsonPath("$.data.maxExpiresSeconds").value(604800))
                .andExpect(jsonPath("$.data.maxDownloadsLimit").doesNotExist());

        mockMvc.perform(put("/api/admin/object-share-policy")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "requirePassword": true,
                                  "requireIpAllowlist": true,
                                  "maxExpiresSeconds": 120,
                                  "maxDownloadsLimit": 2,
                                  "reason": "secure pilot links"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requirePassword").value(true))
                .andExpect(jsonPath("$.data.requireIpAllowlist").value(true))
                .andExpect(jsonPath("$.data.maxExpiresSeconds").value(120))
                .andExpect(jsonPath("$.data.maxDownloadsLimit").value(2));

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("eventType", "OBJECT_SHARE_POLICY_SAVE")
                        .param("targetType", "OBJECT_SHARE_POLICY")
                        .param("targetId", "global")
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].actorId").value("admin"));

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "share-policy-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk());

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "policy.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "policy object".getBytes()
        );

        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "share-policy-bucket")
                        .file(file)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("key", "policy.txt"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/share-links", "share-policy-bucket")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "key": "policy.txt",
                                  "expiresInSeconds": 120,
                                  "maxDownloads": 1
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/share-links", "share-policy-bucket")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "key": "policy.txt",
                                  "expiresInSeconds": 120,
                                  "password": "SharePass!23",
                                  "allowedIpCidrs": "203.0.113.0/24",
                                  "maxDownloads": 3
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/share-links", "share-policy-bucket")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "key": "policy.txt",
                                  "expiresInSeconds": 120,
                                  "password": "SharePass!23",
                                  "allowedIpCidrs": "203.0.113.0/24"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.passwordProtected").value(true))
                .andExpect(jsonPath("$.data.ipRestricted").value(true))
                .andExpect(jsonPath("$.data.maxDownloads").value(2));

        mockMvc.perform(get("/api/admin/object-share-analytics")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("limit", "5")
                        .param("bucketName", "share-policy-bucket")
                        .param("status", "ACTIVE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalLinks").value(1))
                .andExpect(jsonPath("$.data.activeLinks").value(1))
                .andExpect(jsonPath("$.data.passwordProtectedLinks").value(1))
                .andExpect(jsonPath("$.data.ipRestrictedLinks").value(1))
                .andExpect(jsonPath("$.data.totalDownloads").value(0))
                .andExpect(jsonPath("$.data.recentLinks[0].key").value("policy.txt"))
                .andExpect(jsonPath("$.data.recentLinks[0].token").doesNotExist())
                .andExpect(jsonPath("$.data.recentLinks[0].url").doesNotExist());

        mockMvc.perform(get("/api/admin/object-share-analytics")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("status", "BROKEN"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
    }

    private String loginAndReturnAccessToken(String loginId, String password) throws Exception {
        return com.jayway.jsonpath.JsonPath.read(mockMvc.perform(post("/api/auth/login")
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
                .getContentAsString(), "$.data.accessToken");
    }
}
