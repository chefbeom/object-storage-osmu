package com.example.osmu.billing;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

public class ConfigurableChargebackNativePaymentProviderAdapter implements ChargebackNativePaymentProviderAdapter {

    private static final String HANDOFF_EVENT_TYPE = "chargeback.payment_provider.native.handoff.delivery";
    private static final int DEFAULT_TIMEOUT_MS = 3000;
    private static final int MIN_TIMEOUT_MS = 500;
    private static final int MAX_TIMEOUT_MS = 15000;

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final String providerProfile;
    private final String nativeApiUrl;
    private final String authHeaderName;
    private final String authHeaderValue;
    private final String signatureSecret;
    private final String signatureHeaderName;
    private final String signatureTimestampHeaderName;
    private final int timeoutMs;
    private final int maxPayloadBytes;
    private final boolean allowPrivateNetwork;

    public ConfigurableChargebackNativePaymentProviderAdapter(
            ObjectMapper objectMapper,
            String providerProfile,
            String nativeApiUrl,
            String authHeaderName,
            String authHeaderValue,
            String signatureSecret,
            String signatureHeaderName,
            String signatureTimestampHeaderName,
            int timeoutMs,
            int maxPayloadBytes,
            boolean allowPrivateNetwork
    ) {
        this.objectMapper = objectMapper;
        this.providerProfile = normalizeProviderProfile(providerProfile);
        this.nativeApiUrl = normalize(nativeApiUrl);
        this.authHeaderName = normalizeHeaderName(authHeaderName);
        this.authHeaderValue = normalize(authHeaderValue);
        this.signatureSecret = normalize(signatureSecret);
        this.signatureHeaderName = ExternalAdapterSignaturePolicy.normalizeHeaderName(
                signatureHeaderName,
                ExternalAdapterSignaturePolicy.DEFAULT_SIGNATURE_HEADER_NAME
        );
        this.signatureTimestampHeaderName = ExternalAdapterSignaturePolicy.normalizeHeaderName(
                signatureTimestampHeaderName,
                ExternalAdapterSignaturePolicy.DEFAULT_TIMESTAMP_HEADER_NAME
        );
        this.timeoutMs = Math.max(MIN_TIMEOUT_MS, Math.min(timeoutMs <= 0 ? DEFAULT_TIMEOUT_MS : timeoutMs, MAX_TIMEOUT_MS));
        this.maxPayloadBytes = ExternalAdapterPayloadPolicy.normalizeMaxPayloadBytes(maxPayloadBytes);
        this.allowPrivateNetwork = allowPrivateNetwork;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(this.timeoutMs))
                .build();
    }

    @Override
    public String providerProfile() {
        return providerProfile;
    }

    @Override
    public boolean isConfigured() {
        return configuredUri() != null && authHeaderConfigIsValid() && signatureConfigIsValid();
    }

    @Override
    public ChargebackPaymentProviderAdapterResult deliver(ChargebackPaymentProviderHandoffRecord record) {
        URI uri = configuredUri();
        if (uri == null) {
            return ChargebackPaymentProviderAdapterResult.blocked(
                    providerProfile + " native payment provider API endpoint is not configured."
            );
        }
        if (!authHeaderConfigIsValid()) {
            return ChargebackPaymentProviderAdapterResult.blocked(
                    providerProfile + " native payment provider API auth header configuration is invalid."
            );
        }
        if (!signatureConfigIsValid()) {
            return ChargebackPaymentProviderAdapterResult.blocked(
                    providerProfile + " native payment provider API signature configuration is invalid."
            );
        }

        String requestBody;
        try {
            requestBody = objectMapper.writeValueAsString(handoffEnvelope(record));
        } catch (JsonProcessingException exception) {
            return ChargebackPaymentProviderAdapterResult.blocked(
                    providerProfile + " native payment provider API payload serialization failed."
            );
        }
        if (ExternalAdapterPayloadPolicy.exceedsMaxPayloadBytes(requestBody, maxPayloadBytes)) {
            return ChargebackPaymentProviderAdapterResult.blocked(
                    providerProfile + " native payment provider API payload exceeds the configured max payload size."
            );
        }

        try {
            HttpRequest.Builder requestBuilder = HttpRequest.newBuilder(uri)
                    .timeout(Duration.ofMillis(timeoutMs))
                    .header("Content-Type", "application/json")
                    .header("X-OSMU-Event-Type", HANDOFF_EVENT_TYPE)
                    .header("X-OSMU-Provider-Profile", providerProfile)
                    .header("X-OSMU-Handoff-Id", String.valueOf(record.id() == null ? 0L : record.id()))
                    .header(authHeaderName, authHeaderValue)
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody));
            ExternalAdapterSignaturePolicy.addSignatureHeaders(
                    requestBuilder,
                    requestBody,
                    signatureSecret,
                    signatureHeaderName,
                    signatureTimestampHeaderName
            );
            HttpResponse<Void> httpResponse = httpClient.send(
                    requestBuilder.build(),
                    HttpResponse.BodyHandlers.discarding()
            );
            int statusCode = httpResponse.statusCode();
            if (statusCode >= 200 && statusCode < 300) {
                return ChargebackPaymentProviderAdapterResult.success();
            }
            if (statusCode == 429 || statusCode >= 500) {
                return ChargebackPaymentProviderAdapterResult.retry(
                        providerProfile + " native payment provider API returned retryable HTTP " + statusCode + "."
                );
            }
            return ChargebackPaymentProviderAdapterResult.blocked(
                    providerProfile + " native payment provider API returned non-retryable HTTP " + statusCode + "."
            );
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return ChargebackPaymentProviderAdapterResult.retry(
                    providerProfile + " native payment provider API request was interrupted."
            );
        } catch (IOException | IllegalArgumentException exception) {
            return ChargebackPaymentProviderAdapterResult.retry(
                    providerProfile + " native payment provider API request failed; retry scheduled."
            );
        }
    }

    private Map<String, Object> handoffEnvelope(ChargebackPaymentProviderHandoffRecord record) {
        Map<String, Object> envelope = new LinkedHashMap<>();
        envelope.put("eventType", HANDOFF_EVENT_TYPE);
        envelope.put("providerProfile", providerProfile);
        envelope.put("handoffId", record.id());
        envelope.put("finalInvoiceId", record.finalInvoiceId());
        envelope.put("invoiceNumber", record.invoiceNumber());
        envelope.put("organizationId", record.organizationId());
        envelope.put("organizationName", record.organizationName());
        envelope.put("currency", record.currency());
        envelope.put("amount", record.amount());
        envelope.put("provider", record.provider());
        envelope.put("targetAccount", record.targetAccount());
        envelope.put("payload", payload(record.payloadJson()));
        return envelope;
    }

    private Object payload(String payloadJson) {
        if (payloadJson == null || payloadJson.isBlank()) {
            return Map.of();
        }
        try {
            return objectMapper.readTree(payloadJson);
        } catch (JsonProcessingException exception) {
            return payloadJson;
        }
    }

    private URI configuredUri() {
        return WebhookEndpointPolicy.configuredUri(nativeApiUrl, allowPrivateNetwork);
    }

    private boolean authHeaderConfigIsValid() {
        return validHeaderName(authHeaderName) && !authHeaderValue.isBlank() && !containsLineBreak(authHeaderValue);
    }

    private boolean signatureConfigIsValid() {
        return ExternalAdapterSignaturePolicy.signatureConfigIsValid(
                signatureSecret,
                signatureHeaderName,
                signatureTimestampHeaderName
        );
    }

    private static String normalizeProviderProfile(String value) {
        String normalized = normalize(value).toUpperCase(Locale.ROOT).replace('-', '_').replace(' ', '_');
        return switch (normalized) {
            case "CARD", "BANK", "TAX", "ERP" -> normalized;
            default -> "GENERIC";
        };
    }

    private static String normalizeHeaderName(String value) {
        String normalized = normalize(value);
        return normalized.isBlank() ? "Authorization" : normalized;
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim();
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