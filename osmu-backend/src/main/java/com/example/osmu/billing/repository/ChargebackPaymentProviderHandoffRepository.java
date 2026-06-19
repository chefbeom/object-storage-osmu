package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackPaymentProviderHandoffRecord;
import java.util.List;

public interface ChargebackPaymentProviderHandoffRepository {

    ChargebackPaymentProviderHandoffRecord save(ChargebackPaymentProviderHandoffRecord record);

    List<ChargebackPaymentProviderHandoffRecord> findAll(int limit);

    List<ChargebackPaymentProviderHandoffRecord> findByStatus(String status, int limit);
}
