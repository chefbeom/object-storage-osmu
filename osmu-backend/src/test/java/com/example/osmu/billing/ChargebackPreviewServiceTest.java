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
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class ChargebackPreviewServiceTest {

    private static final BigDecimal ONE_GIB_RATE = BigDecimal.valueOf(1024L * 1024L * 1024L);

    private final InMemoryOrganizationRepository organizationRepository = new InMemoryOrganizationRepository();
    private final InMemoryBucketRepository bucketRepository = new InMemoryBucketRepository();
    private final InMemoryDataFlowEventRepository dataFlowEventRepository = new InMemoryDataFlowEventRepository();
    private final BillingPricingPolicyService pricingPolicyService =
            new BillingPricingPolicyService(new InMemoryBillingPricingPolicyRepository());
    private final ChargebackPreviewService service = new ChargebackPreviewService(
            organizationRepository,
            bucketRepository,
            dataFlowEventRepository,
            pricingPolicyService
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
