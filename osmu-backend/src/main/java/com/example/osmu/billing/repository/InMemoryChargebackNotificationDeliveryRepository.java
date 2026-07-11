package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackAlertNotificationDeliveryRecord;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryChargebackNotificationDeliveryRepository implements ChargebackNotificationDeliveryRepository {

    private final AtomicLong sequence = new AtomicLong(1);
    private final List<ChargebackAlertNotificationDeliveryRecord> records = new CopyOnWriteArrayList<>();

    @Override
    public List<ChargebackAlertNotificationDeliveryRecord> saveAll(List<ChargebackAlertNotificationDeliveryRecord> newRecords) {
        List<ChargebackAlertNotificationDeliveryRecord> saved = new ArrayList<>();
        for (ChargebackAlertNotificationDeliveryRecord record : newRecords) {
            ChargebackAlertNotificationDeliveryRecord withId = withId(record, sequence.getAndIncrement());
            records.add(withId);
            saved.add(withId);
        }
        return saved;
    }

    @Override
    public Optional<ChargebackAlertNotificationDeliveryRecord> findById(long id) {
        return records.stream()
                .filter(record -> record.id() != null && record.id() == id)
                .findFirst();
    }

    @Override
    public List<ChargebackAlertNotificationDeliveryRecord> findAll(int limit) {
        return records.stream()
                .sorted(Comparator.comparing(ChargebackAlertNotificationDeliveryRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public List<ChargebackAlertNotificationDeliveryRecord> findByStatus(String status, int limit) {
        return records.stream()
                .filter(record -> record.status().equals(status))
                .sorted(Comparator.comparing(ChargebackAlertNotificationDeliveryRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public List<ChargebackAlertNotificationDeliveryRecord> findDueAdapterRetries(OffsetDateTime now, int limit) {
        return records.stream()
                .filter(record -> isRetryCandidate(record.status()))
                .filter(record -> record.nextAttemptAt() == null || !record.nextAttemptAt().isAfter(now))
                .sorted(Comparator.comparing(ChargebackAlertNotificationDeliveryRecord::updatedAt))
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public List<ChargebackAlertNotificationDeliveryRecord> findByOrganizationId(long organizationId, int limit) {
        return records.stream()
                .filter(record -> record.organizationId() == organizationId)
                .sorted(Comparator.comparing(ChargebackAlertNotificationDeliveryRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public List<ChargebackAlertNotificationDeliveryRecord> findForCloseout(
            List<Long> organizationIds,
            OffsetDateTime from,
            OffsetDateTime to,
            int limit
    ) {
        Set<Long> ids = new HashSet<>(organizationIds == null ? List.of() : organizationIds);
        ids.remove(null);
        return records.stream()
                .filter(record -> timestampWithinWindow(record.createdAt(), from, to))
                .filter(record -> ids.isEmpty() || ids.contains(record.organizationId()))
                .sorted(Comparator.comparing(ChargebackAlertNotificationDeliveryRecord::createdAt).reversed())
                .limit(Math.max(1, limit))
                .toList();
    }

    @Override
    public ChargebackAlertNotificationDeliveryRecord update(ChargebackAlertNotificationDeliveryRecord updated) {
        for (int index = 0; index < records.size(); index++) {
            ChargebackAlertNotificationDeliveryRecord existing = records.get(index);
            if (existing.id() != null && existing.id().equals(updated.id())) {
                records.set(index, updated);
                return updated;
            }
        }
        throw new IllegalArgumentException("Chargeback notification delivery not found: " + updated.id());
    }

    private static boolean timestampWithinWindow(
            OffsetDateTime timestamp,
            OffsetDateTime from,
            OffsetDateTime to
    ) {
        if (from == null && to == null) {
            return true;
        }
        if (timestamp == null) {
            return true;
        }
        if (from != null && timestamp.isBefore(from)) {
            return false;
        }
        return to == null || timestamp.isBefore(to);
    }

    private static int normalizeLimit(int limit) {
        return Math.max(1, Math.min(limit <= 0 ? 50 : limit, 200));
    }

    private static boolean isRetryCandidate(String status) {
        return "PENDING_DELIVERY_ADAPTER".equals(status)
                || "DELIVERY_ADAPTER_RETRY_SCHEDULED".equals(status);
    }

    private static ChargebackAlertNotificationDeliveryRecord withId(
            ChargebackAlertNotificationDeliveryRecord record,
            long id
    ) {
        return new ChargebackAlertNotificationDeliveryRecord(
                id,
                record.organizationId(),
                record.organizationName(),
                record.severity(),
                record.estimatedTotalCost(),
                record.warningAmount(),
                record.criticalAmount(),
                record.channel(),
                record.target(),
                record.status(),
                record.attemptCount(),
                record.nextAttemptAt(),
                record.subject(),
                record.message(),
                record.payloadJson(),
                record.requestedBy(),
                record.reason(),
                record.createdAt(),
                record.updatedAt(),
                record.lastError()
        );
    }
}
