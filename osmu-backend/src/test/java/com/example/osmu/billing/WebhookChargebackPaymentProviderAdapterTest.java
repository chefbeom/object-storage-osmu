package com.example.osmu.billing;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import java.math.BigDecimal;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.concurrent.atomic.AtomicReference;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.Test;

class WebhookChargebackPaymentProviderAdapterTest {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    @Test
    void blocksOversizedPaymentProviderWebhookPayloadBeforeSending() {
        WebhookChargebackPaymentProviderAdapter adapter =
                new WebhookChargebackPaymentProviderAdapter(
                        OBJECT_MAPPER,
                        "https://payments.example.com/osmu",
                        "",
                        "",
                        "",
                        "",
                        "",
                        3000,
                        1024,
                        false
                );

        ChargebackPaymentProviderAdapterResult result = adapter.deliver(new ChargebackPaymentProviderHandoffRecord(
                15L,
                8L,
                "OSMU-FINAL-20260620-8",
                4L,
                "Payment Org",
                "KRW",
                BigDecimal.valueOf(1200L),
                "MANUAL_AP",
                "finance-ap",
                "PENDING_PAYMENT_PROVIDER_ADAPTER",
                0,
                null,
                "{\"eventType\":\"chargeback.payment_provider.handoff\",\"note\":\"" + "x".repeat(2048) + "\"}",
                "admin",
                "unit test",
                OffsetDateTime.now(),
                OffsetDateTime.now(),
                null
        ));

        assertThat(result.result()).isEqualTo("BLOCKED_CREDENTIAL");
        assertThat(result.lastError()).contains("max payload size");
    }

    @Test
    void signsPaymentProviderWebhookPayloadWhenSignatureSecretIsConfigured() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>("");
        AtomicReference<String> signatureHeader = new AtomicReference<>("");
        AtomicReference<String> timestampHeader = new AtomicReference<>("");
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/payment", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            signatureHeader.set(exchange.getRequestHeaders().getFirst("X-OSMU-Payment-Signature"));
            timestampHeader.set(exchange.getRequestHeaders().getFirst("X-OSMU-Payment-Timestamp"));
            exchange.sendResponseHeaders(200, -1);
            exchange.close();
        });
        server.start();
        try {
            String webhookUrl = "http://127.0.0.1:" + server.getAddress().getPort() + "/payment";
            WebhookChargebackPaymentProviderAdapter adapter =
                    new WebhookChargebackPaymentProviderAdapter(
                            OBJECT_MAPPER,
                            webhookUrl,
                            "",
                            "",
                            "payment-signing-secret",
                            "X-OSMU-Payment-Signature",
                            "X-OSMU-Payment-Timestamp",
                            3000,
                            65536,
                            true
                    );

            ChargebackPaymentProviderAdapterResult result = adapter.deliver(handoffRecord(
                    "{\"eventType\":\"chargeback.payment_provider.handoff\"}"
            ));

            String expectedSignature = "t=" + timestampHeader.get()
                    + ",v1=" + hmacSha256("payment-signing-secret", timestampHeader.get() + "." + requestBody.get());
            assertThat(result.result()).isEqualTo("SUCCESS");
            assertThat(signatureHeader.get()).isEqualTo(expectedSignature);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void rejectsInvalidPaymentProviderWebhookSignatureHeaderConfiguration() {
        WebhookChargebackPaymentProviderAdapter adapter =
                new WebhookChargebackPaymentProviderAdapter(
                        OBJECT_MAPPER,
                        "https://payments.example.com/osmu",
                        "",
                        "",
                        "payment-signing-secret",
                        "X-OSMU-Signature\nBad",
                        "X-OSMU-Signature-Timestamp",
                        3000,
                        65536,
                        false
                );

        assertThat(adapter.isConfigured()).isFalse();
    }

    private static ChargebackPaymentProviderHandoffRecord handoffRecord(String payloadJson) {
        return new ChargebackPaymentProviderHandoffRecord(
                16L,
                8L,
                "OSMU-FINAL-20260620-8",
                4L,
                "Payment Org",
                "KRW",
                BigDecimal.valueOf(1200L),
                "MANUAL_AP",
                "finance-ap",
                "PENDING_PAYMENT_PROVIDER_ADAPTER",
                0,
                null,
                payloadJson,
                "admin",
                "unit test",
                OffsetDateTime.now(),
                OffsetDateTime.now(),
                null
        );
    }

    private static String hmacSha256(String secret, String payload) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        return HexFormat.of().formatHex(mac.doFinal(payload.getBytes(StandardCharsets.UTF_8)));
    }
}
