package com.example.osmu.billing;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.math.BigDecimal;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
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
                    new WebhookChargebackNotificationDeliveryAdapter(
                            OBJECT_MAPPER,
                            "",
                            slackUrl,
                            "",
                            "",
                            "",
                            "",
                            "",
                            3000,
                            65536,
                            true,
                            "",
                            25,
                            "",
                            "osmu.local",
                            "[OSMU]",
                            "",
                            "",
                            false,
                            false
                    );

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

    @Test
    void sendsEmailPayloadWhenEmailChannelIsConfigured() throws Exception {
        try (FakeSmtpServer smtpServer = new FakeSmtpServer()) {
            WebhookChargebackNotificationDeliveryAdapter adapter =
                    new WebhookChargebackNotificationDeliveryAdapter(
                            OBJECT_MAPPER,
                            "",
                            "",
                            "",
                            "",
                            "",
                            "",
                            "",
                            3000,
                            65536,
                            false,
                            "127.0.0.1",
                            smtpServer.port(),
                            "billing@example.com",
                            "osmu.local",
                            "[OSMU]",
                            "",
                            "",
                            false,
                            true
                    );

            assertThat(adapter.isConfigured()).isTrue();
            assertThat(adapter.isConfigured("EMAIL")).isTrue();
            assertThat(adapter.isConfigured("WEBHOOK")).isFalse();

            ChargebackNotificationDeliveryAdapterResult result = adapter.deliver(new ChargebackAlertNotificationDeliveryRecord(
                    11L,
                    9L,
                    "Email Org",
                    "WARNING",
                    BigDecimal.valueOf(75L),
                    BigDecimal.valueOf(70L),
                    BigDecimal.valueOf(100L),
                    "EMAIL",
                    "finance@example.com",
                    "PENDING_DELIVERY_ADAPTER",
                    0,
                    null,
                    "Chargeback warning threshold crossed",
                    "Email Org exceeded the warning billing threshold.",
                    "{\"eventType\":\"chargeback.threshold\"}",
                    "admin",
                    "unit test",
                    OffsetDateTime.now(),
                    OffsetDateTime.now(),
                    null
            ));

            assertThat(result.result()).isEqualTo("SUCCESS");
            assertThat(smtpServer.awaitMessage()).isTrue();
            assertThat(smtpServer.commands()).contains("MAIL FROM:<billing@example.com>");
            assertThat(smtpServer.commands()).contains("RCPT TO:<finance@example.com>");
            assertThat(smtpServer.message()).contains("X-OSMU-Event-Type: chargeback.threshold.email.delivery");
            assertThat(smtpServer.message()).contains("Email Org exceeded the warning billing threshold.");
            assertThat(smtpServer.message()).contains("{\"eventType\":\"chargeback.threshold\"}");
        }
    }

    @Test
    void doesNotConfigurePrivateEmailRelayByDefault() {
        WebhookChargebackNotificationDeliveryAdapter adapter =
                new WebhookChargebackNotificationDeliveryAdapter(
                        OBJECT_MAPPER,
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        3000,
                        65536,
                        false,
                        "127.0.0.1",
                        25,
                        "billing@example.com",
                        "osmu.local",
                        "[OSMU]",
                        "",
                        "",
                        false,
                        false
                );

        assertThat(adapter.isConfigured("EMAIL")).isFalse();
    }

    @Test
    void blocksOversizedGenericWebhookPayloadBeforeSending() {
        WebhookChargebackNotificationDeliveryAdapter adapter =
                new WebhookChargebackNotificationDeliveryAdapter(
                        OBJECT_MAPPER,
                        "https://hooks.example.com/osmu",
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        3000,
                        1024,
                        false,
                        "",
                        25,
                        "",
                        "osmu.local",
                        "[OSMU]",
                        "",
                        "",
                        false,
                        false
                );

        ChargebackNotificationDeliveryAdapterResult result = adapter.deliver(new ChargebackAlertNotificationDeliveryRecord(
                12L,
                10L,
                "Oversized Org",
                "WARNING",
                BigDecimal.valueOf(100L),
                BigDecimal.valueOf(70L),
                BigDecimal.valueOf(100L),
                "WEBHOOK",
                "ops-webhook",
                "PENDING_DELIVERY_ADAPTER",
                0,
                null,
                "Chargeback warning threshold crossed",
                "x".repeat(2048),
                "{\"eventType\":\"chargeback.threshold\"}",
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
    void signsGenericWebhookPayloadWhenSignatureSecretIsConfigured() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>("");
        AtomicReference<String> signatureHeader = new AtomicReference<>("");
        AtomicReference<String> timestampHeader = new AtomicReference<>("");
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/webhook", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            signatureHeader.set(exchange.getRequestHeaders().getFirst("X-OSMU-Test-Signature"));
            timestampHeader.set(exchange.getRequestHeaders().getFirst("X-OSMU-Test-Timestamp"));
            exchange.sendResponseHeaders(200, -1);
            exchange.close();
        });
        server.start();
        try {
            String webhookUrl = "http://127.0.0.1:" + server.getAddress().getPort() + "/webhook";
            WebhookChargebackNotificationDeliveryAdapter adapter =
                    new WebhookChargebackNotificationDeliveryAdapter(
                            OBJECT_MAPPER,
                            webhookUrl,
                            "",
                            "",
                            "",
                            "notification-signing-secret",
                            "X-OSMU-Test-Signature",
                            "X-OSMU-Test-Timestamp",
                            3000,
                            65536,
                            true,
                            "",
                            25,
                            "",
                            "osmu.local",
                            "[OSMU]",
                            "",
                            "",
                            false,
                            false
                    );

            ChargebackNotificationDeliveryAdapterResult result = adapter.deliver(new ChargebackAlertNotificationDeliveryRecord(
                    13L,
                    11L,
                    "Signed Org",
                    "WARNING",
                    BigDecimal.valueOf(200L),
                    BigDecimal.valueOf(100L),
                    BigDecimal.valueOf(300L),
                    "WEBHOOK",
                    "signed-webhook",
                    "PENDING_DELIVERY_ADAPTER",
                    0,
                    null,
                    "Chargeback warning threshold crossed",
                    "Signed Org exceeded the warning billing threshold.",
                    "{\"eventType\":\"chargeback.threshold\"}",
                    "admin",
                    "unit test",
                    OffsetDateTime.now(),
                    OffsetDateTime.now(),
                    null
            ));

            String expectedSignature = "t=" + timestampHeader.get()
                    + ",v1=" + hmacSha256("notification-signing-secret", timestampHeader.get() + "." + requestBody.get());
            assertThat(result.result()).isEqualTo("SUCCESS");
            assertThat(signatureHeader.get()).isEqualTo(expectedSignature);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void rejectsInvalidGenericWebhookSignatureHeaderConfiguration() {
        WebhookChargebackNotificationDeliveryAdapter adapter =
                new WebhookChargebackNotificationDeliveryAdapter(
                        OBJECT_MAPPER,
                        "https://hooks.example.com/osmu",
                        "",
                        "",
                        "",
                        "notification-signing-secret",
                        "X-OSMU-Signature\nBad",
                        "X-OSMU-Signature-Timestamp",
                        3000,
                        65536,
                        false,
                        "",
                        25,
                        "",
                        "osmu.local",
                        "[OSMU]",
                        "",
                        "",
                        false,
                        false
                );

        assertThat(adapter.isConfigured("WEBHOOK")).isFalse();
    }

    private static String hmacSha256(String secret, String payload) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        return HexFormat.of().formatHex(mac.doFinal(payload.getBytes(StandardCharsets.UTF_8)));
    }

    private static final class FakeSmtpServer implements AutoCloseable {

        private final ServerSocket serverSocket;
        private final Thread worker;
        private final List<String> commands = new CopyOnWriteArrayList<>();
        private final AtomicReference<String> message = new AtomicReference<>("");
        private final CountDownLatch messageReceived = new CountDownLatch(1);

        private FakeSmtpServer() throws IOException {
            this.serverSocket = new ServerSocket(0, 1, java.net.InetAddress.getByName("127.0.0.1"));
            this.worker = new Thread(this::serve, "fake-smtp-server");
            this.worker.setDaemon(true);
            this.worker.start();
        }

        private int port() {
            return serverSocket.getLocalPort();
        }

        private List<String> commands() {
            return commands;
        }

        private String message() {
            return message.get();
        }

        private boolean awaitMessage() throws InterruptedException {
            return messageReceived.await(3, TimeUnit.SECONDS);
        }

        private void serve() {
            try (Socket socket = serverSocket.accept();
                 BufferedReader reader = new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8));
                 BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.UTF_8))) {
                send(writer, "220 fake smtp");
                String line;
                while ((line = reader.readLine()) != null) {
                    commands.add(line);
                    if (line.startsWith("EHLO") || line.startsWith("HELO")) {
                        send(writer, "250 fake smtp ready");
                    } else if (line.startsWith("MAIL FROM:") || line.startsWith("RCPT TO:")) {
                        send(writer, "250 ok");
                    } else if (line.equals("DATA")) {
                        send(writer, "354 end data with dot");
                        StringBuilder builder = new StringBuilder();
                        while ((line = reader.readLine()) != null && !".".equals(line)) {
                            builder.append(line).append('\n');
                        }
                        message.set(builder.toString());
                        messageReceived.countDown();
                        send(writer, "250 queued");
                    } else if (line.equals("QUIT")) {
                        send(writer, "221 bye");
                        return;
                    } else {
                        send(writer, "250 ok");
                    }
                }
            } catch (IOException ignored) {
                messageReceived.countDown();
            }
        }

        private static void send(BufferedWriter writer, String line) throws IOException {
            writer.write(line);
            writer.write("\r\n");
            writer.flush();
        }

        @Override
        public void close() throws IOException {
            serverSocket.close();
        }
    }
}
