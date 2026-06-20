package com.example.osmu.billing;

public interface ChargebackNotificationDeliveryAdapter {

    boolean isConfigured();

    default boolean isConfigured(String channel) {
        return isConfigured();
    }

    ChargebackNotificationDeliveryAdapterResult deliver(ChargebackAlertNotificationDeliveryRecord record);
}
