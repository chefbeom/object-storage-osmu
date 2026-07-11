package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackInvoiceDraftRecord;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface ChargebackInvoiceDraftRepository {

    List<ChargebackInvoiceDraftRecord> saveAll(List<ChargebackInvoiceDraftRecord> records);

    List<ChargebackInvoiceDraftRecord> findAll(int limit);

    List<ChargebackInvoiceDraftRecord> findByStatus(String status, int limit);

    List<ChargebackInvoiceDraftRecord> findForCloseoutWindow(
            OffsetDateTime from,
            OffsetDateTime to,
            int limit
    );

    Optional<ChargebackInvoiceDraftRecord> findById(long id);

    ChargebackInvoiceDraftRecord updateApproval(
            long id,
            String status,
            String approvedBy,
            String approvalNote
    );
}
