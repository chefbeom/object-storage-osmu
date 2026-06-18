package com.example.osmu.developer;

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
        "osmu.s3.public-endpoint=https://storage.example.com/api/s3",
        "osmu.s3.region=ap-northeast-2",
        "osmu.s3.virtual-hosted-style.enabled=true",
        "osmu.s3.virtual-hosted-style.domain-suffixes=storage.example.com,localhost"
})
@AutoConfigureMockMvc
class DeveloperControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void s3ClientConfigReturnsPublicEndpointAndRegion() throws Exception {
        String accessToken = loginAndReturnAccessToken();

        mockMvc.perform(get("/api/developer/s3-client-config")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.endpoint").value("https://storage.example.com/api/s3"))
                .andExpect(jsonPath("$.data.region").value("ap-northeast-2"))
                .andExpect(jsonPath("$.data.signatureVersion").value("AWS4-HMAC-SHA256"))
                .andExpect(jsonPath("$.data.service").value("s3"))
                .andExpect(jsonPath("$.data.pathStyleSupported").value(true))
                .andExpect(jsonPath("$.data.virtualHostedStyleEnabled").value(true))
                .andExpect(jsonPath("$.data.virtualHostedStyleDomainSuffixes[0]").value("storage.example.com"))
                .andExpect(jsonPath("$.data.virtualHostedStyleDomainSuffixes[1]").value("localhost"));
    }

    @Test
    void s3ClientConfigRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/api/developer/s3-client-config"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"));
    }

    private String loginAndReturnAccessToken() throws Exception {
        String response = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "admin",
                                  "password": "password"
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.accessToken");
    }
}
