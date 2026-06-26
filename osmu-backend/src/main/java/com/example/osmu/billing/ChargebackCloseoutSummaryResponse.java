package com.example.osmu.billing;

import java.time.OffsetDateTime;

public record ChargebackCloseoutSummaryResponse(
        String mode,
        String billingPeriod,
        String closeoutStatus,
        String result,
        String currency,
        OffsetDateTime from,
        OffsetDateTime to,
        int invoiceDraftCount,
        int finalInvoiceCount,
        int paymentRequestedCount,
        int paymentHandoffCount,
        int paidInvoiceCount,
        int notificationDeliveryCount,
        int adapterRetryCount,
        int unpaidInvoiceCount,
        int openHandoffCount,
        int openNotificationCount,
        long finalInvoiceTotalMinorUnits,
        long paidInvoiceTotalMinorUnits,
        long paymentRequestedTotalMinorUnits,
        long reconciliationDifferenceMinorUnits,
        int failureCount,
        boolean rawCustomerPaymentDataStored,
        boolean rawProviderResponseStored,
        boolean rawSecretValuesStored,
        OffsetDateTime generatedAt,
        String scopePolicy,
        String secretPolicy,
        String note
) {
}
