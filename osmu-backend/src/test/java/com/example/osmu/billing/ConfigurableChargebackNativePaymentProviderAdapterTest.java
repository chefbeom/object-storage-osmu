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

class ConfigurableChargebackNativePaymentProviderAdapterTest {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    @Test
    void postsNativePaymentProviderHandoffWithAuthAndSignature() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>("");
        AtomicReference<String> authHeader = new AtomicReference<>("");
        AtomicReference<String> signatureHeader = new AtomicReference<>("");
        AtomicReference<String> timestampHeader = new AtomicReference<>("");
        AtomicReference<String> providerProfileHeader = new AtomicReference<>("");
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/native-bank", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            authHeader.set(exchange.getRequestHeaders().getFirst("X-Native-Token"));
            signatureHeader.set(exchange.getRequestHeaders().getFirst("X-OSMU-Native-Signature"));
            timestampHeader.set(exchange.getRequestHeaders().getFirst("X-OSMU-Native-Timestamp"));
            providerProfileHeader.set(exchange.getRequestHeaders().getFirst("X-OSMU-Provider-Profile"));
            exchange.sendResponseHeaders(200, -1);
            exchange.close();
        });
        server.start();
        try {
            ConfigurableChargebackNativePaymentProviderAdapter adapter = new ConfigurableChargebackNativePaymentProviderAdapter(
                    OBJECT_MAPPER,
                    "BANK",
                    "http://127.0.0.1:" + server.getAddress().getPort() + "/native-bank",
                    "X-Native-Token",
                    "Bearer bank-token",
                    "native-signing-secret",
                    "X-OSMU-Native-Signature",
                    "X-OSMU-Native-Timestamp",
                    3000,
                    65536,
                    true
            );

            ChargebackPaymentProviderAdapterResult result = adapter.deliver(handoffRecord(
                    "BANK_TRANSFER",
                    "{\"providerProfile\":\"BANK\",\"paymentReference\":\"OSMU-123\"}"
            ));

            String expectedSignature = "t=" + timestampHeader.get()
                    + ",v1=" + hmacSha256("native-signing-secret", timestampHeader.get() + "." + requestBody.get());
            assertThat(adapter.providerProfile()).isEqualTo("BANK");
            assertThat(adapter.isConfigured()).isTrue();
            assertThat(result.result()).isEqualTo("SUCCESS");
            assertThat(authHeader.get()).isEqualTo("Bearer bank-token");
            assertThat(signatureHeader.get()).isEqualTo(expectedSignature);
            assertThat(providerProfileHeader.get()).isEqualTo("BANK");
            assertThat(requestBody.get()).contains("\"eventType\":\"chargeback.payment_provider.native.handoff.delivery\"");
            assertThat(requestBody.get()).contains("\"providerProfile\":\"BANK\"");
            assertThat(requestBody.get()).contains("\"provider\":\"BANK_TRANSFER\"");
        } finally {
            server.stop(0);
        }
    }

    @Test
    void requiresAuthHeaderValueBeforeNativeApiIsConfigured() {
        ConfigurableChargebackNativePaymentProviderAdapter adapter = new ConfigurableChargebackNativePaymentProviderAdapter(
                OBJECT_MAPPER,
                "CARD",
                "https://card-provider.example.com/osmu",
                "Authorization",
                "",
                "",
                "X-OSMU-Native-Signature",
                "X-OSMU-Native-Timestamp",
                3000,
                65536,
                false
        );

        ChargebackPaymentProviderAdapterResult result = adapter.deliver(handoffRecord("CARD_PROCESSOR", "{}"));

        assertThat(adapter.isConfigured()).isFalse();
        assertThat(result.result()).isEqualTo("BLOCKED_CREDENTIAL");
        assertThat(result.lastError()).contains("auth header configuration is invalid");
    }

    @Test
    void blocksOversizedNativePayloadBeforeSending() {
        ConfigurableChargebackNativePaymentProviderAdapter adapter = new ConfigurableChargebackNativePaymentProviderAdapter(
                OBJECT_MAPPER,
                "TAX",
                "https://tax-provider.example.com/osmu",
                "Authorization",
                "Bearer tax-token",
                "",
                "X-OSMU-Native-Signature",
                "X-OSMU-Native-Timestamp",
                3000,
                1024,
                false
        );

        ChargebackPaymentProviderAdapterResult result = adapter.deliver(handoffRecord(
                "TAX_INVOICE",
                "{\"providerProfile\":\"TAX\",\"note\":\"" + "x".repeat(2048) + "\"}"
        ));

        assertThat(adapter.isConfigured()).isTrue();
        assertThat(result.result()).isEqualTo("BLOCKED_CREDENTIAL");
        assertThat(result.lastError()).contains("max payload size");
    }

    private static ChargebackPaymentProviderHandoffRecord handoffRecord(String provider, String payloadJson) {
        return new ChargebackPaymentProviderHandoffRecord(
                17L,
                8L,
                "OSMU-FINAL-20260620-8",
                4L,
                "Payment Org",
                "KRW",
                BigDecimal.valueOf(1200L),
                provider,
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