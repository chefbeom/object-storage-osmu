package com.example.osmu.billing.repository;

import com.example.osmu.billing.ChargebackAlertNotificationDeliveryRecord;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface ChargebackNotificationDeliveryRepository {

    List<ChargebackAlertNotificationDeliveryRecord> saveAll(List<ChargebackAlertNotificationDeliveryRecord> records);

    Optional<ChargebackAlertNotificationDeliveryRecord> findById(long id);

    List<ChargebackAlertNotificationDeliveryRecord> findAll(int limit);

    List<ChargebackAlertNotificationDeliveryRecord> findByStatus(String status, int limit);

    List<ChargebackAlertNotificationDeliveryRecord> findDueAdapterRetries(OffsetDateTime now, int limit);

    List<ChargebackAlertNotificationDeliveryRecord> findByOrganizationId(long organizationId, int limit);

    ChargebackAlertNotificationDeliveryRecord update(ChargebackAlertNotificationDeliveryRecord record);
}
