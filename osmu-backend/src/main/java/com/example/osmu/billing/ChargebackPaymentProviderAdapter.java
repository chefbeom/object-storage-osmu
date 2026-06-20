package com.example.osmu.billing;

public interface ChargebackPaymentProviderAdapter {

    boolean isConfigured();

    default boolean isConfigured(String provider) {
        return isConfigured();
    }

    ChargebackPaymentProviderAdapterResult deliver(ChargebackPaymentProviderHandoffRecord record);
}
