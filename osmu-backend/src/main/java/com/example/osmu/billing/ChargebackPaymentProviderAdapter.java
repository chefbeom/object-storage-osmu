package com.example.osmu.billing;

public interface ChargebackPaymentProviderAdapter {

    boolean isConfigured();

    default boolean isConfigured(String provider) {
        return isConfigured();
    }

    default boolean webhookProfileConfigured(String provider) {
        return isConfigured(provider) && !nativeApiReady(provider);
    }

    default boolean nativeApiSupported(String provider) {
        return false;
    }

    default boolean nativeApiReady(String provider) {
        return false;
    }

    default String adapterMode(String provider) {
        if (nativeApiReady(provider)) {
            return "NATIVE_API";
        }
        if (webhookProfileConfigured(provider)) {
            return "WEBHOOK_PROFILE";
        }
        if (nativeApiSupported(provider)) {
            return "NATIVE_API_UNCONFIGURED";
        }
        return "UNCONFIGURED";
    }

    ChargebackPaymentProviderAdapterResult deliver(ChargebackPaymentProviderHandoffRecord record);
}
