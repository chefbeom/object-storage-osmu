package com.example.osmu.billing;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.billing.repository.ChargebackNotificationDeliveryRepository;
import com.example.osmu.billing.repository.ChargebackPaymentProviderHandoffRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class ChargebackAdapterRetryWorkerService {

    private static final String SYSTEM_ACTOR = "system";
    private static final String NOTIFICATION_BLOCKED_STATUS = "DELIVERY_ADAPTER_BLOCKED_CREDENTIAL";
    private static final String PAYMENT_BLOCKED_STATUS = "PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL";
    private static final String NOTIFICATION_BLOCKED_ERROR =
            "Notification adapter retry worker blocked because delivery adapter credentials/configuration are not configured.";
    private static final String PAYMENT_BLOCKED_ERROR =
            "Payment provider adapter retry worker blocked because payment adapter credentials/configuration are not configured.";

    private final ChargebackNotificationDeliveryAdapter notificationDeliveryAdapter;
    private final ChargebackPaymentProviderAdapter paymentProviderAdapter;
    private final ChargebackNotificationDeliveryRepository notificationDeliveryRepository;
    private final ChargebackPaymentProviderHandoffRepository paymentHandoffRepository;
    private final AuditLogService auditLogService;
    private final Counter blockedNotificationCounter;
    private final Counter blockedPaymentCounter;
    private final boolean scheduledWorkerEnabled;
    private final int batchSize;

    public ChargebackAdapterRetryWorkerService(
            ChargebackNotificationDeliveryAdapter notificationDeliveryAdapter,
            ChargebackPaymentProviderAdapter paymentProviderAdapter,
            ChargebackNotificationDeliveryRepository notificationDeliveryRepository,
            ChargebackPaymentProviderHandoffRepository paymentHandoffRepository,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry,
            @Value("${osmu.billing.adapter-retry-worker.enabled:false}") boolean scheduledWorkerEnabled,
            @Value("${osmu.billing.adapter-retry-worker.batch-size:50}") int batchSize
    ) {
        this.notificationDeliveryAdapter = notificationDeliveryAdapter;
        this.paymentProviderAdapter = paymentProviderAdapter;
        this.notificationDeliveryRepository = notificationDeliveryRepository;
        this.paymentHandoffRepository = paymentHandoffRepository;
        this.auditLogService = auditLogService;
        this.scheduledWorkerEnabled = scheduledWorkerEnabled;
        this.batchSize = normalizeLimit(batchSize);
        this.blockedNotificationCounter = Counter.builder("osmu.chargeback.adapter.retry.worker.items")
                .description("Chargeback adapter retry worker item transitions")
                .tag("itemType", "notification")
                .tag("result", "blocked")
                .register(meterRegistry);
        this.blockedPaymentCounter = Counter.builder("osmu.chargeback.adapter.retry.worker.items")
                .description("Chargeback adapter retry worker item transitions")
                .tag("itemType", "payment")
                .tag("result", "blocked")
                .register(meterRegistry);
    }

    public ChargebackAdapterRetryWorkerRunResponse status(AuthenticatedUser actor, int limit) {
        requireAdmin(actor);
        return run(actor.loginId(), true, limit, OffsetDateTime.now());
    }

    public ChargebackAdapterRetryWorkerRunResponse runFromAdmin(AuthenticatedUser actor, boolean dryRun, int limit) {
        requireAdmin(actor);
        return run(actor.loginId(), dryRun, limit, OffsetDateTime.now());
    }

    public ChargebackAdapterRetryWorkerRunResponse runScheduled(OffsetDateTime now) {
        return run(SYSTEM_ACTOR, false, batchSize, now);
    }

    private ChargebackAdapterRetryWorkerRunResponse run(String actor, boolean dryRun, int limit, OffsetDateTime now) {
        int normalizedLimit = normalizeLimit(limit);
        int notificationLimit = Math.max(1, normalizedLimit / 2);
        int paymentLimit = normalizedLimit - notificationLimit;
        if (paymentLimit < 1) {
            paymentLimit = 1;
        }
        List<ChargebackAlertNotificationDeliveryRecord> notificationCandidates =
                notificationDeliveryRepository.findDueAdapterRetries(now, notificationLimit);
        List<ChargebackPaymentProviderHandoffRecord> paymentCandidates =
                paymentHandoffRepository.findDueAdapterRetries(now, paymentLimit);
        List<ChargebackAdapterRetryWorkerItemResponse> items = new ArrayList<>();
        boolean notificationAdapterConfigured = notificationDeliveryAdapter.isConfigured();
        boolean paymentAdapterConfigured = paymentProviderAdapter.isConfigured();
        boolean externalAdaptersEnabled = notificationAdapterConfigured || paymentAdapterConfigured;
        int updatedCount = 0;

        for (ChargebackAlertNotificationDeliveryRecord record : notificationCandidates) {
            boolean channelAdapterConfigured = notificationDeliveryAdapter.isConfigured(record.channel());
            if (dryRun) {
                items.add(notificationItem(record, null, true, channelAdapterConfigured));
            } else {
                ChargebackAlertNotificationDeliveryRecord updated = channelAdapterConfigured
                        ? attemptNotificationDelivery(record, now)
                        : blockNotification(record, now);
                notificationDeliveryRepository.update(updated);
                if (NOTIFICATION_BLOCKED_STATUS.equals(updated.status())) {
                    blockedNotificationCounter.increment();
                }
                items.add(notificationItem(record, updated, false, channelAdapterConfigured));
                updatedCount += 1;
            }
        }
        for (ChargebackPaymentProviderHandoffRecord record : paymentCandidates) {
            if (dryRun) {
                items.add(paymentItem(record, null, true, paymentAdapterConfigured));
            } else {
                ChargebackPaymentProviderHandoffRecord updated = paymentAdapterConfigured
                        ? attemptPaymentProviderHandoff(record, now)
                        : blockPayment(record, now);
                paymentHandoffRepository.update(updated);
                if (PAYMENT_BLOCKED_STATUS.equals(updated.status())) {
                    blockedPaymentCounter.increment();
                }
                items.add(paymentItem(record, updated, false, paymentAdapterConfigured));
                updatedCount += 1;
            }
        }
        if (!dryRun && updatedCount > 0) {
            recordAudit(actor, updatedCount, notificationAdapterConfigured, paymentAdapterConfigured);
        }
        return new ChargebackAdapterRetryWorkerRunResponse(
                "ADAPTER_RETRY_WORKER",
                scheduledWorkerEnabled,
                dryRun,
                externalAdaptersEnabled,
                normalizedLimit,
                notificationCandidates.size(),
                paymentCandidates.size(),
                updatedCount,
                items,
                now,
                dryRun
                        ? "Dry-run only; no external adapter calls or status updates were performed."
                        : retryWorkerRunNote(notificationAdapterConfigured, paymentAdapterConfigured)
        );
    }

    private static ChargebackAdapterRetryWorkerItemResponse notificationItem(
            ChargebackAlertNotificationDeliveryRecord record,
            ChargebackAlertNotificationDeliveryRecord updated,
            boolean dryRun,
            boolean adapterConfigured
    ) {
        String toStatus = dryRun
                ? (adapterConfigured ? "DELIVERY_ADAPTER_SEND_ATTEMPT" : NOTIFICATION_BLOCKED_STATUS)
                : updated.status();
        int attemptCount = dryRun ? record.attemptCount() : updated.attemptCount();
        OffsetDateTime nextAttemptAt = dryRun ? record.nextAttemptAt() : updated.nextAttemptAt();
        return new ChargebackAdapterRetryWorkerItemResponse(
                "NOTIFICATION",
                record.id() == null ? 0L : record.id(),
                record.status(),
                toStatus,
                attemptCount,
                nextAttemptAt,
                notificationRetryWorkerItemNote(dryRun, adapterConfigured, toStatus, updated)
        );
    }

    private static ChargebackAdapterRetryWorkerItemResponse paymentItem(
            ChargebackPaymentProviderHandoffRecord record,
            ChargebackPaymentProviderHandoffRecord updated,
            boolean dryRun,
            boolean adapterConfigured
    ) {
        String toStatus = dryRun
                ? (adapterConfigured ? "PAYMENT_PROVIDER_ADAPTER_SEND_ATTEMPT" : PAYMENT_BLOCKED_STATUS)
                : updated.status();
        int attemptCount = dryRun ? record.attemptCount() : updated.attemptCount();
        OffsetDateTime nextAttemptAt = dryRun ? record.nextAttemptAt() : updated.nextAttemptAt();
        return new ChargebackAdapterRetryWorkerItemResponse(
                "PAYMENT_PROVIDER",
                record.id() == null ? 0L : record.id(),
                record.status(),
                toStatus,
                attemptCount,
                nextAttemptAt,
                paymentRetryWorkerItemNote(dryRun, adapterConfigured, toStatus, updated)
        );
    }

    private static ChargebackAlertNotificationDeliveryRecord blockNotification(
            ChargebackAlertNotificationDeliveryRecord record,
            OffsetDateTime now
    ) {
        return new ChargebackAlertNotificationDeliveryRecord(
                record.id(),
                record.organizationId(),
                record.organizationName(),
                record.severity(),
                record.estimatedTotalCost(),
                record.warningAmount(),
                record.criticalAmount(),
                record.channel(),
                record.target(),
                NOTIFICATION_BLOCKED_STATUS,
                record.attemptCount() + 1,
                null,
                record.subject(),
                record.message(),
                record.payloadJson(),
                record.requestedBy(),
                record.reason(),
                record.createdAt(),
                now,
                NOTIFICATION_BLOCKED_ERROR
        );
    }

    private ChargebackAlertNotificationDeliveryRecord attemptNotificationDelivery(
            ChargebackAlertNotificationDeliveryRecord record,
            OffsetDateTime now
    ) {
        ChargebackNotificationDeliveryAdapterResult adapterResult = notificationDeliveryAdapter.deliver(record);
        String result = normalizeAdapterResult(adapterResult.result());
        return new ChargebackAlertNotificationDeliveryRecord(
                record.id(),
                record.organizationId(),
                record.organizationName(),
                record.severity(),
                record.estimatedTotalCost(),
                record.warningAmount(),
                record.criticalAmount(),
                record.channel(),
                record.target(),
                notificationAdapterStatus(result),
                record.attemptCount() + 1,
                adapterNextAttemptAt(result, adapterResult.nextAttemptAt(), now),
                record.subject(),
                record.message(),
                record.payloadJson(),
                record.requestedBy(),
                record.reason(),
                record.createdAt(),
                now,
                adapterLastError(
                        result,
                        adapterResult.lastError(),
                        "Notification webhook adapter retry scheduled.",
                        "Notification webhook adapter blocked this delivery row."
                )
        );
    }

    private static ChargebackPaymentProviderHandoffRecord blockPayment(
            ChargebackPaymentProviderHandoffRecord record,
            OffsetDateTime now
    ) {
        return new ChargebackPaymentProviderHandoffRecord(
                record.id(),
                record.finalInvoiceId(),
                record.invoiceNumber(),
                record.organizationId(),
                record.organizationName(),
                record.currency(),
                record.amount(),
                record.provider(),
                record.targetAccount(),
                PAYMENT_BLOCKED_STATUS,
                record.attemptCount() + 1,
                null,
                record.payloadJson(),
                record.requestedBy(),
                record.reason(),
                record.createdAt(),
                now,
                PAYMENT_BLOCKED_ERROR
        );
    }

    private ChargebackPaymentProviderHandoffRecord attemptPaymentProviderHandoff(
            ChargebackPaymentProviderHandoffRecord record,
            OffsetDateTime now
    ) {
        ChargebackPaymentProviderAdapterResult adapterResult = paymentProviderAdapter.deliver(record);
        String result = normalizeAdapterResult(adapterResult.result());
        return new ChargebackPaymentProviderHandoffRecord(
                record.id(),
                record.finalInvoiceId(),
                record.invoiceNumber(),
                record.organizationId(),
                record.organizationName(),
                record.currency(),
                record.amount(),
                record.provider(),
                record.targetAccount(),
                paymentAdapterStatus(result),
                record.attemptCount() + 1,
                adapterNextAttemptAt(result, adapterResult.nextAttemptAt(), now),
                record.payloadJson(),
                record.requestedBy(),
                record.reason(),
                record.createdAt(),
                now,
                adapterLastError(
                        result,
                        adapterResult.lastError(),
                        "Payment provider webhook adapter retry scheduled.",
                        "Payment provider webhook adapter blocked this handoff row."
                )
        );
    }

    private void recordAudit(
            String actor,
            int updatedCount,
            boolean notificationAdapterConfigured,
            boolean paymentAdapterConfigured
    ) {
        auditLogService.record(
                "CHARGEBACK_ADAPTER_RETRY_WORKER_RUN",
                actor,
                "CHARGEBACK_ADAPTER_RETRY",
                "due-outbox",
                "SUCCESS",
                (notificationAdapterConfigured || paymentAdapterConfigured
                        ? "Chargeback adapter retry worker processed due rows; configured webhooks were attempted when eligible: "
                        : "Chargeback adapter retry worker blocked due rows without external calls: ")
                        + updatedCount
        );
    }

    private static String normalizeAdapterResult(String value) {
        String result = value == null || value.isBlank()
                ? "BLOCKED_CREDENTIAL"
                : value.trim().toUpperCase().replace('-', '_').replace(' ', '_');
        return List.of("SUCCESS", "RETRY", "BLOCKED_CREDENTIAL").contains(result)
                ? result
                : "BLOCKED_CREDENTIAL";
    }

    private static String notificationAdapterStatus(String result) {
        return switch (result) {
            case "SUCCESS" -> "DELIVERY_ADAPTER_SUCCEEDED";
            case "RETRY" -> "DELIVERY_ADAPTER_RETRY_SCHEDULED";
            default -> NOTIFICATION_BLOCKED_STATUS;
        };
    }

    private static String paymentAdapterStatus(String result) {
        return switch (result) {
            case "SUCCESS" -> "PAYMENT_PROVIDER_ADAPTER_SUCCEEDED";
            case "RETRY" -> "PAYMENT_PROVIDER_ADAPTER_RETRY_SCHEDULED";
            default -> PAYMENT_BLOCKED_STATUS;
        };
    }

    private static OffsetDateTime adapterNextAttemptAt(
            String result,
            OffsetDateTime adapterNextAttemptAt,
            OffsetDateTime now
    ) {
        if (!"RETRY".equals(result)) {
            return null;
        }
        if (adapterNextAttemptAt != null
                && adapterNextAttemptAt.isAfter(now)
                && !adapterNextAttemptAt.isAfter(now.plusMinutes(1440))) {
            return adapterNextAttemptAt;
        }
        return now.plusMinutes(60);
    }

    private static String adapterLastError(
            String result,
            String value,
            String retryFallback,
            String blockedFallback
    ) {
        if ("SUCCESS".equals(result)) {
            return null;
        }
        String fallback = "RETRY".equals(result) ? retryFallback : blockedFallback;
        String error = value == null || value.isBlank() ? fallback : value.trim();
        if (error.length() > 512 || error.contains("\r") || error.contains("\n") || containsCredentialTerm(error)) {
            return fallback;
        }
        return error;
    }

    private static boolean containsCredentialTerm(String value) {
        String text = value.toLowerCase();
        return text.contains("password")
                || text.contains("secret")
                || text.contains("token")
                || text.contains("authorization")
                || text.contains("bearer ")
                || text.contains("private key")
                || text.contains("access_key")
                || text.contains("secret_key");
    }

    private static String notificationRetryWorkerItemNote(
            boolean dryRun,
            boolean adapterConfigured,
            String toStatus,
            ChargebackAlertNotificationDeliveryRecord updated
    ) {
        if (dryRun) {
            return adapterConfigured
                    ? "Due notification adapter retry candidate; configured webhook adapter would be attempted."
                    : "Due notification adapter retry candidate.";
        }
        if ("DELIVERY_ADAPTER_SUCCEEDED".equals(toStatus)) {
            return "Notification webhook adapter delivered this due row.";
        }
        return updated.lastError();
    }

    private static String paymentRetryWorkerItemNote(
            boolean dryRun,
            boolean adapterConfigured,
            String toStatus,
            ChargebackPaymentProviderHandoffRecord updated
    ) {
        if (dryRun) {
            return adapterConfigured
                    ? "Due payment provider adapter retry candidate; configured webhook adapter would be attempted."
                    : "Due payment provider adapter retry candidate.";
        }
        if ("PAYMENT_PROVIDER_ADAPTER_SUCCEEDED".equals(toStatus)) {
            return "Payment provider webhook adapter delivered this due handoff row.";
        }
        return updated.lastError();
    }

    private static String retryWorkerRunNote(boolean notificationAdapterConfigured, boolean paymentAdapterConfigured) {
        if (notificationAdapterConfigured && paymentAdapterConfigured) {
            return "Configured notification and payment provider webhook adapters were attempted for due rows.";
        }
        if (notificationAdapterConfigured) {
            return "Configured notification webhook adapter was attempted for due notification rows; payment rows remain blocked until payment adapter configuration exists.";
        }
        if (paymentAdapterConfigured) {
            return "Configured payment provider webhook adapter was attempted for due payment handoff rows; notification rows remain blocked until notification adapter configuration exists.";
        }
        return "Due adapter retry rows were blocked because external adapter credentials/configuration are not configured.";
    }

    private static void requireAdmin(AuthenticatedUser actor) {
        if (actor == null) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Authentication required.");
        }
        if (!actor.isAdmin()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Chargeback adapter retry worker access denied.");
        }
    }

    private static int normalizeLimit(int limit) {
        return Math.max(1, Math.min(limit <= 0 ? 50 : limit, 200));
    }
}
