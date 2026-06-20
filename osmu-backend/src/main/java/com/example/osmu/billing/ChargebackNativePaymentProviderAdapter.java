package com.example.osmu.billing;

public interface ChargebackNativePaymentProviderAdapter {

    String providerProfile();

    boolean isConfigured();

    ChargebackPaymentProviderAdapterResult deliver(ChargebackPaymentProviderHandoffRecord record);
}
