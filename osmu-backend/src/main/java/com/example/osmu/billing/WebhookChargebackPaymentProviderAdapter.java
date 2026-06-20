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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class WebhookChargebackPaymentProviderAdapter implements ChargebackPaymentProviderAdapter {

    private static final String HANDOFF_EVENT_TYPE = "chargeback.payment_provider.handoff.delivery";
    private static final int DEFAULT_TIMEOUT_MS = 3000;
    private static final int MIN_TIMEOUT_MS = 500;
    private static final int MAX_TIMEOUT_MS = 15000;

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final String webhookUrl;
    private final String cardWebhookUrl;
    private final String bankWebhookUrl;
    private final String taxWebhookUrl;
    private final String erpWebhookUrl;
    private final String secretHeaderName;
    private final String secretHeaderValue;
    private final String signatureSecret;
    private final String signatureHeaderName;
    private final String signatureTimestampHeaderName;
    private final int timeoutMs;
    private final int maxPayloadBytes;
    private final boolean allowPrivateNetwork;

    public WebhookChargebackPaymentProviderAdapter(
            ObjectMapper objectMapper,
            @Value("${osmu.billing.payment-provider.webhook-url:}") String webhookUrl,
            @Value("${osmu.billing.payment-provider.card.webhook-url:}") String cardWebhookUrl,
            @Value("${osmu.billing.payment-provider.bank.webhook-url:}") String bankWebhookUrl,
            @Value("${osmu.billing.payment-provider.tax.webhook-url:}") String taxWebhookUrl,
            @Value("${osmu.billing.payment-provider.erp.webhook-url:}") String erpWebhookUrl,
            @Value("${osmu.billing.payment-provider.secret-header-name:}") String secretHeaderName,
            @Value("${osmu.billing.payment-provider.secret-header-value:}") String secretHeaderValue,
            @Value("${osmu.billing.payment-provider.signature-secret:}") String signatureSecret,
            @Value("${osmu.billing.payment-provider.signature-header-name:X-OSMU-Signature}") String signatureHeaderName,
            @Value("${osmu.billing.payment-provider.signature-timestamp-header-name:X-OSMU-Signature-Timestamp}") String signatureTimestampHeaderName,
            @Value("${osmu.billing.payment-provider.timeout-ms:3000}") int timeoutMs,
            @Value("${osmu.billing.payment-provider.max-payload-bytes:65536}") int maxPayloadBytes,
            @Value("${osmu.billing.payment-provider.allow-private-network:false}") boolean allowPrivateNetwork
    ) {
        this.objectMapper = objectMapper;
        this.webhookUrl = normalize(webhookUrl);
        this.cardWebhookUrl = normalize(cardWebhookUrl);
        this.bankWebhookUrl = normalize(bankWebhookUrl);
        this.taxWebhookUrl = normalize(taxWebhookUrl);
        this.erpWebhookUrl = normalize(erpWebhookUrl);
        this.secretHeaderName = normalize(secretHeaderName);
        this.secretHeaderValue = normalize(secretHeaderValue);
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
    public boolean isConfigured() {
        return anyConfiguredUri() && secretHeaderConfigIsValid() && signatureConfigIsValid();
    }

    @Override
    public boolean isConfigured(String provider) {
        return configuredUriForProvider(provider) != null && secretHeaderConfigIsValid() && signatureConfigIsValid();
    }

    @Override
    public ChargebackPaymentProviderAdapterResult deliver(ChargebackPaymentProviderHandoffRecord record) {
        URI uri = configuredUriForProvider(record.provider());
        if (uri == null) {
            return ChargebackPaymentProviderAdapterResult.blocked(
                    "Payment provider webhook adapter is not configured for provider " + providerCode(record.provider()) + "."
            );
        }
        if (!secretHeaderConfigIsValid()) {
            return ChargebackPaymentProviderAdapterResult.blocked("Payment provider webhook header configuration is invalid.");
        }
        if (!signatureConfigIsValid()) {
            return ChargebackPaymentProviderAdapterResult.blocked("Payment provider webhook signature configuration is invalid.");
        }

        String requestBody;
        try {
            requestBody = objectMapper.writeValueAsString(handoffEnvelope(record));
        } catch (JsonProcessingException exception) {
            return ChargebackPaymentProviderAdapterResult.blocked("Payment provider webhook payload serialization failed.");
        }
        if (ExternalAdapterPayloadPolicy.exceedsMaxPayloadBytes(requestBody, maxPayloadBytes)) {
            return ChargebackPaymentProviderAdapterResult.blocked("Payment provider webhook payload exceeds the configured max payload size.");
        }

        try {
            HttpRequest.Builder requestBuilder = HttpRequest.newBuilder(uri)
                    .timeout(Duration.ofMillis(timeoutMs))
                    .header("Content-Type", "application/json")
                    .header("X-OSMU-Event-Type", HANDOFF_EVENT_TYPE)
                    .header("X-OSMU-Handoff-Id", String.valueOf(record.id() == null ? 0L : record.id()))
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody));
            if (!secretHeaderName.isBlank() && !secretHeaderValue.isBlank()) {
                requestBuilder.header(secretHeaderName, secretHeaderValue);
            }
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
                        "Payment provider webhook returned retryable HTTP " + statusCode + "."
                );
            }
            return ChargebackPaymentProviderAdapterResult.blocked(
                    "Payment provider webhook returned non-retryable HTTP " + statusCode + "."
            );
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return ChargebackPaymentProviderAdapterResult.retry("Payment provider webhook request was interrupted.");
        } catch (IOException | IllegalArgumentException exception) {
            return ChargebackPaymentProviderAdapterResult.retry("Payment provider webhook request failed; retry scheduled.");
        }
    }

    private Map<String, Object> handoffEnvelope(ChargebackPaymentProviderHandoffRecord record) {
        Map<String, Object> envelope = new LinkedHashMap<>();
        envelope.put("eventType", HANDOFF_EVENT_TYPE);
        envelope.put("handoffId", record.id());
        envelope.put("finalInvoiceId", record.finalInvoiceId());
        envelope.put("invoiceNumber", record.invoiceNumber());
        envelope.put("organizationId", record.organizationId());
        envelope.put("organizationName", record.organizationName());
        envelope.put("currency", record.currency());
        envelope.put("amount", record.amount());
        envelope.put("provider", record.provider());
        envelope.put("providerProfile", providerProfile(record.provider()));
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

    private boolean anyConfiguredUri() {
        return configuredRawUri(webhookUrl) != null
                || configuredRawUri(cardWebhookUrl) != null
                || configuredRawUri(bankWebhookUrl) != null
                || configuredRawUri(taxWebhookUrl) != null
                || configuredRawUri(erpWebhookUrl) != null;
    }

    private URI configuredUriForProvider(String provider) {
        return configuredRawUri(webhookUrlForProvider(provider));
    }

    private URI configuredRawUri(String value) {
        return WebhookEndpointPolicy.configuredUri(value, allowPrivateNetwork);
    }

    private String webhookUrlForProvider(String provider) {
        String providerSpecificUrl = switch (providerProfile(provider)) {
            case "CARD" -> cardWebhookUrl;
            case "BANK" -> bankWebhookUrl;
            case "TAX" -> taxWebhookUrl;
            case "ERP" -> erpWebhookUrl;
            default -> "";
        };
        return providerSpecificUrl.isBlank() ? webhookUrl : providerSpecificUrl;
    }

    private boolean secretHeaderConfigIsValid() {
        if (secretHeaderName.isBlank() && secretHeaderValue.isBlank()) {
            return true;
        }
        return validHeaderName(secretHeaderName) && !secretHeaderValue.isBlank() && !containsLineBreak(secretHeaderValue);
    }

    private boolean signatureConfigIsValid() {
        return ExternalAdapterSignaturePolicy.signatureConfigIsValid(
                signatureSecret,
                signatureHeaderName,
                signatureTimestampHeaderName
        );
    }

    private static boolean validHeaderName(String value) {
        if (value.isBlank() || value.length() > 64 || containsLineBreak(value)) {
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

    private static String providerProfile(String provider) {
        String normalizedProvider = providerCode(provider);
        if (normalizedProvider.startsWith("CARD")) {
            return "CARD";
        }
        if (normalizedProvider.startsWith("BANK")) {
            return "BANK";
        }
        if (normalizedProvider.startsWith("TAX")) {
            return "TAX";
        }
        if (normalizedProvider.startsWith("ERP")) {
            return "ERP";
        }
        return "GENERIC";
    }

    private static String providerCode(String provider) {
        String normalizedProvider = normalize(provider).toUpperCase(Locale.ROOT).replace('-', '_').replace(' ', '_');
        return normalizedProvider.isBlank() ? "MANUAL_AP" : normalizedProvider;
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim();
    }
}
