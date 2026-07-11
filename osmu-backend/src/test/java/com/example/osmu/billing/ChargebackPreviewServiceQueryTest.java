package com.example.osmu.billing;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.billing.repository.ChargebackFinalInvoiceRepository;
import com.example.osmu.billing.repository.ChargebackInvoiceDraftRepository;
import com.example.osmu.billing.repository.ChargebackNotificationDeliveryRepository;
import com.example.osmu.billing.repository.ChargebackPaymentProviderHandoffRepository;
import com.example.osmu.billing.repository.InMemoryBillingPricingPolicyProposalRepository;
import com.example.osmu.billing.repository.InMemoryBillingPricingPolicyRepository;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.monitoring.repository.DataFlowEventRepository;
import com.example.osmu.organization.OrganizationRecord;
import com.example.osmu.organization.repository.OrganizationRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class ChargebackPreviewServiceQueryTest {

    @Test
    void closeoutUsesWindowQueriesAndFailsClosedWhenAnySourceIsTruncated() {
        ChargebackInvoiceDraftRepository draftRepository = mock(ChargebackInvoiceDraftRepository.class);
        ChargebackFinalInvoiceRepository finalInvoiceRepository = mock(ChargebackFinalInvoiceRepository.class);
        ChargebackPaymentProviderHandoffRepository handoffRepository =
                mock(ChargebackPaymentProviderHandoffRepository.class);
        ChargebackNotificationDeliveryRepository notificationRepository =
                mock(ChargebackNotificationDeliveryRepository.class);
        OffsetDateTime from = OffsetDateTime.parse("2026-06-01T00:00:00Z");
        OffsetDateTime to = OffsetDateTime.parse("2026-07-01T00:00:00Z");
        when(draftRepository.findForCloseoutWindow(from, to, 2)).thenReturn(List.of(
                mock(ChargebackInvoiceDraftRecord.class),
                mock(ChargebackInvoiceDraftRecord.class)
        ));
        when(finalInvoiceRepository.findForCloseoutWindow(from, to, 2)).thenReturn(List.of());
        when(handoffRepository.findForCloseout(List.of(), from, to, 2)).thenReturn(List.of());
        when(notificationRepository.findForCloseout(List.of(), from, to, 2)).thenReturn(List.of());
        ChargebackPreviewService service = new ChargebackPreviewService(
                mock(OrganizationRepository.class),
                mock(BucketRepository.class),
                mock(DataFlowEventRepository.class),
                new BillingPricingPolicyService(
                        new InMemoryBillingPricingPolicyRepository(),
                        new InMemoryBillingPricingPolicyProposalRepository()
                ),
                notificationRepository,
                draftRepository,
                finalInvoiceRepository,
                handoffRepository,
                mock(ChargebackNotificationDeliveryAdapter.class),
                mock(ChargebackPaymentProviderAdapter.class)
        );

        ChargebackCloseoutSummaryResponse summary = service.closeoutSummary(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                "2026-06",
                from,
                to,
                1
        );

        assertThat(summary.scanLimit()).isEqualTo(1);
        assertThat(summary.sourceTruncated()).isTrue();
        assertThat(summary.truncationBlockerCount()).isEqualTo(1);
        assertThat(summary.closeoutReady()).isFalse();
        assertThat(summary.closeoutStatus()).isEqualTo("PENDING");
        assertThat(summary.invoiceDraftCount()).isEqualTo(1);
        verify(draftRepository).findForCloseoutWindow(from, to, 2);
        verify(finalInvoiceRepository).findForCloseoutWindow(from, to, 2);
        verify(handoffRepository).findForCloseout(List.of(), from, to, 2);
        verify(notificationRepository).findForCloseout(List.of(), from, to, 2);
        verify(draftRepository, never()).findAll(anyInt());
        verify(finalInvoiceRepository, never()).findAll(anyInt());
        verify(handoffRepository, never()).findAll(anyInt());
        verify(notificationRepository, never()).findAll(anyInt());
    }

    @Test
    void orgAdminPreviewAndRollupLoadOnlyOwnOrganizationBucketsOnce() {
        OrganizationRepository organizationRepository = mock(OrganizationRepository.class);
        BucketRepository bucketRepository = mock(BucketRepository.class);
        DataFlowEventRepository dataFlowEventRepository = mock(DataFlowEventRepository.class);
        OrganizationRecord organization = new OrganizationRecord(
                7L,
                "Scoped Org",
                "",
                10_000L,
                OffsetDateTime.now()
        );
        when(organizationRepository.findById(7L)).thenReturn(Optional.of(organization));
        when(bucketRepository.findByOwners("ORG", List.of(7L))).thenReturn(List.of(new BucketRecord(
                3L,
                "scoped-bucket",
                "ORG",
                7L,
                10_000L,
                100L,
                1L,
                OffsetDateTime.now()
        )));
        when(dataFlowEventRepository.find(any(), anyInt())).thenReturn(List.of());
        when(dataFlowEventRepository.dailyRollup(any(), anyInt())).thenReturn(List.of());
        ChargebackPreviewService service = new ChargebackPreviewService(
                organizationRepository,
                bucketRepository,
                dataFlowEventRepository,
                new BillingPricingPolicyService(
                        new InMemoryBillingPricingPolicyRepository(),
                        new InMemoryBillingPricingPolicyProposalRepository()
                ),
                mock(ChargebackNotificationDeliveryRepository.class),
                mock(ChargebackInvoiceDraftRepository.class),
                mock(ChargebackFinalInvoiceRepository.class),
                mock(ChargebackPaymentProviderHandoffRepository.class),
                mock(ChargebackNotificationDeliveryAdapter.class),
                mock(ChargebackPaymentProviderAdapter.class)
        );
        AuthenticatedUser actor = new AuthenticatedUser(9L, "org-admin", "ORG_ADMIN", 7L);

        service.preview(actor, null);

        verify(bucketRepository).findByOwners("ORG", List.of(7L));
        verify(bucketRepository, never()).findAll();

        clearInvocations(bucketRepository);
        service.dailyRollup(actor, null, 7, 50, false);

        verify(bucketRepository).findByOwners("ORG", List.of(7L));
        verify(bucketRepository, never()).findAll();
    }
}