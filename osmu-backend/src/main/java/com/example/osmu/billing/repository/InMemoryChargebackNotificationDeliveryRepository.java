package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackAlertNotificationDeliveryRecord;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
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
    public List<ChargebackAlertNotificationDeliveryRecord> findAll(int limit) {
        return records.stream()
                .sorted(Comparator.comparing(ChargebackAlertNotificationDeliveryRecord::createdAt).reversed())
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

    private static int normalizeLimit(int limit) {
        return Math.max(1, Math.min(limit <= 0 ? 50 : limit, 200));
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
