package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackInvoiceDraftRecord;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryChargebackInvoiceDraftRepository implements ChargebackInvoiceDraftRepository {

    private final AtomicLong sequence = new AtomicLong(1);
    private final List<ChargebackInvoiceDraftRecord> records = new CopyOnWriteArrayList<>();

    @Override
    public List<ChargebackInvoiceDraftRecord> saveAll(List<ChargebackInvoiceDraftRecord> newRecords) {
        List<ChargebackInvoiceDraftRecord> saved = new ArrayList<>();
        for (ChargebackInvoiceDraftRecord record : newRecords) {
            ChargebackInvoiceDraftRecord withId = withId(record, sequence.getAndIncrement());
            records.add(withId);
            saved.add(withId);
        }
        return saved;
    }

    @Override
    public List<ChargebackInvoiceDraftRecord> findAll(int limit) {
        return records.stream()
                .sorted(Comparator.comparing(ChargebackInvoiceDraftRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public List<ChargebackInvoiceDraftRecord> findByStatus(String status, int limit) {
        String normalized = status == null ? "" : status.trim().toUpperCase();
        return records.stream()
                .filter(record -> record.status().equals(normalized))
                .sorted(Comparator.comparing(ChargebackInvoiceDraftRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public Optional<ChargebackInvoiceDraftRecord> findById(long id) {
        return records.stream()
                .filter(record -> record.id() != null && record.id() == id)
                .findFirst();
    }

    @Override
    public ChargebackInvoiceDraftRecord updateApproval(
            long id,
            String status,
            String approvedBy,
            String approvalNote
    ) {
        OffsetDateTime now = OffsetDateTime.now();
        for (int index = 0; index < records.size(); index += 1) {
            ChargebackInvoiceDraftRecord current = records.get(index);
            if (current.id() != null && current.id() == id) {
                ChargebackInvoiceDraftRecord updated = new ChargebackInvoiceDraftRecord(
                        current.id(),
                        current.invoiceNumber(),
                        status,
                        current.organizationId(),
                        current.organizationName(),
                        current.currency(),
                        current.from(),
                        current.to(),
                        current.previewGeneratedAt(),
                        current.eventScanLimit(),
                        current.storageGbMonthRate(),
                        current.ingressGbRate(),
                        current.egressGbRate(),
                        current.internalGbRate(),
                        current.operationThousandRate(),
                        current.bucketCount(),
                        current.objectCount(),
                        current.usedBytes(),
                        current.storageCost(),
                        current.trafficCost(),
                        current.operationCost(),
                        current.estimatedTotalCost(),
                        current.requestedBy(),
                        approvedBy,
                        current.reason(),
                        approvalNote,
                        current.createdAt(),
                        now,
                        now,
                        current.note()
                );
                records.set(index, updated);
                return updated;
            }
        }
        throw new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback invoice draft not found.");
    }

    private static int normalizeLimit(int limit) {
        return Math.max(1, Math.min(limit <= 0 ? 50 : limit, 200));
    }

    private static ChargebackInvoiceDraftRecord withId(ChargebackInvoiceDraftRecord record, long id) {
        return new ChargebackInvoiceDraftRecord(
                id,
                record.invoiceNumber(),
                record.status(),
                record.organizationId(),
                record.organizationName(),
                record.currency(),
                record.from(),
                record.to(),
                record.previewGeneratedAt(),
                record.eventScanLimit(),
                record.storageGbMonthRate(),
                record.ingressGbRate(),
                record.egressGbRate(),
                record.internalGbRate(),
                record.operationThousandRate(),
                record.bucketCount(),
                record.objectCount(),
                record.usedBytes(),
                record.storageCost(),
                record.trafficCost(),
                record.operationCost(),
                record.estimatedTotalCost(),
                record.requestedBy(),
                record.approvedBy(),
                record.reason(),
                record.approvalNote(),
                record.createdAt(),
                record.updatedAt(),
                record.approvedAt(),
                record.note()
        );
    }
}
