package com.example.osmu.bucket;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jayway.jsonpath.JsonPath;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class BucketVersioningControllerTest {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanReadAndUpdateBucketVersioning() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "versioning-api-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(get("/api/buckets/{bucketName}/versioning", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.bucketName").value(bucketName))
                .andExpect(jsonPath("$.data.status").value("SUSPENDED"))
                .andExpect(jsonPath("$.data.storageBacked").value(true))
                .andExpect(jsonPath("$.data.scopePolicy").value(org.hamcrest.Matchers.containsString("not AWS S3 versioning parity")));

        mockMvc.perform(put("/api/buckets/{bucketName}/versioning", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(OBJECT_MAPPER.writeValueAsString(Map.of("status", "ENABLED"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.bucketName").value(bucketName))
                .andExpect(jsonPath("$.data.status").value("ENABLED"));

        mockMvc.perform(get("/api/buckets/{bucketName}/versioning", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ENABLED"));

        mockMvc.perform(put("/api/buckets/{bucketName}/versioning", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(OBJECT_MAPPER.writeValueAsString(Map.of("status", "suspended"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("SUSPENDED"));

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + token)
                        .param("eventType", "BUCKET_VERSIONING_UPDATE")
                        .param("targetId", bucketName)
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].actorId").value("admin"))
                .andExpect(jsonPath("$.items[0].message").value(org.hamcrest.Matchers.containsString("SUSPENDED")));
    }

    @Test
    void invalidBucketVersioningStatusReturnsValidationError() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "versioning-invalid-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/buckets/{bucketName}/versioning", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(OBJECT_MAPPER.writeValueAsString(Map.of("status", "DISABLED"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.message").value("Bucket versioning status must be ENABLED or SUSPENDED."));
    }

    @Test
    void userWithoutBucketManagePermissionCannotReadOrUpdateVersioning() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        createUser(adminToken, "versioning-user", "versioning-user@example.com");
        String userToken = loginAndReturnAccessToken("versioning-user", "user-password");
        String bucketName = "versioning-denied-bucket";
        createBucket(adminToken, bucketName);

        mockMvc.perform(get("/api/buckets/{bucketName}/versioning", bucketName)
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        mockMvc.perform(put("/api/buckets/{bucketName}/versioning", bucketName)
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(OBJECT_MAPPER.writeValueAsString(Map.of("status", "ENABLED"))))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));
    }

    private void createBucket(String token, String bucketName) throws Exception {
        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "quotaBytes": 1073741824
                                }
                                """.formatted(bucketName)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value(bucketName));
    }

    private void createUser(String adminToken, String loginId, String email) throws Exception {
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s",
                                  "name": "Versioning User",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """.formatted(loginId, email)))
                .andExpect(status().isOk());
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
