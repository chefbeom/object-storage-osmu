package com.example.osmu.billing;

import java.util.List;
import java.util.Locale;
import java.util.Optional;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

@Component
@Primary
public class CompositeChargebackPaymentProviderAdapter implements ChargebackPaymentProviderAdapter {

    private final WebhookChargebackPaymentProviderAdapter webhookAdapter;
    private final List<ChargebackNativePaymentProviderAdapter> nativeAdapters;

    public CompositeChargebackPaymentProviderAdapter(
            WebhookChargebackPaymentProviderAdapter webhookAdapter,
            List<ChargebackNativePaymentProviderAdapter> nativeAdapters
    ) {
        this.webhookAdapter = webhookAdapter;
        this.nativeAdapters = nativeAdapters == null ? List.of() : List.copyOf(nativeAdapters);
    }

    @Override
    public boolean isConfigured() {
        return webhookAdapter.isConfigured()
                || nativeAdapters.stream().anyMatch(ChargebackNativePaymentProviderAdapter::isConfigured);
    }

    @Override
    public boolean isConfigured(String provider) {
        return nativeApiReady(provider) || webhookAdapter.isConfigured(provider);
    }

    @Override
    public boolean webhookProfileConfigured(String provider) {
        return webhookAdapter.isConfigured(provider);
    }

    @Override
    public boolean nativeApiSupported(String provider) {
        return nativeAdapter(provider).isPresent();
    }

    @Override
    public boolean nativeApiReady(String provider) {
        return nativeAdapter(provider)
                .map(ChargebackNativePaymentProviderAdapter::isConfigured)
                .orElse(false);
    }

    @Override
    public String adapterMode(String provider) {
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

    @Override
    public ChargebackPaymentProviderAdapterResult deliver(ChargebackPaymentProviderHandoffRecord record) {
        Optional<ChargebackNativePaymentProviderAdapter> nativeAdapter = nativeAdapter(record.provider())
                .filter(ChargebackNativePaymentProviderAdapter::isConfigured);
        if (nativeAdapter.isPresent()) {
            return nativeAdapter.get().deliver(record);
        }
        return webhookAdapter.deliver(record);
    }

    private Optional<ChargebackNativePaymentProviderAdapter> nativeAdapter(String provider) {
        String profile = providerProfile(provider);
        return nativeAdapters.stream()
                .filter(adapter -> profile.equals(providerProfile(adapter.providerProfile())))
                .findFirst();
    }

    private static String providerProfile(String provider) {
        String normalizedProvider = provider == null
                ? ""
                : provider.trim().toUpperCase(Locale.ROOT).replace('-', '_').replace(' ', '_');
        if (normalizedProvider.startsWith("CARD")) {
            return "CARD";
        }
        if (normalizedProvider.startsWith("BANK")) {
            return "BANK";
        }
        if (normalizedProvider.startsWith("TAX")) {
            return "TAX";
        }
        if (normalizedProvider.startsWith("ERP")) {
            return "ERP";
        }
        return "GENERIC";
    }
}
