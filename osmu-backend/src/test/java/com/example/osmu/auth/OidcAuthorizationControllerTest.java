package com.example.osmu.auth;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "osmu.enterprise-auth.oidc.authorization-enabled=true",
        "osmu.enterprise-auth.oidc.issuer-uri=https://idp.example.com/realms/osmu",
        "osmu.enterprise-auth.oidc.client-id=osmu-web",
        "osmu.enterprise-auth.oidc.authorization-uri=https://idp.example.com/realms/osmu/protocol/openid-connect/auth",
        "osmu.enterprise-auth.oidc.redirect-uri=http://localhost:5173/auth/oidc/callback"
})
@AutoConfigureMockMvc
class OidcAuthorizationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void oidcAuthorizeIsPublicAndReturnsAuthorizationRequest() throws Exception {
        mockMvc.perform(get("/api/auth/oidc/authorize"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.authorizationUrl", containsString("response_type=code")))
                .andExpect(jsonPath("$.data.authorizationUrl", containsString("code_challenge_method=S256")))
                .andExpect(jsonPath("$.data.state").isNotEmpty())
                .andExpect(jsonPath("$.data.nonce").isNotEmpty())
                .andExpect(jsonPath("$.data.codeChallenge").isNotEmpty())
                .andExpect(jsonPath("$.data.codeChallengeMethod").value("S256"))
                .andExpect(jsonPath("$.data.redirectUri").value("http://localhost:5173/auth/oidc/callback"))
                .andExpect(jsonPath("$.data.scopes[0]").value("openid"));
    }
}
