package com.example.osmu.billing;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.Socket;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import javax.net.ssl.SSLSocketFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class WebhookChargebackNotificationDeliveryAdapter implements ChargebackNotificationDeliveryAdapter {

    private static final String DELIVERY_EVENT_TYPE = "chargeback.threshold.delivery";
    private static final String SLACK_DELIVERY_EVENT_TYPE = "chargeback.threshold.slack.delivery";
    private static final String EMAIL_DELIVERY_EVENT_TYPE = "chargeback.threshold.email.delivery";
    private static final int DEFAULT_TIMEOUT_MS = 3000;
    private static final int MIN_TIMEOUT_MS = 500;
    private static final int MAX_TIMEOUT_MS = 15000;
    private static final int SLACK_TEXT_LIMIT = 3000;
    private static final int EMAIL_BODY_LIMIT = 12000;

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final String webhookUrl;
    private final String slackWebhookUrl;
    private final String secretHeaderName;
    private final String secretHeaderValue;
    private final int timeoutMs;
    private final int maxPayloadBytes;
    private final boolean allowPrivateNetwork;
    private final String emailSmtpHost;
    private final int emailSmtpPort;
    private final String emailFrom;
    private final String emailHeloDomain;
    private final String emailSubjectPrefix;
    private final String emailUsername;
    private final String emailPassword;
    private final boolean emailStartTlsEnabled;
    private final boolean emailAllowPrivateNetwork;

    public WebhookChargebackNotificationDeliveryAdapter(
            ObjectMapper objectMapper,
            @Value("${osmu.billing.notification-delivery.webhook-url:}") String webhookUrl,
            @Value("${osmu.billing.notification-delivery.slack.webhook-url:}") String slackWebhookUrl,
            @Value("${osmu.billing.notification-delivery.secret-header-name:}") String secretHeaderName,
            @Value("${osmu.billing.notification-delivery.secret-header-value:}") String secretHeaderValue,
            @Value("${osmu.billing.notification-delivery.timeout-ms:3000}") int timeoutMs,
            @Value("${osmu.billing.notification-delivery.max-payload-bytes:65536}") int maxPayloadBytes,
            @Value("${osmu.billing.notification-delivery.allow-private-network:false}") boolean allowPrivateNetwork,
            @Value("${osmu.billing.notification-delivery.email.smtp-host:}") String emailSmtpHost,
            @Value("${osmu.billing.notification-delivery.email.smtp-port:25}") int emailSmtpPort,
            @Value("${osmu.billing.notification-delivery.email.from:}") String emailFrom,
            @Value("${osmu.billing.notification-delivery.email.helo-domain:osmu.local}") String emailHeloDomain,
            @Value("${osmu.billing.notification-delivery.email.subject-prefix:[OSMU]}") String emailSubjectPrefix,
            @Value("${osmu.billing.notification-delivery.email.username:}") String emailUsername,
            @Value("${osmu.billing.notification-delivery.email.password:}") String emailPassword,
            @Value("${osmu.billing.notification-delivery.email.starttls-enabled:false}") boolean emailStartTlsEnabled,
            @Value("${osmu.billing.notification-delivery.email.allow-private-network:false}") boolean emailAllowPrivateNetwork
    ) {
        this.objectMapper = objectMapper;
        this.webhookUrl = normalize(webhookUrl);
        this.slackWebhookUrl = normalize(slackWebhookUrl);
        this.secretHeaderName = normalize(secretHeaderName);
        this.secretHeaderValue = normalize(secretHeaderValue);
        this.timeoutMs = Math.max(MIN_TIMEOUT_MS, Math.min(timeoutMs <= 0 ? DEFAULT_TIMEOUT_MS : timeoutMs, MAX_TIMEOUT_MS));
        this.maxPayloadBytes = ExternalAdapterPayloadPolicy.normalizeMaxPayloadBytes(maxPayloadBytes);
        this.allowPrivateNetwork = allowPrivateNetwork;
        this.emailSmtpHost = normalize(emailSmtpHost);
        this.emailSmtpPort = normalizePort(emailSmtpPort);
        this.emailFrom = normalize(emailFrom);
        this.emailHeloDomain = normalize(emailHeloDomain).isBlank() ? "osmu.local" : normalize(emailHeloDomain);
        this.emailSubjectPrefix = normalize(emailSubjectPrefix);
        this.emailUsername = normalize(emailUsername);
        this.emailPassword = normalize(emailPassword);
        this.emailStartTlsEnabled = emailStartTlsEnabled;
        this.emailAllowPrivateNetwork = emailAllowPrivateNetwork;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(this.timeoutMs))
                .build();
    }

    @Override
    public boolean isConfigured() {
        return genericWebhookIsConfigured() || configuredUri(slackWebhookUrl) != null || emailIsConfigured();
    }

    @Override
    public boolean isConfigured(String channel) {
        if (slackChannel(channel)) {
            return configuredUri(slackWebhookUrl) != null || genericWebhookIsConfigured();
        }
        if (emailChannel(channel)) {
            return emailIsConfigured() || genericWebhookIsConfigured();
        }
        return genericWebhookIsConfigured();
    }

    @Override
    public ChargebackNotificationDeliveryAdapterResult deliver(ChargebackAlertNotificationDeliveryRecord record) {
        URI slackUri = configuredUri(slackWebhookUrl);
        if (slackChannel(record.channel()) && slackUri != null) {
            return deliverSlack(record, slackUri);
        }
        if (emailChannel(record.channel()) && emailIsConfigured()) {
            return deliverEmail(record);
        }
        return deliverGeneric(record);
    }

    private ChargebackNotificationDeliveryAdapterResult deliverGeneric(ChargebackAlertNotificationDeliveryRecord record) {
        URI uri = configuredUri(webhookUrl);
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
        if (payloadExceedsLimit(requestBody)) {
            return ChargebackNotificationDeliveryAdapterResult.blocked("Notification webhook payload exceeds the configured max payload size.");
        }

        try {
            HttpRequest.Builder requestBuilder = HttpRequest.newBuilder(uri)
                    .timeout(Duration.ofMillis(timeoutMs))
                    .header("Content-Type", "application/json")
                    .header("X-OSMU-Event-Type", DELIVERY_EVENT_TYPE)
                    .header("X-OSMU-Delivery-Id", String.valueOf(record.id() == null ? 0L : record.id()))
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody));
            if (!secretHeaderName.isBlank() && !secretHeaderValue.isBlank()) {
                requestBuilder.header(secretHeaderName, secretHeaderValue);
            }
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

    private ChargebackNotificationDeliveryAdapterResult deliverSlack(
            ChargebackAlertNotificationDeliveryRecord record,
            URI uri
    ) {
        String requestBody;
        try {
            requestBody = objectMapper.writeValueAsString(slackEnvelope(record));
        } catch (JsonProcessingException exception) {
            return ChargebackNotificationDeliveryAdapterResult.blocked("Slack notification payload serialization failed.");
        }
        if (payloadExceedsLimit(requestBody)) {
            return ChargebackNotificationDeliveryAdapterResult.blocked("Slack notification payload exceeds the configured max payload size.");
        }

        try {
            HttpResponse<Void> httpResponse = httpClient.send(
                    HttpRequest.newBuilder(uri)
                            .timeout(Duration.ofMillis(timeoutMs))
                            .header("Content-Type", "application/json")
                            .header("X-OSMU-Event-Type", SLACK_DELIVERY_EVENT_TYPE)
                            .header("X-OSMU-Delivery-Id", String.valueOf(record.id() == null ? 0L : record.id()))
                            .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                            .build(),
                    HttpResponse.BodyHandlers.discarding()
            );
            int statusCode = httpResponse.statusCode();
            if (statusCode >= 200 && statusCode < 300) {
                return ChargebackNotificationDeliveryAdapterResult.success();
            }
            if (statusCode == 429 || statusCode >= 500) {
                return ChargebackNotificationDeliveryAdapterResult.retry(
                        "Slack notification webhook returned retryable HTTP " + statusCode + "."
                );
            }
            return ChargebackNotificationDeliveryAdapterResult.blocked(
                    "Slack notification webhook returned non-retryable HTTP " + statusCode + "."
            );
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return ChargebackNotificationDeliveryAdapterResult.retry("Slack notification webhook request was interrupted.");
        } catch (IOException | IllegalArgumentException exception) {
            return ChargebackNotificationDeliveryAdapterResult.retry("Slack notification webhook request failed; retry scheduled.");
        }
    }

    private ChargebackNotificationDeliveryAdapterResult deliverEmail(ChargebackAlertNotificationDeliveryRecord record) {
        if (!emailIsConfigured()) {
            return ChargebackNotificationDeliveryAdapterResult.blocked("Email notification adapter is not configured.");
        }
        String recipient = emailAddress(record.target());
        if (recipient.isBlank()) {
            return ChargebackNotificationDeliveryAdapterResult.blocked("Email notification target must be a single email address.");
        }
        String requestBody = emailMessage(record, recipient);
        if (payloadExceedsLimit(requestBody)) {
            return ChargebackNotificationDeliveryAdapterResult.blocked("Email notification payload exceeds the configured max payload size.");
        }
        try {
            sendEmail(recipient, requestBody);
            return ChargebackNotificationDeliveryAdapterResult.success();
        } catch (SmtpCommandException exception) {
            if (exception.retryable()) {
                return ChargebackNotificationDeliveryAdapterResult.retry("Email SMTP relay returned a retryable error.");
            }
            return ChargebackNotificationDeliveryAdapterResult.blocked("Email SMTP relay rejected the notification.");
        } catch (IOException | IllegalArgumentException exception) {
            return ChargebackNotificationDeliveryAdapterResult.retry("Email SMTP relay request failed; retry scheduled.");
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

    private Map<String, Object> slackEnvelope(ChargebackAlertNotificationDeliveryRecord record) {
        Map<String, Object> envelope = new LinkedHashMap<>();
        envelope.put("text", truncate(slackText(record), SLACK_TEXT_LIMIT));
        return envelope;
    }

    private String emailMessage(ChargebackAlertNotificationDeliveryRecord record, String recipient) {
        String deliveryId = String.valueOf(record.id() == null ? 0L : record.id());
        String subject = emailSubject(record);
        String payload = record.payloadJson() == null ? "" : truncate(record.payloadJson(), EMAIL_BODY_LIMIT);
        String body = """
                Chargeback threshold alert

                Organization: %s
                Severity: %s
                Estimated total cost: %s
                Warning threshold: %s
                Critical threshold: %s

                %s

                %s

                Payload:
                %s
                """.formatted(
                bodyText(record.organizationName()),
                bodyText(record.severity()),
                decimalText(record.estimatedTotalCost()),
                decimalText(record.warningAmount()),
                decimalText(record.criticalAmount()),
                bodyText(record.subject()),
                bodyText(record.message()),
                bodyText(payload)
        );
        return "From: <" + emailFrom + ">\r\n"
                + "To: <" + recipient + ">\r\n"
                + "Subject: " + encodedHeader(subject) + "\r\n"
                + "Date: " + DateTimeFormatter.RFC_1123_DATE_TIME.format(OffsetDateTime.now()) + "\r\n"
                + "Message-ID: <osmu-chargeback-" + deliveryId + "-" + System.currentTimeMillis() + "@osmu.local>\r\n"
                + "MIME-Version: 1.0\r\n"
                + "Content-Type: text/plain; charset=UTF-8\r\n"
                + "Content-Transfer-Encoding: 8bit\r\n"
                + "X-OSMU-Event-Type: " + EMAIL_DELIVERY_EVENT_TYPE + "\r\n"
                + "X-OSMU-Delivery-Id: " + deliveryId + "\r\n"
                + "\r\n"
                + body.replace("\n", "\r\n");
    }

    private String emailSubject(ChargebackAlertNotificationDeliveryRecord record) {
        String prefix = emailSubjectPrefix.isBlank() ? "" : emailSubjectPrefix + " ";
        return prefix + normalize(record.severity()) + " chargeback alert - " + normalize(record.organizationName());
    }

    private void sendEmail(String recipient, String message) throws IOException {
        Socket socket = new Socket();
        SmtpConnection connection = null;
        try {
            socket.connect(new InetSocketAddress(emailSmtpHost, emailSmtpPort), timeoutMs);
            socket.setSoTimeout(timeoutMs);
            connection = SmtpConnection.open(socket);
            connection.expect(220);
            sendEhlo(connection);
            if (emailStartTlsEnabled) {
                connection.command("STARTTLS", 220);
                Socket tlsSocket = ((SSLSocketFactory) SSLSocketFactory.getDefault())
                        .createSocket(socket, emailSmtpHost, emailSmtpPort, true);
                tlsSocket.setSoTimeout(timeoutMs);
                connection = SmtpConnection.open(tlsSocket);
                sendEhlo(connection);
            }
            if (!emailUsername.isBlank() || !emailPassword.isBlank()) {
                String authPlain = "\0" + emailUsername + "\0" + emailPassword;
                connection.command(
                        "AUTH PLAIN " + Base64.getEncoder().encodeToString(authPlain.getBytes(StandardCharsets.UTF_8)),
                        235
                );
            }
            connection.command("MAIL FROM:<" + emailFrom + ">", 250);
            connection.command("RCPT TO:<" + recipient + ">", 250, 251);
            connection.command("DATA", 354);
            connection.data(message);
            connection.command("QUIT", 221);
        } finally {
            if (connection != null) {
                connection.close();
            } else {
                socket.close();
            }
        }
    }

    private void sendEhlo(SmtpConnection connection) throws IOException {
        try {
            connection.command("EHLO " + emailHeloDomain, 250);
        } catch (SmtpCommandException exception) {
            if (exception.retryable()) {
                throw exception;
            }
            connection.command("HELO " + emailHeloDomain, 250);
        }
    }

    private static String slackText(ChargebackAlertNotificationDeliveryRecord record) {
        String amount = record.estimatedTotalCost() == null ? "0" : record.estimatedTotalCost().toPlainString();
        return "[OSMU] " + normalize(record.severity()) + " chargeback alert - " + normalize(record.organizationName())
                + "\n" + normalize(record.subject())
                + "\n" + normalize(record.message())
                + "\nAmount: " + amount
                + "\nTarget: " + normalize(record.target());
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

    private boolean payloadExceedsLimit(String value) {
        return ExternalAdapterPayloadPolicy.exceedsMaxPayloadBytes(value, maxPayloadBytes);
    }

    private boolean genericWebhookIsConfigured() {
        return configuredUri(webhookUrl) != null && secretHeaderConfigIsValid();
    }

    private boolean emailIsConfigured() {
        return validSmtpHost(emailSmtpHost)
                && emailSmtpPort > 0
                && validEmailAddress(emailFrom)
                && validHeloDomain(emailHeloDomain)
                && emailAuthConfigIsValid()
                && (emailAllowPrivateNetwork || !WebhookEndpointPolicy.isPrivateOrLocalHost(emailSmtpHost));
    }

    private URI configuredUri(String value) {
        return WebhookEndpointPolicy.configuredUri(value, allowPrivateNetwork);
    }

    private static boolean slackChannel(String value) {
        return "SLACK".equals(normalize(value).toUpperCase(Locale.ROOT));
    }

    private static boolean emailChannel(String value) {
        return "EMAIL".equals(normalize(value).toUpperCase(Locale.ROOT));
    }

    private static String truncate(String value, int limit) {
        if (value.length() <= limit) {
            return value;
        }
        return value.substring(0, limit - 3) + "...";
    }

    private static int normalizePort(int value) {
        return value >= 1 && value <= 65535 ? value : -1;
    }

    private boolean secretHeaderConfigIsValid() {
        if (secretHeaderName.isBlank() && secretHeaderValue.isBlank()) {
            return true;
        }
        return validHeaderName(secretHeaderName) && !secretHeaderValue.isBlank() && !containsLineBreak(secretHeaderValue);
    }

    private boolean emailAuthConfigIsValid() {
        if (emailUsername.isBlank() && emailPassword.isBlank()) {
            return true;
        }
        return !emailUsername.isBlank()
                && !emailPassword.isBlank()
                && !containsLineBreak(emailUsername)
                && !containsLineBreak(emailPassword);
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

    private static boolean validSmtpHost(String value) {
        if (value.isBlank() || value.length() > 253 || containsLineBreak(value)) {
            return false;
        }
        if (value.contains("/") || value.contains("\\") || value.contains("@")) {
            return false;
        }
        for (int index = 0; index < value.length(); index += 1) {
            if (Character.isWhitespace(value.charAt(index))) {
                return false;
            }
        }
        return true;
    }

    private static boolean validHeloDomain(String value) {
        return validSmtpHost(value) && !value.contains(":");
    }

    private static String emailAddress(String value) {
        String normalized = normalize(value);
        return validEmailAddress(normalized) ? normalized : "";
    }

    private static boolean validEmailAddress(String value) {
        if (value == null || value.isBlank() || value.length() > 254 || containsLineBreak(value)) {
            return false;
        }
        if (value.contains("<") || value.contains(">") || value.contains(",") || value.contains(";")) {
            return false;
        }
        for (int index = 0; index < value.length(); index += 1) {
            if (Character.isWhitespace(value.charAt(index))) {
                return false;
            }
        }
        int separator = value.indexOf('@');
        if (separator <= 0 || separator != value.lastIndexOf('@') || separator == value.length() - 1) {
            return false;
        }
        String local = value.substring(0, separator);
        String domain = value.substring(separator + 1);
        return local.length() <= 64
                && domain.length() <= 253
                && !local.startsWith(".")
                && !local.endsWith(".")
                && !domain.startsWith(".")
                && !domain.endsWith(".");
    }

    private static boolean containsLineBreak(String value) {
        return value.contains("\r") || value.contains("\n");
    }

    private static String encodedHeader(String value) {
        String safeValue = normalize(value).replace("\r", " ").replace("\n", " ");
        return "=?UTF-8?B?" + Base64.getEncoder().encodeToString(safeValue.getBytes(StandardCharsets.UTF_8)) + "?=";
    }

    private static String bodyText(String value) {
        return normalize(value).replace("\r", " ").trim();
    }

    private static String decimalText(Object value) {
        return value == null ? "0" : String.valueOf(value);
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim();
    }

    private static final class SmtpConnection implements AutoCloseable {

        private final Socket socket;
        private final BufferedReader reader;
        private final BufferedWriter writer;

        private SmtpConnection(Socket socket, BufferedReader reader, BufferedWriter writer) {
            this.socket = socket;
            this.reader = reader;
            this.writer = writer;
        }

        private static SmtpConnection open(Socket socket) throws IOException {
            return new SmtpConnection(
                    socket,
                    new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8)),
                    new BufferedWriter(new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.UTF_8))
            );
        }

        private void expect(int... expectedCodes) throws IOException {
            int code = readResponseCode();
            if (!expected(code, expectedCodes)) {
                throw new SmtpCommandException(code);
            }
        }

        private void command(String command, int... expectedCodes) throws IOException {
            writer.write(command);
            writer.write("\r\n");
            writer.flush();
            expect(expectedCodes);
        }

        private void data(String message) throws IOException {
            String normalizedMessage = message.replace("\r\n", "\n").replace('\r', '\n');
            for (String line : normalizedMessage.split("\n", -1)) {
                if (line.startsWith(".")) {
                    writer.write('.');
                }
                writer.write(line);
                writer.write("\r\n");
            }
            writer.write(".\r\n");
            writer.flush();
            expect(250);
        }

        private int readResponseCode() throws IOException {
            String line;
            int code = -1;
            do {
                line = reader.readLine();
                if (line == null || line.length() < 3) {
                    throw new IOException("SMTP relay closed the connection.");
                }
                try {
                    code = Integer.parseInt(line.substring(0, 3));
                } catch (NumberFormatException exception) {
                    throw new IOException("SMTP relay returned an invalid response.");
                }
            } while (line.length() > 3 && line.charAt(3) == '-');
            return code;
        }

        private static boolean expected(int code, int[] expectedCodes) {
            for (int expectedCode : expectedCodes) {
                if (code == expectedCode) {
                    return true;
                }
            }
            return false;
        }

        @Override
        public void close() throws IOException {
            socket.close();
        }
    }

    private static final class SmtpCommandException extends IOException {

        private final int code;

        private SmtpCommandException(int code) {
            this.code = code;
        }

        private boolean retryable() {
            return code >= 400 && code < 500;
        }
    }
}
