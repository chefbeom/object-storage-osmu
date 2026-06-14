package com.example.osmu.accesskey;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
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

@SpringBootTest(properties = {
        "osmu.access-key.provisioning-mode=minio",
        "osmu.access-key.minio.mc-path=missing-osmu-mc-command"
})
@AutoConfigureMockMvc
class AccessKeyProvisioningFailureTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void failedProvisioningDoesNotPersistUnusableAccessKey() throws Exception {
        String accessToken = loginAndReturnAccessToken("admin", "password");
        createBucket(accessToken, "provision-fail-bucket");

        mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "provision-failed-key",
                                  "allowedBuckets": ["provision-fail-bucket"],
                                  "permissions": ["READ"],
                                  "expiresAt": null
                                }
                                """))
                .andExpect(status().isBadGateway());

        mockMvc.perform(get("/api/access-keys")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", not(hasItem("provision-failed-key"))));
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
