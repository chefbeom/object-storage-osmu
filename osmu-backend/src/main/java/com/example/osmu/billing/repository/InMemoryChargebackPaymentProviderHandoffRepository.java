package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackPaymentProviderHandoffRecord;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryChargebackPaymentProviderHandoffRepository implements ChargebackPaymentProviderHandoffRepository {

    private final AtomicLong sequence = new AtomicLong(1);
    private final List<ChargebackPaymentProviderHandoffRecord> records = new CopyOnWriteArrayList<>();

    @Override
    public ChargebackPaymentProviderHandoffRecord save(ChargebackPaymentProviderHandoffRecord record) {
        ChargebackPaymentProviderHandoffRecord withId = withId(record, sequence.getAndIncrement());
        records.add(withId);
        return withId;
    }

    @Override
    public List<ChargebackPaymentProviderHandoffRecord> findAll(int limit) {
        return records.stream()
                .sorted(Comparator.comparing(ChargebackPaymentProviderHandoffRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public List<ChargebackPaymentProviderHandoffRecord> findByStatus(String status, int limit) {
        return records.stream()
                .filter(record -> status.equals(record.status()))
                .sorted(Comparator.comparing(ChargebackPaymentProviderHandoffRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    private static int normalizeLimit(int limit) {
        return Math.max(1, Math.min(limit <= 0 ? 50 : limit, 200));
    }

    private static ChargebackPaymentProviderHandoffRecord withId(
            ChargebackPaymentProviderHandoffRecord record,
            long id
    ) {
        return new ChargebackPaymentProviderHandoffRecord(
                id,
                record.finalInvoiceId(),
                record.invoiceNumber(),
                record.organizationId(),
                record.organizationName(),
                record.currency(),
                record.amount(),
                record.provider(),
                record.targetAccount(),
                record.status(),
                record.attemptCount(),
                record.nextAttemptAt(),
                record.payloadJson(),
                record.requestedBy(),
                record.reason(),
                record.createdAt(),
                record.updatedAt(),
                record.lastError()
        );
    }
}
