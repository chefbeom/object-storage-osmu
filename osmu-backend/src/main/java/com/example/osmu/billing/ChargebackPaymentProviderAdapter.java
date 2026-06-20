package com.example.osmu.billing;

public interface ChargebackPaymentProviderAdapter {

    boolean isConfigured();

    ChargebackPaymentProviderAdapterResult deliver(ChargebackPaymentProviderHandoffRecord record);
}
