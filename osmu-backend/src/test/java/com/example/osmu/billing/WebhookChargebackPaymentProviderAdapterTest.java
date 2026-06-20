package com.example.osmu.billing;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
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
}
