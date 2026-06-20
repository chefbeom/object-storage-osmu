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

    private final ChargebackNotificationDeliveryRepository notificationDeliveryRepository;
    private final ChargebackPaymentProviderHandoffRepository paymentHandoffRepository;
    private final AuditLogService auditLogService;
    private final Counter blockedNotificationCounter;
    private final Counter blockedPaymentCounter;
    private final boolean scheduledWorkerEnabled;
    private final int batchSize;

    public ChargebackAdapterRetryWorkerService(
            ChargebackNotificationDeliveryRepository notificationDeliveryRepository,
            ChargebackPaymentProviderHandoffRepository paymentHandoffRepository,
            AuditLogService auditLogService,
            MeterRegistry meterRegistry,
            @Value("${osmu.billing.adapter-retry-worker.enabled:false}") boolean scheduledWorkerEnabled,
            @Value("${osmu.billing.adapter-retry-worker.batch-size:50}") int batchSize
    ) {
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
        int updatedCount = 0;

        for (ChargebackAlertNotificationDeliveryRecord record : notificationCandidates) {
            items.add(notificationItem(record, dryRun, now));
            if (!dryRun) {
                notificationDeliveryRepository.update(blockNotification(record, now));
                blockedNotificationCounter.increment();
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
            recordAudit(actor, updatedCount);
        }
        return new ChargebackAdapterRetryWorkerRunResponse(
                "ADAPTER_RETRY_WORKER",
                scheduledWorkerEnabled,
                dryRun,
                false,
                normalizedLimit,
                notificationCandidates.size(),
                paymentCandidates.size(),
                updatedCount,
                items,
                now,
                dryRun
                        ? "Dry-run only; no external adapter calls or status updates were performed."
                        : "Due adapter retry rows were blocked because external adapter credentials/configuration are not configured."
        );
    }

    private static ChargebackAdapterRetryWorkerItemResponse notificationItem(
            ChargebackAlertNotificationDeliveryRecord record,
            boolean dryRun,
            OffsetDateTime now
    ) {
        return new ChargebackAdapterRetryWorkerItemResponse(
                "NOTIFICATION",
                record.id() == null ? 0L : record.id(),
                record.status(),
                NOTIFICATION_BLOCKED_STATUS,
                dryRun ? record.attemptCount() : record.attemptCount() + 1,
                dryRun ? record.nextAttemptAt() : null,
                dryRun ? "Due notification adapter retry candidate." : NOTIFICATION_BLOCKED_ERROR
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

    private void recordAudit(String actor, int updatedCount) {
        auditLogService.record(
                "CHARGEBACK_ADAPTER_RETRY_WORKER_RUN",
                actor,
                "CHARGEBACK_ADAPTER_RETRY",
                "due-outbox",
                "SUCCESS",
                "Chargeback adapter retry worker blocked due rows without external calls: " + updatedCount
        );
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
