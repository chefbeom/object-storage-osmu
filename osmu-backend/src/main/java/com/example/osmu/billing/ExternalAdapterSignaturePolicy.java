package com.example.osmu.billing;

import java.net.http.HttpRequest;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

final class ExternalAdapterSignaturePolicy {

    static final String DEFAULT_SIGNATURE_HEADER_NAME = "X-OSMU-Signature";
    static final String DEFAULT_TIMESTAMP_HEADER_NAME = "X-OSMU-Signature-Timestamp";

    private ExternalAdapterSignaturePolicy() {
    }

    static String normalizeHeaderName(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value.trim();
    }

    static boolean signatureConfigIsValid(
            String signingSecret,
            String signatureHeaderName,
            String timestampHeaderName
    ) {
        if (signingSecret == null || signingSecret.isBlank()) {
            return true;
        }
        return !containsLineBreak(signingSecret)
                && validHeaderName(signatureHeaderName)
                && validHeaderName(timestampHeaderName)
                && !signatureHeaderName.equalsIgnoreCase(timestampHeaderName);
    }

    static void addSignatureHeaders(
            HttpRequest.Builder requestBuilder,
            String payload,
            String signingSecret,
            String signatureHeaderName,
            String timestampHeaderName
    ) {
        if (signingSecret == null || signingSecret.isBlank()) {
            return;
        }
        String timestamp = String.valueOf(Instant.now().getEpochSecond());
        String signature = "t=" + timestamp + ",v1=" + hmacSha256(signingSecret, timestamp + "." + payload);
        requestBuilder.header(timestampHeaderName, timestamp);
        requestBuilder.header(signatureHeaderName, signature);
    }

    private static String hmacSha256(String signingSecret, String payload) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(signingSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(payload.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("Webhook signature generation failed.", exception);
        }
    }

    private static boolean validHeaderName(String value) {
        if (value == null || value.isBlank() || value.length() > 64 || containsLineBreak(value)) {
            return false;
        }
        for (int index = 0; index < value.length(); index += 1) {
            char character = value.charAt(index);
            if (!(Character.isLetterOrDigit(character) || "!#$%&'*+-.^_`|~".indexOf(character) >= 0)) {
                return false;
            }
        }
        return true;
    }

    private static boolean containsLineBreak(String value) {
        return value.contains("\r") || value.contains("\n");
    }
}
