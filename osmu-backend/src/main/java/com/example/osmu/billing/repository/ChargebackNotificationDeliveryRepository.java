package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackAlertNotificationDeliveryRecord;
import java.util.List;

public interface ChargebackNotificationDeliveryRepository {

    List<ChargebackAlertNotificationDeliveryRecord> saveAll(List<ChargebackAlertNotificationDeliveryRecord> records);

    List<ChargebackAlertNotificationDeliveryRecord> findAll(int limit);

    List<ChargebackAlertNotificationDeliveryRecord> findByOrganizationId(long organizationId, int limit);
}
