package com.example.osmu.auth;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.Signature;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.RSAPublicKeySpec;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class OidcIdTokenVerifier {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {
    };
    private static final Base64.Decoder BASE64_URL_DECODER = Base64.getUrlDecoder();

    private final ObjectMapper objectMapper;
    private final OidcJwksClient jwksClient;

    public OidcIdTokenVerifier(ObjectMapper objectMapper, OidcJwksClient jwksClient) {
        this.objectMapper = objectMapper;
        this.jwksClient = jwksClient;
    }

    public OidcIdTokenClaims verify(String idToken, String jwksUri, String issuerUri, String clientId, String expectedNonce) {
        try {
            String[] parts = idToken == null ? new String[0] : idToken.split("\\.", -1);
            if (parts.length != 3) {
                throw invalidToken();
            }
            Map<String, Object> header = decodeJson(parts[0]);
            Map<String, Object> claims = decodeJson(parts[1]);
            if (!"RS256".equals(header.get("alg"))) {
                throw invalidToken();
            }
            RSAPublicKey publicKey = publicKeyFor(jwksClient.getJwks(jwksUri), stringValue(header.get("kid")));
            if (!validSignature(parts[0] + "." + parts[1], parts[2], publicKey)) {
                throw invalidToken();
            }
            assertClaimEquals(claims, "iss", issuerUri);
            if (!audienceContains(claims.get("aud"), clientId)) {
                throw invalidToken();
            }
            if (longValue(claims.get("exp")) <= Instant.now().getEpochSecond()) {
                throw invalidToken();
            }
            assertClaimEquals(claims, "nonce", expectedNonce);
            String subject = requiredString(claims, "sub");
            return new OidcIdTokenClaims(
                    subject,
                    issuerUri,
                    stringValue(claims.get("email")),
                    stringValue(claims.get("name")),
                    expectedNonce,
                    Map.copyOf(claims)
            );
        } catch (ApiException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw invalidToken();
        }
    }

    private Map<String, Object> decodeJson(String encoded) {
        try {
            return objectMapper.readValue(BASE64_URL_DECODER.decode(encoded), MAP_TYPE);
        } catch (Exception exception) {
            throw invalidToken();
        }
    }

    private RSAPublicKey publicKeyFor(Map<String, Object> jwks, String kid) {
        Object keysValue = jwks.get("keys");
        if (!(keysValue instanceof List<?> keys) || keys.isEmpty()) {
            throw invalidToken();
        }
        for (Object keyValue : keys) {
            if (!(keyValue instanceof Map<?, ?> rawKey)) {
                continue;
            }
            Map<String, Object> key = normalizeMap(rawKey);
            if (!"RSA".equals(key.get("kty"))) {
                continue;
            }
            if (kid != null && !kid.isBlank() && !kid.equals(key.get("kid"))) {
                continue;
            }
            if (key.containsKey("alg") && !"RS256".equals(key.get("alg"))) {
                continue;
            }
            return rsaPublicKey(requiredString(key, "n"), requiredString(key, "e"));
        }
        throw invalidToken();
    }

    private RSAPublicKey rsaPublicKey(String modulus, String exponent) {
        try {
            BigInteger n = new BigInteger(1, BASE64_URL_DECODER.decode(modulus));
            BigInteger e = new BigInteger(1, BASE64_URL_DECODER.decode(exponent));
            return (RSAPublicKey) KeyFactory.getInstance("RSA").generatePublic(new RSAPublicKeySpec(n, e));
        } catch (Exception exception) {
            throw invalidToken();
        }
    }

    private boolean validSignature(String unsignedToken, String encodedSignature, RSAPublicKey publicKey) {
        try {
            Signature signature = Signature.getInstance("SHA256withRSA");
            signature.initVerify(publicKey);
            signature.update(unsignedToken.getBytes(StandardCharsets.US_ASCII));
            return signature.verify(BASE64_URL_DECODER.decode(encodedSignature));
        } catch (Exception exception) {
            throw invalidToken();
        }
    }

    private boolean audienceContains(Object audience, String clientId) {
        if (audience instanceof String text) {
            return clientId.equals(text);
        }
        if (audience instanceof List<?> values) {
            return values.stream().anyMatch(value -> clientId.equals(value));
        }
        return false;
    }

    private void assertClaimEquals(Map<String, Object> claims, String key, String expected) {
        if (!expected.equals(claims.get(key))) {
            throw invalidToken();
        }
    }

    private String requiredString(Map<String, Object> claims, String key) {
        String value = stringValue(claims.get(key));
        if (value == null || value.isBlank()) {
            throw invalidToken();
        }
        return value;
    }

    private long longValue(Object value) {
        if (value instanceof Number number) {
            return number.longValue();
        }
        throw invalidToken();
    }

    private String stringValue(Object value) {
        return value instanceof String text ? text : null;
    }

    private Map<String, Object> normalizeMap(Map<?, ?> map) {
        return map.entrySet().stream()
                .filter(entry -> entry.getKey() instanceof String)
                .collect(java.util.stream.Collectors.toMap(
                        entry -> (String) entry.getKey(),
                        Map.Entry::getValue
                ));
    }

    private ApiException invalidToken() {
        return new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid OIDC id token.");
    }
}
