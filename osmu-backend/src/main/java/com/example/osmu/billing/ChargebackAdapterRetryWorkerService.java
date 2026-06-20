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
    private final ChargebackNotificationDeliveryRepository notificationDeliveryRepository;
    private final ChargebackPaymentProviderHandoffRepository paymentHandoffRepository;
    private final AuditLogService auditLogService;
    private final Counter blockedNotificationCounter;
    private final Counter blockedPaymentCounter;
    private final boolean scheduledWorkerEnabled;
    private final int batchSize;

    public ChargebackAdapterRetryWorkerService(
            ChargebackNotificationDeliveryAdapter notificationDeliveryAdapter,
            ChargebackNotificationDeliveryRepository notificationDeliveryRepository,
            ChargebackPaymentProviderHandoffRepository paymentHandoffRepository,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry,
            @Value("${osmu.billing.adapter-retry-worker.enabled:false}") boolean scheduledWorkerEnabled,
            @Value("${osmu.billing.adapter-retry-worker.batch-size:50}") int batchSize
    ) {
        this.notificationDeliveryAdapter = notificationDeliveryAdapter;
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
        int updatedCount = 0;

        for (ChargebackAlertNotificationDeliveryRecord record : notificationCandidates) {
            if (dryRun) {
                items.add(notificationItem(record, null, true, notificationAdapterConfigured));
            } else {
                ChargebackAlertNotificationDeliveryRecord updated = notificationAdapterConfigured
                        ? attemptNotificationDelivery(record, now)
                        : blockNotification(record, now);
                notificationDeliveryRepository.update(updated);
                if (NOTIFICATION_BLOCKED_STATUS.equals(updated.status())) {
                    blockedNotificationCounter.increment();
                }
                items.add(notificationItem(record, updated, false, notificationAdapterConfigured));
                updatedCount += 1;
            }
        }
        for (ChargebackPaymentProviderHandoffRecord record : paymentCandidates) {
            items.add(paymentItem(record, dryRun, now));
            if (!dryRun) {
                paymentHandoffRepository.update(blockPayment(record, now));
                blockedPaymentCounter.increment();
                updatedCount += 1;
            }
        }
        if (!dryRun && updatedCount > 0) {
            recordAudit(actor, updatedCount, notificationAdapterConfigured);
        }
        return new ChargebackAdapterRetryWorkerRunResponse(
                "ADAPTER_RETRY_WORKER",
                scheduledWorkerEnabled,
                dryRun,
                notificationAdapterConfigured,
                normalizedLimit,
                notificationCandidates.size(),
                paymentCandidates.size(),
                updatedCount,
                items,
                now,
                dryRun
                        ? "Dry-run only; no external adapter calls or status updates were performed."
                        : retryWorkerRunNote(notificationAdapterConfigured)
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
            boolean dryRun,
            OffsetDateTime now
    ) {
        return new ChargebackAdapterRetryWorkerItemResponse(
                "PAYMENT_PROVIDER",
                record.id() == null ? 0L : record.id(),
                record.status(),
                PAYMENT_BLOCKED_STATUS,
                dryRun ? record.attemptCount() : record.attemptCount() + 1,
                dryRun ? record.nextAttemptAt() : null,
                dryRun ? "Due payment provider adapter retry candidate." : PAYMENT_BLOCKED_ERROR
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
        String result = normalizeNotificationAdapterResult(adapterResult.result());
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
                notificationNextAttemptAt(result, adapterResult.nextAttemptAt(), now),
                record.subject(),
                record.message(),
                record.payloadJson(),
                record.requestedBy(),
                record.reason(),
                record.createdAt(),
                now,
                notificationLastError(result, adapterResult.lastError())
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

    private void recordAudit(String actor, int updatedCount, boolean notificationAdapterConfigured) {
        auditLogService.record(
                "CHARGEBACK_ADAPTER_RETRY_WORKER_RUN",
                actor,
                "CHARGEBACK_ADAPTER_RETRY",
                "due-outbox",
                "SUCCESS",
                (notificationAdapterConfigured
                        ? "Chargeback adapter retry worker processed due rows; notification webhook was attempted when eligible: "
                        : "Chargeback adapter retry worker blocked due rows without external calls: ")
                        + updatedCount
        );
    }

    private static String normalizeNotificationAdapterResult(String value) {
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

    private static OffsetDateTime notificationNextAttemptAt(
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

    private static String notificationLastError(String result, String value) {
        if ("SUCCESS".equals(result)) {
            return null;
        }
        String fallback = "RETRY".equals(result)
                ? "Notification webhook adapter retry scheduled."
                : "Notification webhook adapter blocked this delivery row.";
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

    private static String retryWorkerRunNote(boolean notificationAdapterConfigured) {
        return notificationAdapterConfigured
                ? "Configured notification webhook adapter was attempted for due notification rows; payment rows remain blocked until payment adapter configuration exists."
                : "Due adapter retry rows were blocked because external adapter credentials/configuration are not configured.";
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
