package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackPaymentProviderHandoffRecord;
import java.time.OffsetDateTime;
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
    public Optional<ChargebackPaymentProviderHandoffRecord> findById(long id) {
        return records.stream()
                .filter(record -> record.id() != null && record.id() == id)
                .findFirst();
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

    @Override
    public List<ChargebackPaymentProviderHandoffRecord> findForCloseout(
            List<Long> finalInvoiceIds,
            OffsetDateTime from,
            OffsetDateTime to,
            int limit
    ) {
        Set<Long> invoiceIds = new HashSet<>(finalInvoiceIds == null ? List.of() : finalInvoiceIds);
        invoiceIds.remove(null);
        return records.stream()
                .filter(record -> invoiceIds.isEmpty()
                        ? timestampWithinWindow(record.createdAt(), from, to)
                        : invoiceIds.contains(record.finalInvoiceId()))
                .sorted(Comparator.comparing(ChargebackPaymentProviderHandoffRecord::createdAt).reversed())
                .limit(Math.max(1, limit))
                .toList();
    }

    @Override
    public List<ChargebackPaymentProviderHandoffRecord> findDueAdapterRetries(OffsetDateTime now, int limit) {
        return records.stream()
                .filter(record -> isRetryCandidate(record.status()))
                .filter(record -> record.nextAttemptAt() == null || !record.nextAttemptAt().isAfter(now))
                .sorted(Comparator.comparing(ChargebackPaymentProviderHandoffRecord::updatedAt))
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public ChargebackPaymentProviderHandoffRecord update(ChargebackPaymentProviderHandoffRecord updated) {
        for (int index = 0; index < records.size(); index++) {
            ChargebackPaymentProviderHandoffRecord existing = records.get(index);
            if (existing.id() != null && existing.id().equals(updated.id())) {
                records.set(index, updated);
                return updated;
            }
        }
        throw new IllegalArgumentException("Chargeback payment handoff not found: " + updated.id());
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
        return "PENDING_PAYMENT_PROVIDER_ADAPTER".equals(status)
                || "PAYMENT_PROVIDER_ADAPTER_RETRY_SCHEDULED".equals(status);
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
