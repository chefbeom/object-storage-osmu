package com.example.osmu.billing;

public interface ChargebackNotificationDeliveryAdapter {

    boolean isConfigured();

    ChargebackNotificationDeliveryAdapterResult deliver(ChargebackAlertNotificationDeliveryRecord record);
}
