package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackPaymentProviderHandoffRecord;
import java.util.List;
import java.util.Optional;

public interface ChargebackPaymentProviderHandoffRepository {

    ChargebackPaymentProviderHandoffRecord save(ChargebackPaymentProviderHandoffRecord record);

    Optional<ChargebackPaymentProviderHandoffRecord> findById(long id);

    List<ChargebackPaymentProviderHandoffRecord> findAll(int limit);

    List<ChargebackPaymentProviderHandoffRecord> findByStatus(String status, int limit);

    ChargebackPaymentProviderHandoffRecord update(ChargebackPaymentProviderHandoffRecord record);
}
