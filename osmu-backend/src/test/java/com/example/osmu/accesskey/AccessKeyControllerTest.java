package com.example.osmu.accesskey;

import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.emptyString;
import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
class AccessKeyControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void createAccessKeyShowsSecretOnlyInCreateResponse() throws Exception {
        String accessToken = loginAndReturnAccessToken("admin", "password");
        createBucket(accessToken, "key-scope-bucket");

        mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "integration-key",
                                  "allowedBuckets": ["key-scope-bucket"],
                                  "permissions": ["READ", "WRITE"],
                                  "expiresAt": null
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessKey", not(emptyString())))
                .andExpect(jsonPath("$.data.secretKey", not(emptyString())))
                .andExpect(jsonPath("$.data.policyName", not(emptyString())))
                .andExpect(jsonPath("$.data.policyDocument").value(org.hamcrest.Matchers.containsString("arn:aws:s3:::key-scope-bucket/*")))
                .andExpect(jsonPath("$.data.policyDocument").value(org.hamcrest.Matchers.containsString("s3:GetObject")))
                .andExpect(jsonPath("$.data.policyDocument").value(org.hamcrest.Matchers.containsString("s3:PutObject")))
                .andExpect(jsonPath("$.data.allowedBuckets[0]").value("key-scope-bucket"))
                .andExpect(jsonPath("$.data.permissions[*]", hasItem("READ")))
                .andExpect(jsonPath("$.data.permissions[*]", hasItem("WRITE")));

        mockMvc.perform(get("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("integration-key")))
                .andExpect(jsonPath("$.items[0].secretKey").doesNotExist())
                .andExpect(jsonPath("$.items[0].secretKeyHash").doesNotExist())
                .andExpect(jsonPath("$.items[0].policyName", not(emptyString())))
                .andExpect(jsonPath("$.items[*].allowedBuckets[0]", hasItem("key-scope-bucket")))
                .andExpect(jsonPath("$.items[*].permissions[*]", hasItem("READ")));
    }

    @Test
    void userSeesOnlyOwnAccessKeys() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        createBucket(adminToken, "admin-key-bucket");
        createUser(adminToken, "key-user-1", "key-user-1@example.com");
        String userToken = loginAndReturnAccessToken("key-user-1", "user-password");
        createBucket(userToken, "user-key-bucket");

        mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "admin-key",
                                  "allowedBuckets": ["admin-key-bucket"],
                                  "expiresAt": null
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "user-key",
                                  "allowedBuckets": ["user-key-bucket"],
                                  "expiresAt": null
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/access-keys")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("user-key")))
                .andExpect(jsonPath("$.items[*].name", not(hasItem("admin-key"))));
    }

    @Test
    void userCannotCreateAccessKeyForOtherUsersBucket() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        createBucket(adminToken, "access-key-admin-private-bucket");
        createUser(adminToken, "key-user-2", "key-user-2@example.com");
        String userToken = loginAndReturnAccessToken("key-user-2", "user-password");

        mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "invalid-scope",
                                  "allowedBuckets": ["access-key-admin-private-bucket"],
                                  "permissions": ["READ"],
                                  "expiresAt": null
                                }
                                """))
                .andExpect(status().isForbidden());
    }

    private void createUser(String adminToken, String loginId, String email) throws Exception {
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s",
                                  "name": "Key User",
                                  "password": "user-password",
                                  "role": "USER"
                                }
                                """.formatted(loginId, email)))
                .andExpect(status().isOk());
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
