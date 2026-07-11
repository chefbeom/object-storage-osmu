package com.example.osmu.quota;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.bucket.BucketOwnerUsageSummary;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.quota.repository.QuotaPolicyRepository;
import com.example.osmu.user.repository.UserRepository;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class QuotaPolicyServiceTest {

    @Test
    void listResolvesUsageWithBulkOwnerAndBucketQueries() {
        QuotaPolicyRepository quotaPolicyRepository = mock(QuotaPolicyRepository.class);
        BucketRepository bucketRepository = mock(BucketRepository.class);
        UserRepository userRepository = mock(UserRepository.class);
        OrganizationRepository organizationRepository = mock(OrganizationRepository.class);
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        List<QuotaPolicy> policies = List.of(
                new QuotaPolicy(1L, "USER", 10L, 2_000L, now, now),
                new QuotaPolicy(2L, "USER", 11L, 3_000L, now, now),
                new QuotaPolicy(3L, "ORGANIZATION", 20L, 4_000L, now, now),
                new QuotaPolicy(4L, "BUCKET", 30L, 5_000L, now, now)
        );
        when(quotaPolicyRepository.findAllForDashboardSummary()).thenReturn(policies);
        when(bucketRepository.summarizeUsageByOwners("USER", List.of(10L, 11L))).thenReturn(List.of(
                new BucketOwnerUsageSummary(10L, 2L, 2_000L, 900L, 9L),
                new BucketOwnerUsageSummary(11L, 1L, 1_000L, 400L, 4L)
        ));
        when(bucketRepository.summarizeUsageByOwners("ORG", List.of(20L))).thenReturn(List.of(
                new BucketOwnerUsageSummary(20L, 1L, 4_000L, 1_500L, 15L)
        ));
        when(bucketRepository.findByIds(List.of(30L))).thenReturn(List.of(
                new BucketRecord(30L, "policy-bucket", "USER", 10L, 5_000L, 2_500L, 25L, now)
        ));

        QuotaPolicyService service = new QuotaPolicyService(
                quotaPolicyRepository,
                bucketRepository,
                userRepository,
                organizationRepository
        );

        assertThat(service.listAllForDashboardSummary())
                .extracting(
                        QuotaPolicyResponse::targetType,
                        QuotaPolicyResponse::targetId,
                        QuotaPolicyResponse::usedBytes
                )
                .containsExactly(
                        tuple("USER", 10L, 900L),
                        tuple("USER", 11L, 400L),
                        tuple("ORGANIZATION", 20L, 1_500L),
                        tuple("BUCKET", 30L, 2_500L)
                );
        verify(bucketRepository).summarizeUsageByOwners("USER", List.of(10L, 11L));
        verify(bucketRepository).summarizeUsageByOwners("ORG", List.of(20L));
        verify(bucketRepository).findByIds(List.of(30L));
        verify(bucketRepository, never()).findAll();
    }

    @Test
    void listReturnsBoundedCursorPageAndResolvesOnlyReturnedUsage() {
        QuotaPolicyRepository quotaPolicyRepository = mock(QuotaPolicyRepository.class);
        BucketRepository bucketRepository = mock(BucketRepository.class);
        UserRepository userRepository = mock(UserRepository.class);
        OrganizationRepository organizationRepository = mock(OrganizationRepository.class);
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        List<QuotaPolicy> policies = List.of(
                new QuotaPolicy(1L, "BUCKET", 30L, 5_000L, now, now),
                new QuotaPolicy(2L, "ORGANIZATION", 20L, 4_000L, now, now),
                new QuotaPolicy(3L, "USER", 10L, 2_000L, now, now)
        );
        when(quotaPolicyRepository.findPage(null, 3)).thenReturn(policies);
        when(bucketRepository.findByIds(List.of(30L))).thenReturn(List.of(
                new BucketRecord(30L, "policy-bucket", "USER", 10L, 5_000L, 2_500L, 25L, now)
        ));
        when(bucketRepository.summarizeUsageByOwners("ORG", List.of(20L))).thenReturn(List.of(
                new BucketOwnerUsageSummary(20L, 1L, 4_000L, 1_500L, 15L)
        ));

        QuotaPolicyService service = new QuotaPolicyService(
                quotaPolicyRepository,
                bucketRepository,
                userRepository,
                organizationRepository
        );

        var page = service.list(null, 2);

        assertThat(page.items())
                .extracting(
                        QuotaPolicyResponse::targetType,
                        QuotaPolicyResponse::targetId,
                        QuotaPolicyResponse::usedBytes
                )
                .containsExactly(
                        tuple("BUCKET", 30L, 2_500L),
                        tuple("ORGANIZATION", 20L, 1_500L)
                );
        assertThat(QuotaPolicyPageCursor.decode(page.nextCursor()))
                .isEqualTo(new QuotaPolicyPageCursor("ORGANIZATION", 20L));
        verify(quotaPolicyRepository).findPage(null, 3);
        verify(quotaPolicyRepository, never()).findAllForDashboardSummary();
        verify(bucketRepository, never()).findAll();
    }
}