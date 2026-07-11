package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackFinalInvoiceRecord;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryChargebackFinalInvoiceRepository implements ChargebackFinalInvoiceRepository {

    private final AtomicLong sequence = new AtomicLong(1);
    private final List<ChargebackFinalInvoiceRecord> records = new CopyOnWriteArrayList<>();

    @Override
    public ChargebackFinalInvoiceRecord save(ChargebackFinalInvoiceRecord record) {
        if (findBySourceDraftId(record.sourceDraftId()).isPresent()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Chargeback invoice draft already has a final invoice.");
        }
        ChargebackFinalInvoiceRecord withId = withId(record, sequence.getAndIncrement());
        records.add(withId);
        return withId;
    }

    @Override
    public List<ChargebackFinalInvoiceRecord> findAll(int limit) {
        return records.stream()
                .sorted(Comparator.comparing(ChargebackFinalInvoiceRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public List<ChargebackFinalInvoiceRecord> findByStatus(String status, int limit) {
        String normalized = status == null ? "" : status.trim().toUpperCase();
        return records.stream()
                .filter(record -> record.status().equals(normalized))
                .sorted(Comparator.comparing(ChargebackFinalInvoiceRecord::createdAt).reversed())
                .limit(normalizeLimit(limit))
                .toList();
    }

    @Override
    public List<ChargebackFinalInvoiceRecord> findForCloseoutWindow(
            OffsetDateTime from,
            OffsetDateTime to,
            int limit
    ) {
        return records.stream()
                .filter(record -> invoiceWindowMatches(record.from(), record.to(), from, to))
                .sorted(Comparator.comparing(ChargebackFinalInvoiceRecord::createdAt).reversed())
                .limit(Math.max(1, limit))
                .toList();
    }

    @Override
    public Optional<ChargebackFinalInvoiceRecord> findById(long id) {
        return records.stream()
                .filter(record -> record.id() != null && record.id() == id)
                .findFirst();
    }

    @Override
    public Optional<ChargebackFinalInvoiceRecord> findBySourceDraftId(long sourceDraftId) {
        return records.stream()
                .filter(record -> record.sourceDraftId() == sourceDraftId)
                .findFirst();
    }

    @Override
    public ChargebackFinalInvoiceRecord updatePaymentRequest(
            long id,
            String status,
            String paymentStatus,
            String paymentRequestedBy,
            String paymentRequestNote
    ) {
        OffsetDateTime now = OffsetDateTime.now();
        return update(id, current -> new ChargebackFinalInvoiceRecord(
                current.id(),
                current.sourceDraftId(),
                current.invoiceNumber(),
                status,
                paymentStatus,
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
                current.approvedBy(),
                current.finalizedBy(),
                paymentRequestedBy,
                current.paymentRecordedBy(),
                current.reason(),
                current.approvalNote(),
                current.finalizationNote(),
                paymentRequestNote,
                current.paymentReference(),
                current.createdAt(),
                now,
                current.approvedAt(),
                current.finalizedAt(),
                now,
                current.paidAt(),
                "Final invoice payment request recorded for billing operations."
        ));
    }

    @Override
    public ChargebackFinalInvoiceRecord updatePaymentRecord(
            long id,
            String status,
            String paymentStatus,
            String paymentRecordedBy,
            String paymentReference,
            String paymentRequestNote
    ) {
        OffsetDateTime now = OffsetDateTime.now();
        return update(id, current -> new ChargebackFinalInvoiceRecord(
                current.id(),
                current.sourceDraftId(),
                current.invoiceNumber(),
                status,
                paymentStatus,
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
                current.approvedBy(),
                current.finalizedBy(),
                current.paymentRequestedBy(),
                paymentRecordedBy,
                current.reason(),
                current.approvalNote(),
                current.finalizationNote(),
                paymentRequestNote,
                paymentReference,
                current.createdAt(),
                now,
                current.approvedAt(),
                current.finalizedAt(),
                current.paymentRequestedAt(),
                now,
                "Final invoice payment recorded for billing operations."
        ));
    }

    private ChargebackFinalInvoiceRecord update(long id, InvoiceUpdater updater) {
        for (int index = 0; index < records.size(); index += 1) {
            ChargebackFinalInvoiceRecord current = records.get(index);
            if (current.id() != null && current.id() == id) {
                ChargebackFinalInvoiceRecord updated = updater.update(current);
                records.set(index, updated);
                return updated;
            }
        }
        throw new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback final invoice not found.");
    }

    private static boolean invoiceWindowMatches(
            OffsetDateTime recordFrom,
            OffsetDateTime recordTo,
            OffsetDateTime from,
            OffsetDateTime to
    ) {
        if (from == null && to == null) {
            return true;
        }
        OffsetDateTime recordStart = recordFrom == null ? recordTo : recordFrom;
        OffsetDateTime recordEnd = recordTo == null ? recordFrom : recordTo;
        if (recordStart == null && recordEnd == null) {
            return true;
        }
        if (from != null && recordEnd != null && recordEnd.isBefore(from)) {
            return false;
        }
        return to == null || recordStart == null || recordStart.isBefore(to);
    }

    private static int normalizeLimit(int limit) {
        return Math.max(1, Math.min(limit <= 0 ? 50 : limit, 200));
    }

    private static ChargebackFinalInvoiceRecord withId(ChargebackFinalInvoiceRecord record, long id) {
        return new ChargebackFinalInvoiceRecord(
                id,
                record.sourceDraftId(),
                record.invoiceNumber(),
                record.status(),
                record.paymentStatus(),
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
                record.finalizedBy(),
                record.paymentRequestedBy(),
                record.paymentRecordedBy(),
                record.reason(),
                record.approvalNote(),
                record.finalizationNote(),
                record.paymentRequestNote(),
                record.paymentReference(),
                record.createdAt(),
                record.updatedAt(),
                record.approvedAt(),
                record.finalizedAt(),
                record.paymentRequestedAt(),
                record.paidAt(),
                record.note()
        );
    }

    @FunctionalInterface
    private interface InvoiceUpdater {
        ChargebackFinalInvoiceRecord update(ChargebackFinalInvoiceRecord record);
    }
}
