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
public class WebhookChargebackNotificationDeliveryAdapter implements ChargebackNotificationDeliveryAdapter {

    private static final String DELIVERY_EVENT_TYPE = "chargeback.threshold.delivery";
    private static final int DEFAULT_TIMEOUT_MS = 3000;
    private static final int MIN_TIMEOUT_MS = 500;
    private static final int MAX_TIMEOUT_MS = 15000;

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final String webhookUrl;
    private final String secretHeaderName;
    private final String secretHeaderValue;
    private final int timeoutMs;

    public WebhookChargebackNotificationDeliveryAdapter(
            ObjectMapper objectMapper,
            @Value("${osmu.billing.notification-delivery.webhook-url:}") String webhookUrl,
            @Value("${osmu.billing.notification-delivery.secret-header-name:}") String secretHeaderName,
            @Value("${osmu.billing.notification-delivery.secret-header-value:}") String secretHeaderValue,
            @Value("${osmu.billing.notification-delivery.timeout-ms:3000}") int timeoutMs
    ) {
        this.objectMapper = objectMapper;
        this.webhookUrl = normalize(webhookUrl);
        this.secretHeaderName = normalize(secretHeaderName);
        this.secretHeaderValue = normalize(secretHeaderValue);
        this.timeoutMs = Math.max(MIN_TIMEOUT_MS, Math.min(timeoutMs <= 0 ? DEFAULT_TIMEOUT_MS : timeoutMs, MAX_TIMEOUT_MS));
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(this.timeoutMs))
                .build();
    }

    @Override
    public boolean isConfigured() {
        return configuredUri() != null && secretHeaderConfigIsValid();
    }

    @Override
    public ChargebackNotificationDeliveryAdapterResult deliver(ChargebackAlertNotificationDeliveryRecord record) {
        URI uri = configuredUri();
        if (uri == null) {
            return ChargebackNotificationDeliveryAdapterResult.blocked("Notification webhook adapter is not configured.");
        }
        if (!secretHeaderConfigIsValid()) {
            return ChargebackNotificationDeliveryAdapterResult.blocked("Notification webhook header configuration is invalid.");
        }

        String requestBody;
        try {
            requestBody = objectMapper.writeValueAsString(deliveryEnvelope(record));
        } catch (JsonProcessingException exception) {
            return ChargebackNotificationDeliveryAdapterResult.blocked("Notification webhook payload serialization failed.");
        }

        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder(uri)
                .timeout(Duration.ofMillis(timeoutMs))
                .header("Content-Type", "application/json")
                .header("X-OSMU-Event-Type", DELIVERY_EVENT_TYPE)
                .header("X-OSMU-Delivery-Id", String.valueOf(record.id() == null ? 0L : record.id()))
                .POST(HttpRequest.BodyPublishers.ofString(requestBody));
        if (!secretHeaderName.isBlank() && !secretHeaderValue.isBlank()) {
            requestBuilder.header(secretHeaderName, secretHeaderValue);
        }

        try {
            HttpResponse<Void> httpResponse = httpClient.send(
                    requestBuilder.build(),
                    HttpResponse.BodyHandlers.discarding()
            );
            int statusCode = httpResponse.statusCode();
            if (statusCode >= 200 && statusCode < 300) {
                return ChargebackNotificationDeliveryAdapterResult.success();
            }
            if (statusCode == 429 || statusCode >= 500) {
                return ChargebackNotificationDeliveryAdapterResult.retry(
                        "Notification webhook returned retryable HTTP " + statusCode + "."
                );
            }
            return ChargebackNotificationDeliveryAdapterResult.blocked(
                    "Notification webhook returned non-retryable HTTP " + statusCode + "."
            );
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return ChargebackNotificationDeliveryAdapterResult.retry("Notification webhook request was interrupted.");
        } catch (IOException | IllegalArgumentException exception) {
            return ChargebackNotificationDeliveryAdapterResult.retry("Notification webhook request failed; retry scheduled.");
        }
    }

    private Map<String, Object> deliveryEnvelope(ChargebackAlertNotificationDeliveryRecord record) {
        Map<String, Object> envelope = new LinkedHashMap<>();
        envelope.put("eventType", DELIVERY_EVENT_TYPE);
        envelope.put("deliveryId", record.id());
        envelope.put("organizationId", record.organizationId());
        envelope.put("organizationName", record.organizationName());
        envelope.put("severity", record.severity());
        envelope.put("channel", record.channel());
        envelope.put("target", record.target());
        envelope.put("subject", record.subject());
        envelope.put("message", record.message());
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
        if (webhookUrl.isBlank()) {
            return null;
        }
        try {
            URI uri = URI.create(webhookUrl);
            String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
            if (!("http".equals(scheme) || "https".equals(scheme))
                    || uri.getHost() == null
                    || uri.getHost().isBlank()
                    || uri.getUserInfo() != null) {
                return null;
            }
            return uri;
        } catch (IllegalArgumentException exception) {
            return null;
        }
    }

    private boolean secretHeaderConfigIsValid() {
        if (secretHeaderName.isBlank() && secretHeaderValue.isBlank()) {
            return true;
        }
        return validHeaderName(secretHeaderName) && !secretHeaderValue.isBlank() && !containsLineBreak(secretHeaderValue);
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

    private static String normalize(String value) {
        return value == null ? "" : value.trim();
    }
}
