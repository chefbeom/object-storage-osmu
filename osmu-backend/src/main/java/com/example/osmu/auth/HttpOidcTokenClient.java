package com.example.osmu.auth;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class HttpOidcTokenClient implements OidcTokenClient {

    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper;

    public HttpOidcTokenClient(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public OidcTokenResponse exchangeAuthorizationCode(OidcTokenExchangeRequest request) {
        try {
            HttpRequest httpRequest = HttpRequest.newBuilder(URI.create(request.tokenUri()))
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString(formBody(request)))
                    .build();
            HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "OIDC token exchange failed.");
            }
            return objectMapper.readValue(response.body(), OidcTokenResponse.class);
        } catch (ApiException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "OIDC token exchange failed.");
        }
    }

    private String formBody(OidcTokenExchangeRequest request) {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("grant_type", "authorization_code");
        params.put("code", request.code());
        params.put("redirect_uri", request.redirectUri());
        params.put("client_id", request.clientId());
        if (request.clientSecret() != null && !request.clientSecret().isBlank()) {
            params.put("client_secret", request.clientSecret());
        }
        params.put("code_verifier", request.codeVerifier());
        return params.entrySet().stream()
                .map(entry -> urlEncode(entry.getKey()) + "=" + urlEncode(entry.getValue()))
                .reduce((left, right) -> left + "&" + right)
                .orElse("");
    }

    private String urlEncode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}
