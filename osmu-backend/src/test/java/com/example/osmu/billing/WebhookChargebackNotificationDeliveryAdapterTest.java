package com.example.osmu.billing;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import java.math.BigDecimal;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;

class WebhookChargebackNotificationDeliveryAdapterTest {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    @Test
    void sendsSlackPayloadWhenSlackChannelIsConfigured() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>("");
        AtomicReference<String> eventHeader = new AtomicReference<>("");
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/slack", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            eventHeader.set(exchange.getRequestHeaders().getFirst("X-OSMU-Event-Type"));
            exchange.sendResponseHeaders(200, -1);
            exchange.close();
        });
        server.start();
        try {
            String slackUrl = "http://127.0.0.1:" + server.getAddress().getPort() + "/slack";
            WebhookChargebackNotificationDeliveryAdapter adapter =
                    new WebhookChargebackNotificationDeliveryAdapter(OBJECT_MAPPER, "", slackUrl, "", "", 3000);

            assertThat(adapter.isConfigured()).isTrue();
            assertThat(adapter.isConfigured("SLACK")).isTrue();
            assertThat(adapter.isConfigured("WEBHOOK")).isFalse();

            ChargebackNotificationDeliveryAdapterResult result = adapter.deliver(new ChargebackAlertNotificationDeliveryRecord(
                    7L,
                    3L,
                    "Slack Org",
                    "CRITICAL",
                    BigDecimal.valueOf(1200L),
                    BigDecimal.valueOf(1000L),
                    BigDecimal.valueOf(1100L),
                    "SLACK",
                    "ops-alerts",
                    "PENDING_DELIVERY_ADAPTER",
                    0,
                    null,
                    "Chargeback threshold crossed",
                    "Slack Org exceeded the critical billing threshold.",
                    "{\"eventType\":\"chargeback.threshold\"}",
                    "admin",
                    "unit test",
                    OffsetDateTime.now(),
                    OffsetDateTime.now(),
                    null
            ));

            assertThat(result.result()).isEqualTo("SUCCESS");
            assertThat(eventHeader.get()).isEqualTo("chargeback.threshold.slack.delivery");
            assertThat(requestBody.get()).contains("\"text\"");
            assertThat(requestBody.get()).contains("Slack Org");
            assertThat(requestBody.get()).contains("Amount: 1200");
        } finally {
            server.stop(0);
        }
    }
}
