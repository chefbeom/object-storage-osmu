package com.example.osmu.accesskey;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.emptyString;
import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

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

    @Test
    void accessKeyListShowsUsageCountAndLastUsedAtAfterS3Request() throws Exception {
        String accessToken = loginAndReturnAccessToken("admin", "password");
        createBucket(accessToken, "key-last-used-bucket");

        MvcResult createResult = mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "last-used-key",
                                  "allowedBuckets": ["key-last-used-bucket"],
                                  "permissions": ["READ", "WRITE"],
                                  "expiresAt": null
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn();
        String createBody = createResult.getResponse().getContentAsString();
        String accessKey = JsonPath.read(createBody, "$.data.accessKey");
        String secretKey = JsonPath.read(createBody, "$.data.secretKey");

        mockMvc.perform(put("/api/s3/key-last-used-bucket/last-used.txt")
                        .header("X-OSMU-Access-Key", accessKey)
                        .header("X-OSMU-Secret-Key", secretKey)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("last used"))
                .andExpect(status().isOk());

        mockMvc.perform(put("/api/s3/key-last-used-bucket/last-used-again.txt")
                        .header("X-OSMU-Access-Key", accessKey)
                        .header("X-OSMU-Secret-Key", secretKey)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("last used again"))
                .andExpect(status().isOk());

        String listBody = mockMvc.perform(get("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        List<String> lastUsedAt = JsonPath.read(listBody, "$.items[?(@.accessKey == '%s')].lastUsedAt".formatted(accessKey));
        List<Integer> usageCount = JsonPath.read(listBody, "$.items[?(@.accessKey == '%s')].usageCount".formatted(accessKey));

        assertThat(lastUsedAt).hasSize(1);
        assertThat(lastUsedAt.get(0)).isNotBlank();
        assertThat(usageCount).containsExactly(2);
    }

    @Test
    void rotateAccessKeyReturnsNewSecretAndInvalidatesOldSecret() throws Exception {
        String accessToken = loginAndReturnAccessToken("admin", "password");
        createBucket(accessToken, "key-rotation-bucket");

        MvcResult createResult = mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "rotation-key",
                                  "allowedBuckets": ["key-rotation-bucket"],
                                  "permissions": ["READ", "WRITE"],
                                  "expiresAt": null
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn();
        String createBody = createResult.getResponse().getContentAsString();
        Number keyId = JsonPath.read(createBody, "$.data.id");
        String accessKey = JsonPath.read(createBody, "$.data.accessKey");
        String originalSecret = JsonPath.read(createBody, "$.data.secretKey");

        MvcResult rotateResult = mockMvc.perform(post("/api/access-keys/%d/rotate".formatted(keyId.longValue()))
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(keyId.intValue()))
                .andExpect(jsonPath("$.data.accessKey").value(accessKey))
                .andExpect(jsonPath("$.data.secretKey", not(emptyString())))
                .andReturn();
        String rotatedSecret = JsonPath.read(rotateResult.getResponse().getContentAsString(), "$.data.secretKey");

        assertThat(rotatedSecret).isNotEqualTo(originalSecret);

        mockMvc.perform(put("/api/s3/key-rotation-bucket/old-secret.txt")
                        .header("X-OSMU-Access-Key", accessKey)
                        .header("X-OSMU-Secret-Key", originalSecret)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("old secret"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(put("/api/s3/key-rotation-bucket/new-secret.txt")
                        .header("X-OSMU-Access-Key", accessKey)
                        .header("X-OSMU-Secret-Key", rotatedSecret)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("new secret"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].secretKey").doesNotExist())
                .andExpect(jsonPath("$.items[0].secretKeyHash").doesNotExist());
    }

    @Test
    void bulkDisableAccessKeysDisablesActiveKeysAndSkipsInactiveKeys() throws Exception {
        String accessToken = loginAndReturnAccessToken("admin", "password");
        createBucket(accessToken, "key-bulk-cleanup-bucket");

        Number firstKeyId = createAccessKey(accessToken, "bulk-cleanup-key-1", "key-bulk-cleanup-bucket");
        Number secondKeyId = createAccessKey(accessToken, "bulk-cleanup-key-2", "key-bulk-cleanup-bucket");

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete("/api/access-keys/%d".formatted(secondKeyId.longValue()))
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(post("/api/access-keys/bulk-disable")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "keyIds": [%d, %d]
                                }
                                """.formatted(firstKeyId.longValue(), secondKeyId.longValue())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestedCount").value(2))
                .andExpect(jsonPath("$.data.disabledCount").value(1))
                .andExpect(jsonPath("$.data.skippedCount").value(1))
                .andExpect(jsonPath("$.data.disabledKeyIds[0]").value(firstKeyId.intValue()))
                .andExpect(jsonPath("$.data.skippedKeyIds[0]").value(secondKeyId.intValue()));

        mockMvc.perform(get("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.id == %d)].status".formatted(firstKeyId.longValue())).value(hasItem("INACTIVE")))
                .andExpect(jsonPath("$.items[?(@.id == %d)].status".formatted(secondKeyId.longValue())).value(hasItem("INACTIVE")));
    }

    @Test
    void accessKeySecretIsRedactedFromAuditOutputsAndToString() throws Exception {
        String accessToken = loginAndReturnAccessToken("admin", "password");
        createBucket(accessToken, "key-secret-log-bucket");

        MvcResult createResult = mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "secret-log-key",
                                  "allowedBuckets": ["key-secret-log-bucket"],
                                  "permissions": ["READ"],
                                  "expiresAt": null
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn();
        String createBody = createResult.getResponse().getContentAsString();
        String rawSecret = JsonPath.read(createBody, "$.data.secretKey");
        String accessKey = JsonPath.read(createBody, "$.data.accessKey");

        String auditBody = mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + accessToken)
                        .param("eventType", "ACCESS_KEY_CREATE")
                        .param("targetId", accessKey)
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        assertThat(auditBody).doesNotContain(rawSecret);

        String auditCsv = mockMvc.perform(get("/api/admin/audit-logs/export.csv")
                        .header("Authorization", "Bearer " + accessToken)
                        .param("eventType", "ACCESS_KEY_CREATE")
                        .param("targetId", accessKey)
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        assertThat(auditCsv).doesNotContain(rawSecret);

        List<AccessKeyBucketScope> scopes = List.of(new AccessKeyBucketScope("key-secret-log-bucket", List.of("READ")));
        CreateAccessKeyResponse response = new CreateAccessKeyResponse(900L, "safe-key", accessKey, rawSecret, "policy-name", "policy-document", List.of("key-secret-log-bucket"), List.of("READ"), scopes);
        AccessKeyEntity entity = new AccessKeyEntity(900L, 1L, "safe-key", accessKey, "raw-secret-hash", "raw-secret-ciphertext", List.of("key-secret-log-bucket"), List.of("READ"), scopes, "ACTIVE", OffsetDateTime.now(), null, null, 0L);
        AccessKeyCredential credential = new AccessKeyCredential(900L, 1L, accessKey, "raw-secret-hash", "raw-secret-ciphertext", scopes, "ACTIVE", null);

        assertThat(response.toString())
                .contains("secretKey=<redacted>")
                .doesNotContain(rawSecret);
        assertThat(entity.toString())
                .contains("secretKeyHash=<redacted>", "secretKeyCiphertext=<redacted>")
                .doesNotContain("raw-secret-hash", "raw-secret-ciphertext");
        assertThat(credential.toString())
                .contains("secretKeyHash=<redacted>", "secretKeyCiphertext=<redacted>")
                .doesNotContain("raw-secret-hash", "raw-secret-ciphertext");
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

    private Number createAccessKey(String accessToken, String name, String bucketName) throws Exception {
        String response = mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "allowedBuckets": ["%s"],
                                  "permissions": ["READ"],
                                  "expiresAt": null
                                }
                                """.formatted(name, bucketName)))
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
