package com.example.osmu.billing;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.repository.InMemoryBucketRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.monitoring.DataFlowEventRecord;
import com.example.osmu.monitoring.repository.InMemoryDataFlowEventRepository;
import com.example.osmu.organization.OrganizationRecord;
import com.example.osmu.organization.repository.InMemoryOrganizationRepository;
import com.example.osmu.billing.repository.InMemoryBillingPricingPolicyRepository;
import com.example.osmu.billing.repository.InMemoryBillingPricingPolicyProposalRepository;
import com.example.osmu.billing.repository.InMemoryChargebackFinalInvoiceRepository;
import com.example.osmu.billing.repository.InMemoryChargebackInvoiceDraftRepository;
import com.example.osmu.billing.repository.InMemoryChargebackNotificationDeliveryRepository;
import com.example.osmu.billing.repository.InMemoryChargebackPaymentProviderHandoffRepository;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class ChargebackPreviewServiceTest {

    private static final BigDecimal ONE_GIB_RATE = BigDecimal.valueOf(1024L * 1024L * 1024L);

    private final InMemoryOrganizationRepository organizationRepository = new InMemoryOrganizationRepository();
    private final InMemoryBucketRepository bucketRepository = new InMemoryBucketRepository();
    private final InMemoryDataFlowEventRepository dataFlowEventRepository = new InMemoryDataFlowEventRepository();
    private final InMemoryChargebackNotificationDeliveryRepository notificationDeliveryRepository =
            new InMemoryChargebackNotificationDeliveryRepository();
    private final InMemoryChargebackInvoiceDraftRepository invoiceDraftRepository =
            new InMemoryChargebackInvoiceDraftRepository();
    private final InMemoryChargebackFinalInvoiceRepository finalInvoiceRepository =
            new InMemoryChargebackFinalInvoiceRepository();
    private final InMemoryChargebackPaymentProviderHandoffRepository paymentHandoffRepository =
            new InMemoryChargebackPaymentProviderHandoffRepository();
    private final BillingPricingPolicyService pricingPolicyService =
            new BillingPricingPolicyService(
                    new InMemoryBillingPricingPolicyRepository(),
                    new InMemoryBillingPricingPolicyProposalRepository()
            );
    private final ChargebackPreviewService service = new ChargebackPreviewService(
            organizationRepository,
            bucketRepository,
            dataFlowEventRepository,
            pricingPolicyService,
            notificationDeliveryRepository,
            invoiceDraftRepository,
            finalInvoiceRepository,
            paymentHandoffRepository,
            disabledNotificationAdapter(),
            disabledPaymentProviderAdapter()
    );

    @Test
    void buildsOrganizationChargebackPreviewFromCurrentUsageAndDataFlowEvents() {
        OffsetDateTime now = OffsetDateTime.now();
        organizationRepository.save(new OrganizationRecord(1L, "AI Lab", "", 10_000L, now));
        organizationRepository.save(new OrganizationRecord(2L, "Archive", "", 10_000L, now));
        bucketRepository.save(new BucketRecord(1L, "ai-media", "ORG", 1L, 10_000L, 1024L, 2L, now));
        bucketRepository.save(new BucketRecord(2L, "archive-media", "ORG", 2L, 10_000L, 2048L, 3L, now));
        bucketRepository.save(new BucketRecord(3L, "user-media", "USER", 99L, 10_000L, 4096L, 4L, now));

        dataFlowEventRepository.save(event("UPLOAD", "upload", "INGRESS", "ai-media", "SUCCESS", 1024L, now.minusMinutes(3)));
        dataFlowEventRepository.save(event("DOWNLOAD", "download", "EGRESS", "ai-media", "SUCCESS", 512L, now.minusMinutes(2)));
        dataFlowEventRepository.save(event("COPY", "copy", "INTERNAL", "ai-media", "SUCCESS", 128L, now.minusMinutes(1)));
        dataFlowEventRepository.save(event("FAILURE", "download", "CONTROL", "ai-media", "FAILED", 0L, now));
        dataFlowEventRepository.save(event("UPLOAD", "upload", "INGRESS", "user-media", "SUCCESS", 9999L, now));

        ChargebackPreviewResponse preview = service.preview(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(
                        now.minusHours(1),
                        now.plusHours(1),
                        "krw",
                        ONE_GIB_RATE,
                        ONE_GIB_RATE,
                        ONE_GIB_RATE,
                        ONE_GIB_RATE,
                        BigDecimal.valueOf(1000L),
                        100
                )
        );

        assertThat(preview.currency()).isEqualTo("KRW");
        assertThat(preview.organizationCount()).isEqualTo(2L);
        assertThat(preview.bucketCount()).isEqualTo(2L);
        assertThat(preview.usedBytes()).isEqualTo(3072L);
        assertThat(preview.scannedEventCount()).isEqualTo(5);
        assertThat(preview.estimatedTotalCost()).isEqualByComparingTo("4739.000000");

        ChargebackOrganizationPreviewResponse aiLab = preview.organizations().get(0);
        assertThat(aiLab.organizationName()).isEqualTo("AI Lab");
        assertThat(aiLab.usedBytes()).isEqualTo(1024L);
        assertThat(aiLab.ingressBytes()).isEqualTo(1024L);
        assertThat(aiLab.egressBytes()).isEqualTo(512L);
        assertThat(aiLab.internalBytes()).isEqualTo(128L);
        assertThat(aiLab.billableOperationCount()).isEqualTo(3L);
        assertThat(aiLab.failedOperationCount()).isEqualTo(1L);
        assertThat(aiLab.projectedStorageCost()).isEqualByComparingTo("1024.000000");
        assertThat(aiLab.ingressCost()).isEqualByComparingTo("1024.000000");
        assertThat(aiLab.egressCost()).isEqualByComparingTo("512.000000");
        assertThat(aiLab.internalCost()).isEqualByComparingTo("128.000000");
        assertThat(aiLab.operationCost()).isEqualByComparingTo("3.000000");
        assertThat(aiLab.estimatedTotalCost()).isEqualByComparingTo("2691.000000");

        ChargebackOrganizationPreviewResponse archive = preview.organizations().get(1);
        assertThat(archive.organizationName()).isEqualTo("Archive");
        assertThat(archive.estimatedTotalCost()).isEqualByComparingTo("2048.000000");
    }

    @Test
    void orgAdminSeesOnlyOwnOrganization() {
        OffsetDateTime now = OffsetDateTime.now();
        organizationRepository.save(new OrganizationRecord(1L, "Visible Org", "", 10_000L, now));
        organizationRepository.save(new OrganizationRecord(2L, "Hidden Org", "", 10_000L, now));
        bucketRepository.save(new BucketRecord(1L, "visible-bucket", "ORG", 1L, 10_000L, 100L, 1L, now));
        bucketRepository.save(new BucketRecord(2L, "hidden-bucket", "ORG", 2L, 10_000L, 200L, 1L, now));

        ChargebackPreviewResponse preview = service.preview(
                new AuthenticatedUser(10L, "org-admin", "ORG_ADMIN", 1L),
                new ChargebackPreviewRequest(null, null, null, BigDecimal.ONE, null, null, null, null, 0)
        );

        assertThat(preview.organizations()).extracting(ChargebackOrganizationPreviewResponse::organizationName)
                .containsExactly("Visible Org");
        assertThat(preview.usedBytes()).isEqualTo(100L);
    }

    @Test
    void usesPersistedPricingPolicyWhenPreviewRequestOmitsRates() {
        OffsetDateTime now = OffsetDateTime.now();
        organizationRepository.save(new OrganizationRecord(1L, "Policy Org", "", 10_000L, now));
        bucketRepository.save(new BucketRecord(1L, "policy-bucket", "ORG", 1L, 10_000L, 1024L, 1L, now));
        dataFlowEventRepository.save(event("UPLOAD", "upload", "INGRESS", "policy-bucket", "SUCCESS", 2048L, now));

        pricingPolicyService.save(new BillingPricingPolicyRequest(
                "krw",
                ONE_GIB_RATE,
                ONE_GIB_RATE,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.valueOf(1000L),
                BigDecimal.valueOf(2000L),
                BigDecimal.valueOf(3000L),
                25,
                "unit test"
        ));

        ChargebackPreviewResponse preview = service.preview(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0)
        );

        assertThat(preview.currency()).isEqualTo("KRW");
        assertThat(preview.eventScanLimit()).isEqualTo(25);
        assertThat(preview.rates().storageGbMonthRate()).isEqualByComparingTo("1073741824.000000");
        assertThat(preview.rates().ingressGbRate()).isEqualByComparingTo("1073741824.000000");
        assertThat(preview.estimatedTotalCost()).isEqualByComparingTo("3073.000000");

        ChargebackAlertResponse alerts = service.alerts(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0)
        );

        assertThat(alerts.warningAmount()).isEqualByComparingTo("2000.000000");
        assertThat(alerts.criticalAmount()).isEqualByComparingTo("3000.000000");
        assertThat(alerts.alertCount()).isEqualTo(1L);
        assertThat(alerts.criticalCount()).isEqualTo(1L);
        assertThat(alerts.organizations().get(0).severity()).isEqualTo("CRITICAL");
    }

    @Test
    void createsAndApprovesPricingPolicyProposalBeforeApplyingRates() {
        BillingPricingPolicyProposalCreateResponse created = pricingPolicyService.createProposal(
                new BillingPricingPolicyRequest(
                        "krw",
                        BigDecimal.valueOf(10L),
                        BigDecimal.valueOf(20L),
                        BigDecimal.valueOf(30L),
                        BigDecimal.valueOf(40L),
                        BigDecimal.valueOf(50L),
                        BigDecimal.valueOf(60L),
                        BigDecimal.valueOf(70L),
                        25,
                        "proposal test"
                ),
                "admin"
        );

        assertThat(created.status()).isEqualTo(BillingPricingPolicyService.PROPOSAL_STATUS_PENDING_APPROVAL);
        assertThat(created.approvedPriceList()).isFalse();
        assertThat(created.proposal().requestedBy()).isEqualTo("admin");
        assertThat(pricingPolicyService.current().currency()).isEqualTo("USD");

        BillingPricingPolicyProposalListResponse pending =
                pricingPolicyService.proposals("pending_approval", 10);
        assertThat(pending.proposalCount()).isEqualTo(1L);
        assertThat(pending.proposals().get(0).status())
                .isEqualTo(BillingPricingPolicyService.PROPOSAL_STATUS_PENDING_APPROVAL);

        BillingPricingPolicyProposalApprovalResponse approved = pricingPolicyService.approveProposal(
                created.proposal().id(),
                "admin",
                "approved for internal chargeback"
        );

        assertThat(approved.status()).isEqualTo(BillingPricingPolicyService.PROPOSAL_STATUS_APPROVED_APPLIED);
        assertThat(approved.approvedPriceList()).isFalse();
        assertThat(approved.proposal().approvedBy()).isEqualTo("admin");
        assertThat(approved.proposal().approvalNote()).isEqualTo("approved for internal chargeback");
        assertThat(approved.appliedPolicy().currency()).isEqualTo("KRW");
        assertThat(pricingPolicyService.current().storageGbMonthRate()).isEqualByComparingTo("10.000000");

        BillingPricingPolicyProposalApprovalResponse priceListApproved = pricingPolicyService.approveCommercialPriceList(
                created.proposal().id(),
                "admin",
                "LEGAL-2026-0001",
                "commercial approval recorded",
                OffsetDateTime.parse("2026-06-20T00:00:00Z")
        );

        assertThat(priceListApproved.status()).isEqualTo(BillingPricingPolicyService.PROPOSAL_STATUS_PRICE_LIST_APPROVED);
        assertThat(priceListApproved.approvedPriceList()).isTrue();
        assertThat(priceListApproved.proposal().commercialApprovedBy()).isEqualTo("admin");
        assertThat(priceListApproved.proposal().commercialApprovalReference()).isEqualTo("LEGAL-2026-0001");
        assertThat(priceListApproved.proposal().commercialApprovalNote()).isEqualTo("commercial approval recorded");
        assertThat(priceListApproved.proposal().commercialEffectiveFrom()).isEqualTo(OffsetDateTime.parse("2026-06-20T00:00:00Z"));

        BillingPricingPolicyProposalListResponse commercialApproved =
                pricingPolicyService.proposals("PRICE_LIST_APPROVED", 10);
        assertThat(commercialApproved.proposalCount()).isEqualTo(1L);
        assertThat(commercialApproved.proposals().get(0).approvedPriceList()).isTrue();

        assertThatThrownBy(() -> pricingPolicyService.approveProposal(created.proposal().id(), "admin", "again"))
                .isInstanceOf(ApiException.class)
                .extracting("code")
                .isEqualTo(ApiErrorCode.VALIDATION_ERROR);
    }

    @Test
    void buildsChargebackAlertNotificationPreviewWithoutExternalDelivery() {
        OffsetDateTime now = OffsetDateTime.now();
        organizationRepository.save(new OrganizationRecord(1L, "Notify Org", "", 10_000L, now));
        bucketRepository.save(new BucketRecord(1L, "notify-bucket", "ORG", 1L, 10_000L, 1024L, 1L, now));

        pricingPolicyService.save(new BillingPricingPolicyRequest(
                "krw",
                ONE_GIB_RATE,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.valueOf(20L),
                BigDecimal.valueOf(25L),
                25,
                "notification preview test"
        ));

        ChargebackAlertNotificationPreviewResponse preview = service.alertNotificationPreview(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0),
                "slack",
                "ops-webhook"
        );

        assertThat(preview.mode()).isEqualTo("PREVIEW");
        assertThat(preview.channel()).isEqualTo("SLACK");
        assertThat(preview.target()).isEqualTo("ops-webhook");
        assertThat(preview.externalDeliveryEnabled()).isFalse();
        assertThat(preview.notificationCount()).isEqualTo(1L);
        assertThat(preview.note()).contains("no external notification was sent");

        ChargebackAlertNotificationOrganizationResponse notification = preview.notifications().get(0);
        assertThat(notification.organizationName()).isEqualTo("Notify Org");
        assertThat(notification.severity()).isEqualTo("CRITICAL");
        assertThat(notification.subject()).contains("CRITICAL chargeback alert");
        assertThat(notification.payload()).containsEntry("eventType", "chargeback.threshold");
        assertThat(notification.payload()).containsEntry("channel", "SLACK");
        assertThat(notification.payload()).containsEntry("target", "ops-webhook");

        ChargebackAlertNotificationDispatchResponse dispatch = service.queueAlertNotifications(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0),
                "slack",
                "ops-webhook",
                "unit test dispatch"
        );

        assertThat(dispatch.mode()).isEqualTo("OUTBOX");
        assertThat(dispatch.status()).isEqualTo("PENDING_DELIVERY_ADAPTER");
        assertThat(dispatch.externalDeliveryEnabled()).isFalse();
        assertThat(dispatch.queuedCount()).isEqualTo(1L);
        assertThat(dispatch.deliveries().get(0).id()).isGreaterThan(0L);
        assertThat(dispatch.deliveries().get(0).payloadJson()).contains("\"eventType\":\"chargeback.threshold\"");

        ChargebackAlertNotificationOutboxResponse outbox = service.notificationOutbox(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                10
        );
        assertThat(outbox.deliveryCount()).isEqualTo(1L);
        assertThat(outbox.deliveries().get(0).status()).isEqualTo("PENDING_DELIVERY_ADAPTER");

        ChargebackAlertNotificationDeliveryAttemptResponse blocked = service.recordNotificationDeliveryAdapterResult(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                outbox.deliveries().get(0).id(),
                "BLOCKED_SECRET",
                null,
                null
        );
        assertThat(blocked.mode()).isEqualTo("ADAPTER_RESULT");
        assertThat(blocked.status()).isEqualTo("DELIVERY_ADAPTER_BLOCKED_CREDENTIAL");
        assertThat(blocked.externalDeliveryEnabled()).isFalse();
        assertThat(blocked.delivery().attemptCount()).isEqualTo(1);
        assertThat(blocked.delivery().lastError()).contains("credential/configuration");

        ChargebackAlertNotificationDeliveryAttemptResponse retry = service.recordNotificationDeliveryAdapterResult(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                outbox.deliveries().get(0).id(),
                "RETRY",
                30,
                "Notification adapter endpoint is not ready."
        );
        assertThat(retry.status()).isEqualTo("DELIVERY_ADAPTER_RETRY_SCHEDULED");
        assertThat(retry.delivery().attemptCount()).isEqualTo(2);
        assertThat(retry.delivery().nextAttemptAt()).isNotNull();
    }

    @Test
    void sendsConfiguredChargebackAlertNotificationAdapter() {
        OffsetDateTime now = OffsetDateTime.now();
        organizationRepository.save(new OrganizationRecord(1L, "Webhook Org", "", 10_000L, now));
        bucketRepository.save(new BucketRecord(1L, "webhook-bucket", "ORG", 1L, 10_000L, 1024L, 1L, now));

        pricingPolicyService.save(new BillingPricingPolicyRequest(
                "krw",
                ONE_GIB_RATE,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.valueOf(20L),
                BigDecimal.valueOf(25L),
                25,
                "notification adapter send test"
        ));

        ChargebackPreviewService sendingService = serviceWithNotificationAdapter(new ChargebackNotificationDeliveryAdapter() {
            @Override
            public boolean isConfigured() {
                return true;
            }

            @Override
            public ChargebackNotificationDeliveryAdapterResult deliver(ChargebackAlertNotificationDeliveryRecord record) {
                assertThat(record.payloadJson()).contains("\"eventType\":\"chargeback.threshold\"");
                return ChargebackNotificationDeliveryAdapterResult.success();
            }
        });

        ChargebackAlertNotificationDispatchResponse dispatch = sendingService.queueAlertNotifications(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0),
                "webhook",
                "ops-webhook",
                "unit test send"
        );

        assertThat(dispatch.externalDeliveryEnabled()).isTrue();
        assertThat(dispatch.queuedCount()).isEqualTo(1L);

        ChargebackAlertNotificationDeliveryAttemptResponse sent = sendingService.sendNotificationDeliveryAdapter(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                dispatch.deliveries().get(0).id(),
                null
        );

        assertThat(sent.status()).isEqualTo("DELIVERY_ADAPTER_SUCCEEDED");
        assertThat(sent.externalDeliveryEnabled()).isTrue();
        assertThat(sent.delivery().attemptCount()).isEqualTo(1);
        assertThat(sent.delivery().lastError()).isNull();
        assertThat(sent.note()).contains("delivered");
    }

    @Test
    void evaluatesNotificationAdapterConfigurationPerChannel() {
        OffsetDateTime now = OffsetDateTime.now();
        organizationRepository.save(new OrganizationRecord(1L, "Slack Org", "", 10_000L, now));
        bucketRepository.save(new BucketRecord(1L, "slack-bucket", "ORG", 1L, 10_000L, 1024L, 1L, now));

        pricingPolicyService.save(new BillingPricingPolicyRequest(
                "krw",
                ONE_GIB_RATE,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.ZERO,
                BigDecimal.valueOf(20L),
                BigDecimal.valueOf(25L),
                25,
                "channel adapter test"
        ));

        ChargebackPreviewService slackService = serviceWithNotificationAdapter(new ChargebackNotificationDeliveryAdapter() {
            @Override
            public boolean isConfigured() {
                return true;
            }

            @Override
            public boolean isConfigured(String channel) {
                return "SLACK".equals(channel);
            }

            @Override
            public ChargebackNotificationDeliveryAdapterResult deliver(ChargebackAlertNotificationDeliveryRecord record) {
                assertThat(record.channel()).isEqualTo("SLACK");
                return ChargebackNotificationDeliveryAdapterResult.success();
            }
        });

        ChargebackAlertNotificationPreviewResponse slackPreview = slackService.alertNotificationPreview(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0),
                "slack",
                "ops-alerts"
        );
        ChargebackAlertNotificationPreviewResponse webhookPreview = slackService.alertNotificationPreview(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0),
                "webhook",
                "ops-webhook"
        );

        assertThat(slackPreview.externalDeliveryEnabled()).isTrue();
        assertThat(webhookPreview.externalDeliveryEnabled()).isFalse();

        ChargebackAlertNotificationDispatchResponse dispatch = slackService.queueAlertNotifications(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0),
                "slack",
                "ops-alerts",
                "channel-specific send"
        );

        assertThat(dispatch.externalDeliveryEnabled()).isTrue();
        ChargebackAlertNotificationDeliveryAttemptResponse sent = slackService.sendNotificationDeliveryAdapter(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                dispatch.deliveries().get(0).id(),
                null
        );
        assertThat(sent.status()).isEqualTo("DELIVERY_ADAPTER_SUCCEEDED");
        assertThat(sent.externalDeliveryEnabled()).isTrue();
    }

    @Test
    void persistsAndApprovesChargebackInvoiceDraftsForInternalReview() {
        OffsetDateTime now = OffsetDateTime.now();
        organizationRepository.save(new OrganizationRecord(1L, "Invoice Org", "", 10_000L, now));
        bucketRepository.save(new BucketRecord(1L, "invoice-bucket", "ORG", 1L, 10_000L, 1024L, 1L, now));

        ChargebackInvoiceDraftCreateResponse create = service.persistInvoiceDrafts(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(
                        now.minusHours(1),
                        now.plusHours(1),
                        "krw",
                        ONE_GIB_RATE,
                        BigDecimal.ZERO,
                        BigDecimal.ZERO,
                        BigDecimal.ZERO,
                        BigDecimal.ZERO,
                        100
                ),
                "unit test invoice draft"
        );

        assertThat(create.mode()).isEqualTo("DRAFT_REVIEW");
        assertThat(create.status()).isEqualTo("DRAFT_REVIEW");
        assertThat(create.finalInvoice()).isFalse();
        assertThat(create.paymentRequest()).isFalse();
        assertThat(create.persistedCount()).isEqualTo(1L);
        ChargebackInvoiceDraftResponse draft = create.invoices().get(0);
        assertThat(draft.id()).isGreaterThan(0L);
        assertThat(draft.invoiceNumber()).startsWith("OSMU-DRAFT-");
        assertThat(draft.organizationName()).isEqualTo("Invoice Org");
        assertThat(draft.estimatedTotalCost()).isEqualByComparingTo("1024.000000");

        ChargebackInvoiceDraftListResponse drafts = service.invoiceDrafts(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                "DRAFT_REVIEW",
                10
        );
        assertThat(drafts.invoiceCount()).isEqualTo(1L);

        ChargebackInvoiceDraftApprovalResponse approved = service.approveInvoiceDraft(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                draft.id(),
                "approved for pilot review"
        );
        assertThat(approved.status()).isEqualTo("APPROVED_INTERNAL");
        assertThat(approved.finalInvoice()).isFalse();
        assertThat(approved.paymentRequest()).isFalse();
        assertThat(approved.invoice().approvedBy()).isEqualTo("admin");
        assertThat(approved.invoice().approvalNote()).isEqualTo("approved for pilot review");

        ChargebackInvoiceDraftListResponse approvedList = service.invoiceDrafts(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                "APPROVED_INTERNAL",
                10
        );
        assertThat(approvedList.invoiceCount()).isEqualTo(1L);

        ChargebackFinalInvoiceActionResponse finalized = service.finalizeInvoiceDraft(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                draft.id(),
                "final invoice ready"
        );
        assertThat(finalized.mode()).isEqualTo("FINAL_INVOICE");
        assertThat(finalized.status()).isEqualTo("FINALIZED");
        assertThat(finalized.paymentStatus()).isEqualTo("NOT_REQUESTED");
        assertThat(finalized.finalInvoice()).isTrue();
        assertThat(finalized.paymentRequest()).isFalse();
        assertThat(finalized.invoice().invoiceNumber()).startsWith("OSMU-FINAL-");
        assertThat(finalized.invoice().sourceDraftId()).isEqualTo(draft.id());
        assertThat(finalized.invoice().finalizedBy()).isEqualTo("admin");

        ChargebackFinalInvoiceListResponse finalInvoices = service.finalInvoices(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                "FINALIZED",
                10
        );
        assertThat(finalInvoices.invoiceCount()).isEqualTo(1L);

        ChargebackFinalInvoiceActionResponse paymentRequested = service.requestFinalInvoicePayment(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                finalized.invoice().id(),
                "send payment request"
        );
        assertThat(paymentRequested.status()).isEqualTo("PAYMENT_REQUESTED");
        assertThat(paymentRequested.paymentStatus()).isEqualTo("REQUESTED");
        assertThat(paymentRequested.paymentRequest()).isTrue();
        assertThat(paymentRequested.invoice().paymentRequestedBy()).isEqualTo("admin");

        ChargebackPaymentProviderHandoffPreviewResponse handoffPreview = service.paymentProviderHandoffPreview(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                finalized.invoice().id(),
                "manual_ap",
                "finance-ap"
        );
        assertThat(handoffPreview.mode()).isEqualTo("PREVIEW");
        assertThat(handoffPreview.provider()).isEqualTo("MANUAL_AP");
        assertThat(handoffPreview.targetAccount()).isEqualTo("finance-ap");
        assertThat(handoffPreview.externalPaymentEnabled()).isFalse();
        assertThat(handoffPreview.payload()).containsEntry("eventType", "chargeback.payment_provider.handoff");
        assertThat(handoffPreview.payload()).containsEntry("externalPaymentEnabled", false);

        ChargebackPaymentProviderHandoffQueueResponse queuedHandoff = service.queuePaymentProviderHandoff(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                finalized.invoice().id(),
                "manual_ap",
                "finance-ap",
                "unit test handoff"
        );
        assertThat(queuedHandoff.mode()).isEqualTo("OUTBOX");
        assertThat(queuedHandoff.status()).isEqualTo("PENDING_PAYMENT_PROVIDER_ADAPTER");
        assertThat(queuedHandoff.externalPaymentEnabled()).isFalse();
        assertThat(queuedHandoff.handoff().payloadJson()).contains("\"eventType\":\"chargeback.payment_provider.handoff\"");

        ChargebackPaymentProviderHandoffListResponse handoffs = service.paymentProviderHandoffs(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                "PENDING_PAYMENT_PROVIDER_ADAPTER",
                10
        );
        assertThat(handoffs.handoffCount()).isEqualTo(1L);
        assertThat(handoffs.handoffs().get(0).provider()).isEqualTo("MANUAL_AP");

        ChargebackPaymentProviderHandoffAttemptResponse blockedHandoff =
                service.recordPaymentProviderHandoffAdapterResult(
                        new AuthenticatedUser(1L, "admin", "ADMIN", null),
                        handoffs.handoffs().get(0).id(),
                        "BLOCKED_CREDENTIAL",
                        null,
                        null
                );
        assertThat(blockedHandoff.status()).isEqualTo("PAYMENT_PROVIDER_ADAPTER_BLOCKED_CREDENTIAL");
        assertThat(blockedHandoff.externalPaymentEnabled()).isFalse();
        assertThat(blockedHandoff.handoff().attemptCount()).isEqualTo(1);

        ChargebackPaymentProviderHandoffAttemptResponse retryHandoff =
                service.recordPaymentProviderHandoffAdapterResult(
                        new AuthenticatedUser(1L, "admin", "ADMIN", null),
                        handoffs.handoffs().get(0).id(),
                        "RETRY",
                        45,
                        "Payment adapter configuration pending."
                );
        assertThat(retryHandoff.status()).isEqualTo("PAYMENT_PROVIDER_ADAPTER_RETRY_SCHEDULED");
        assertThat(retryHandoff.handoff().attemptCount()).isEqualTo(2);
        assertThat(retryHandoff.handoff().nextAttemptAt()).isNotNull();

        ChargebackPaymentProviderHandoffListResponse retryHandoffs = service.paymentProviderHandoffs(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                "PAYMENT_PROVIDER_ADAPTER_RETRY_SCHEDULED",
                10
        );
        assertThat(retryHandoffs.handoffCount()).isEqualTo(1L);

        ChargebackFinalInvoiceActionResponse paid = service.recordFinalInvoicePayment(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                finalized.invoice().id(),
                "PAY-2026-0001",
                "payment confirmed"
        );
        assertThat(paid.status()).isEqualTo("PAID");
        assertThat(paid.paymentStatus()).isEqualTo("PAID");
        assertThat(paid.invoice().paymentRecordedBy()).isEqualTo("admin");
        assertThat(paid.invoice().paymentReference()).isEqualTo("PAY-2026-0001");
    }

    @Test
    void sendsConfiguredPaymentProviderHandoffAdapter() {
        OffsetDateTime now = OffsetDateTime.now();
        organizationRepository.save(new OrganizationRecord(1L, "Pay Org", "", 10_000L, now));
        bucketRepository.save(new BucketRecord(1L, "pay-bucket", "ORG", 1L, 10_000L, 1024L, 1L, now));

        ChargebackPreviewService sendingService = serviceWithPaymentProviderAdapter(new ChargebackPaymentProviderAdapter() {
            @Override
            public boolean isConfigured() {
                return true;
            }

            @Override
            public ChargebackPaymentProviderAdapterResult deliver(ChargebackPaymentProviderHandoffRecord record) {
                assertThat(record.payloadJson()).contains("\"eventType\":\"chargeback.payment_provider.handoff\"");
                assertThat(record.invoiceNumber()).startsWith("OSMU-FINAL-");
                return ChargebackPaymentProviderAdapterResult.success();
            }
        });

        ChargebackInvoiceDraftCreateResponse create = sendingService.persistInvoiceDrafts(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(
                        now.minusHours(1),
                        now.plusHours(1),
                        "krw",
                        ONE_GIB_RATE,
                        BigDecimal.ZERO,
                        BigDecimal.ZERO,
                        BigDecimal.ZERO,
                        BigDecimal.ZERO,
                        100
                ),
                "payment adapter send test"
        );
        ChargebackInvoiceDraftApprovalResponse approved = sendingService.approveInvoiceDraft(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                create.invoices().get(0).id(),
                "approve"
        );
        ChargebackFinalInvoiceActionResponse finalized = sendingService.finalizeInvoiceDraft(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                approved.invoice().id(),
                "finalize"
        );
        sendingService.requestFinalInvoicePayment(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                finalized.invoice().id(),
                "request payment"
        );

        ChargebackPaymentProviderHandoffQueueResponse queued = sendingService.queuePaymentProviderHandoff(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                finalized.invoice().id(),
                "manual_ap",
                "finance-ap",
                "unit test payment send"
        );

        assertThat(queued.externalPaymentEnabled()).isTrue();

        ChargebackPaymentProviderHandoffAttemptResponse sent = sendingService.sendPaymentProviderHandoffAdapter(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                queued.handoff().id(),
                null
        );

        assertThat(sent.status()).isEqualTo("PAYMENT_PROVIDER_ADAPTER_SUCCEEDED");
        assertThat(sent.externalPaymentEnabled()).isTrue();
        assertThat(sent.handoff().attemptCount()).isEqualTo(1);
        assertThat(sent.handoff().lastError()).isNull();
        assertThat(sent.note()).contains("delivered");
    }

    @Test
    void rejectsUnsupportedRolesAndInvalidRates() {
        assertThatThrownBy(() -> service.preview(
                new AuthenticatedUser(3L, "auditor", "AUDITOR", null),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0)
        ))
                .isInstanceOf(ApiException.class)
                .extracting("code")
                .isEqualTo(ApiErrorCode.AUTHORIZATION_FAILED);

        assertThatThrownBy(() -> service.preview(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(null, null, null, BigDecimal.valueOf(-1L), null, null, null, null, 0)
        ))
                .isInstanceOf(ApiException.class)
                .extracting("code")
                .isEqualTo(ApiErrorCode.VALIDATION_ERROR);

        assertThatThrownBy(() -> service.alertNotificationPreview(
                new AuthenticatedUser(1L, "admin", "ADMIN", null),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0),
                "bad channel!",
                null
        ))
                .isInstanceOf(ApiException.class)
                .extracting("code")
                .isEqualTo(ApiErrorCode.VALIDATION_ERROR);

        assertThatThrownBy(() -> service.persistInvoiceDrafts(
                new AuthenticatedUser(3L, "org-admin", "ORG_ADMIN", 1L),
                new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0),
                "denied"
        ))
                .isInstanceOf(ApiException.class)
                .extracting("code")
                .isEqualTo(ApiErrorCode.AUTHORIZATION_FAILED);

        assertThatThrownBy(() -> service.finalInvoices(
                new AuthenticatedUser(3L, "org-admin", "ORG_ADMIN", 1L),
                null,
                10
        ))
                .isInstanceOf(ApiException.class)
                .extracting("code")
                .isEqualTo(ApiErrorCode.AUTHORIZATION_FAILED);

        assertThatThrownBy(() -> service.paymentProviderHandoffs(
                new AuthenticatedUser(3L, "org-admin", "ORG_ADMIN", 1L),
                null,
                10
        ))
                .isInstanceOf(ApiException.class)
                .extracting("code")
                .isEqualTo(ApiErrorCode.AUTHORIZATION_FAILED);

        assertThatThrownBy(() -> service.recordNotificationDeliveryAdapterResult(
                new AuthenticatedUser(3L, "org-admin", "ORG_ADMIN", 1L),
                1L,
                "RETRY",
                30,
                "adapter not ready"
        ))
                .isInstanceOf(ApiException.class)
                .extracting("code")
                .isEqualTo(ApiErrorCode.AUTHORIZATION_FAILED);

        assertThatThrownBy(() -> service.recordPaymentProviderHandoffAdapterResult(
                new AuthenticatedUser(3L, "org-admin", "ORG_ADMIN", 1L),
                1L,
                "RETRY",
                30,
                "adapter not ready"
        ))
                .isInstanceOf(ApiException.class)
                .extracting("code")
                .isEqualTo(ApiErrorCode.AUTHORIZATION_FAILED);
    }

    private ChargebackPreviewService serviceWithNotificationAdapter(ChargebackNotificationDeliveryAdapter adapter) {
        return new ChargebackPreviewService(
                organizationRepository,
                bucketRepository,
                dataFlowEventRepository,
                pricingPolicyService,
                notificationDeliveryRepository,
                invoiceDraftRepository,
                finalInvoiceRepository,
                paymentHandoffRepository,
                adapter,
                disabledPaymentProviderAdapter()
        );
    }

    private ChargebackPreviewService serviceWithPaymentProviderAdapter(ChargebackPaymentProviderAdapter adapter) {
        return new ChargebackPreviewService(
                organizationRepository,
                bucketRepository,
                dataFlowEventRepository,
                pricingPolicyService,
                notificationDeliveryRepository,
                invoiceDraftRepository,
                finalInvoiceRepository,
                paymentHandoffRepository,
                disabledNotificationAdapter(),
                adapter
        );
    }

    private static ChargebackNotificationDeliveryAdapter disabledNotificationAdapter() {
        return new ChargebackNotificationDeliveryAdapter() {
            @Override
            public boolean isConfigured() {
                return false;
            }

            @Override
            public ChargebackNotificationDeliveryAdapterResult deliver(ChargebackAlertNotificationDeliveryRecord record) {
                return ChargebackNotificationDeliveryAdapterResult.blocked("Notification webhook adapter is not configured.");
            }
        };
    }

    private static ChargebackPaymentProviderAdapter disabledPaymentProviderAdapter() {
        return new ChargebackPaymentProviderAdapter() {
            @Override
            public boolean isConfigured() {
                return false;
            }

            @Override
            public ChargebackPaymentProviderAdapterResult deliver(ChargebackPaymentProviderHandoffRecord record) {
                return ChargebackPaymentProviderAdapterResult.blocked("Payment provider webhook adapter is not configured.");
            }
        };
    }

    private DataFlowEventRecord event(
            String eventType,
            String operation,
            String direction,
            String bucketName,
            String status,
            long bytes,
            OffsetDateTime createdAt
    ) {
        return new DataFlowEventRecord(
                null,
                eventType,
                operation,
                direction,
                bucketName,
                "sample.bin",
                "actor",
                status,
                bytes,
                "",
                "REST",
                createdAt
        );
    }
}
