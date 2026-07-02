package com.example.osmu.billing;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ChargebackNativePaymentProviderAdapterConfiguration {

    @Bean
    ChargebackNativePaymentProviderAdapter cardChargebackNativePaymentProviderAdapter(
            ObjectMapper objectMapper,
            NativePaymentProviderAdapterSettings settings,
            @Value("${osmu.billing.payment-provider.card.native-api-url:}") String nativeApiUrl,
            @Value("${osmu.billing.payment-provider.card.native-api-auth-header-value:}") String authHeaderValue
    ) {
        return adapter(objectMapper, "CARD", nativeApiUrl, authHeaderValue, settings);
    }

    @Bean
    ChargebackNativePaymentProviderAdapter bankChargebackNativePaymentProviderAdapter(
            ObjectMapper objectMapper,
            NativePaymentProviderAdapterSettings settings,
            @Value("${osmu.billing.payment-provider.bank.native-api-url:}") String nativeApiUrl,
            @Value("${osmu.billing.payment-provider.bank.native-api-auth-header-value:}") String authHeaderValue
    ) {
        return adapter(objectMapper, "BANK", nativeApiUrl, authHeaderValue, settings);
    }

    @Bean
    ChargebackNativePaymentProviderAdapter taxChargebackNativePaymentProviderAdapter(
            ObjectMapper objectMapper,
            NativePaymentProviderAdapterSettings settings,
            @Value("${osmu.billing.payment-provider.tax.native-api-url:}") String nativeApiUrl,
            @Value("${osmu.billing.payment-provider.tax.native-api-auth-header-value:}") String authHeaderValue
    ) {
        return adapter(objectMapper, "TAX", nativeApiUrl, authHeaderValue, settings);
    }

    @Bean
    ChargebackNativePaymentProviderAdapter erpChargebackNativePaymentProviderAdapter(
            ObjectMapper objectMapper,
            NativePaymentProviderAdapterSettings settings,
            @Value("${osmu.billing.payment-provider.erp.native-api-url:}") String nativeApiUrl,
            @Value("${osmu.billing.payment-provider.erp.native-api-auth-header-value:}") String authHeaderValue
    ) {
        return adapter(objectMapper, "ERP", nativeApiUrl, authHeaderValue, settings);
    }

    @Bean
    NativePaymentProviderAdapterSettings nativePaymentProviderAdapterSettings(
            @Value("${osmu.billing.payment-provider.native-api.auth-header-name:Authorization}") String authHeaderName,
            @Value("${osmu.billing.payment-provider.native-api.signature-secret:}") String signatureSecret,
            @Value("${osmu.billing.payment-provider.native-api.signature-header-name:X-OSMU-Native-Signature}") String signatureHeaderName,
            @Value("${osmu.billing.payment-provider.native-api.signature-timestamp-header-name:X-OSMU-Native-Signature-Timestamp}") String signatureTimestampHeaderName,
            @Value("${osmu.billing.payment-provider.native-api.timeout-ms:3000}") int timeoutMs,
            @Value("${osmu.billing.payment-provider.native-api.max-payload-bytes:65536}") int maxPayloadBytes,
            @Value("${osmu.billing.payment-provider.native-api.allow-private-network:false}") boolean allowPrivateNetwork
    ) {
        return new NativePaymentProviderAdapterSettings(
                authHeaderName,
                signatureSecret,
                signatureHeaderName,
                signatureTimestampHeaderName,
                timeoutMs,
                maxPayloadBytes,
                allowPrivateNetwork
        );
    }

    private static ChargebackNativePaymentProviderAdapter adapter(
            ObjectMapper objectMapper,
            String providerProfile,
            String nativeApiUrl,
            String authHeaderValue,
            NativePaymentProviderAdapterSettings settings
    ) {
        return new ConfigurableChargebackNativePaymentProviderAdapter(
                objectMapper,
                providerProfile,
                nativeApiUrl,
                settings.authHeaderName(),
                authHeaderValue,
                settings.signatureSecret(),
                settings.signatureHeaderName(),
                settings.signatureTimestampHeaderName(),
                settings.timeoutMs(),
                settings.maxPayloadBytes(),
                settings.allowPrivateNetwork()
        );
    }

    record NativePaymentProviderAdapterSettings(
            String authHeaderName,
            String signatureSecret,
            String signatureHeaderName,
            String signatureTimestampHeaderName,
            int timeoutMs,
            int maxPayloadBytes,
            boolean allowPrivateNetwork
    ) {
    }
}