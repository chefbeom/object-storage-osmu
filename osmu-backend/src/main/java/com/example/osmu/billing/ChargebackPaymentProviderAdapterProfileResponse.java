package com.example.osmu.billing;

public record ChargebackPaymentProviderAdapterProfileResponse(
        String providerProfile,
        String sampleProvider,
        String adapterMode,
        String status,
        boolean webhookProfileConfigured,
        boolean nativeApiSupported,
        boolean nativeApiReady,
        String requiredConfiguration,
        String note
) {
}
