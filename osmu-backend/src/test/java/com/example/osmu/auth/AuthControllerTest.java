package com.example.osmu.auth;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.matchesPattern;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class AuthControllerTest {

    private static final String JWT_PATTERN = "^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$";

    @Autowired
    private MockMvc mockMvc;

    @Test
    void loginReturnsSignedJwtForAdmin() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "admin",
                                  "password": "password"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken", matchesPattern(JWT_PATTERN)))
                .andExpect(jsonPath("$.data.refreshToken", matchesPattern(JWT_PATTERN)))
                .andExpect(jsonPath("$.data.user.role").value("ADMIN"));
    }

    @Test
    void loginRejectsInvalidCredentials() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "admin",
                                  "password": "wrong"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"));
    }

    @Test
    void protectedApiRejectsMissingToken() throws Exception {
        mockMvc.perform(get("/api/buckets")
                        .header("X-Request-Id", "req-missing-token-1"))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("X-Request-Id", "req-missing-token-1"))
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"))
                .andExpect(jsonPath("$.error.requestId").value("req-missing-token-1"));
    }

    @Test
    void oidcCallbackIsPublicButDisabledByDefault() throws Exception {
        mockMvc.perform(get("/api/auth/oidc/callback")
                        .param("code", "auth-code")
                        .param("state", "state-1"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
    }

    @Test
    void ldapLoginIsPublicButDisabledByDefault() throws Exception {
        mockMvc.perform(post("/api/auth/ldap/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "admin",
                                  "password": "ldap-password"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
    }

    @Test
    void protectedApiAcceptsIssuedAccessToken() throws Exception {
        String accessToken = loginAndReturnAccessToken();

        mockMvc.perform(get("/api/buckets")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk());
    }

    @Test
    void meReturnsAuthenticatedUserProfile() throws Exception {
        String accessToken = loginAndReturnAccessToken();

        mockMvc.perform(get("/api/users/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.loginId").value("admin"))
                .andExpect(jsonPath("$.data.email").value("admin@example.com"))
                .andExpect(jsonPath("$.data.role").value("ADMIN"));
    }

    @Test
    void protectedApiRejectsMalformedToken() throws Exception {
        mockMvc.perform(get("/api/buckets")
                        .header("Authorization", "Bearer not-a-jwt"))
                .andExpect(status().isUnauthorized())
                .andExpect(header().exists("X-Request-Id"))
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"))
                .andExpect(jsonPath("$.error.requestId").exists());
    }

    @Test
    void refreshRotatesRefreshToken() throws Exception {
        String loginResponse = loginAndReturnResponse();
        String refreshToken = JsonPath.read(loginResponse, "$.data.refreshToken");

        String refreshResponse = mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "%s"
                                }
                                """.formatted(refreshToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken", matchesPattern(JWT_PATTERN)))
                .andExpect(jsonPath("$.data.refreshToken", matchesPattern(JWT_PATTERN)))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String rotatedRefreshToken = JsonPath.read(refreshResponse, "$.data.refreshToken");
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "%s"
                                }
                                """.formatted(refreshToken)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"));

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "%s"
                                }
                                """.formatted(rotatedRefreshToken)))
                .andExpect(status().isOk());
    }

    @Test
    void logoutRevokesRefreshToken() throws Exception {
        String loginResponse = loginAndReturnResponse();
        String accessToken = JsonPath.read(loginResponse, "$.data.accessToken");
        String refreshToken = JsonPath.read(loginResponse, "$.data.refreshToken");

        mockMvc.perform(post("/api/auth/logout")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "%s"
                                }
                                """.formatted(refreshToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.success").value(true));

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "refreshToken": "%s"
                                }
                                """.formatted(refreshToken)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_REQUIRED"));
    }

    @Test
    void auditLogsIncludeRequestMetadata() throws Exception {
        String response = mockMvc.perform(post("/api/auth/login")
                        .header("X-Forwarded-For", "203.0.113.10, 10.0.0.1")
                        .header("User-Agent", "OSMU-Test-Agent")
                        .header("X-Request-Id", "req-auth-meta-1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "admin",
                                  "password": "password"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Request-Id", "req-auth-meta-1"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String accessToken = JsonPath.read(response, "$.data.accessToken");
        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.eventType == 'LOGIN' && @.requestId == 'req-auth-meta-1')].actorId", hasItem("admin")))
                .andExpect(jsonPath("$.items[?(@.eventType == 'LOGIN' && @.requestId == 'req-auth-meta-1')].ipAddress", hasItem("203.0.113.10")))
                .andExpect(jsonPath("$.items[?(@.eventType == 'LOGIN' && @.requestId == 'req-auth-meta-1')].userAgent", hasItem("OSMU-Test-Agent")));
    }

    @Test
    void requestIdIsGeneratedAndRecordedWhenMissing() throws Exception {
        MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "admin",
                                  "password": "password"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(header().exists("X-Request-Id"))
                .andReturn();

        String requestId = loginResult.getResponse().getHeader("X-Request-Id");
        String accessToken = JsonPath.read(loginResult.getResponse().getContentAsString(), "$.data.accessToken");
        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.eventType == 'LOGIN' && @.requestId == '%s')].actorId".formatted(requestId), hasItem("admin")));
    }

    private String loginAndReturnAccessToken() throws Exception {
        String response = loginAndReturnResponse();

        return JsonPath.read(response, "$.data.accessToken");
    }

    private String loginAndReturnResponse() throws Exception {
        return mockMvc.perform(post("/api/auth/login")
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
    }
}
