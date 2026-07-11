package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackFinalInvoiceRecord;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface ChargebackFinalInvoiceRepository {

    ChargebackFinalInvoiceRecord save(ChargebackFinalInvoiceRecord record);

    List<ChargebackFinalInvoiceRecord> findAll(int limit);

    List<ChargebackFinalInvoiceRecord> findByStatus(String status, int limit);

    List<ChargebackFinalInvoiceRecord> findForCloseoutWindow(
            OffsetDateTime from,
            OffsetDateTime to,
            int limit
    );

    Optional<ChargebackFinalInvoiceRecord> findById(long id);

    Optional<ChargebackFinalInvoiceRecord> findBySourceDraftId(long sourceDraftId);

    ChargebackFinalInvoiceRecord updatePaymentRequest(
            long id,
            String status,
            String paymentStatus,
            String paymentRequestedBy,
            String paymentRequestNote
    );

    ChargebackFinalInvoiceRecord updatePaymentRecord(
            long id,
            String status,
            String paymentStatus,
            String paymentRecordedBy,
            String paymentReference,
            String paymentRequestNote
    );
}
