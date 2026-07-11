package com.example.osmu.object;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectRetentionPolicyRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class ObjectLifecycleRuleQueryTest {

    @Test
    void purgeJobsLoadOnlyEnabledRulesForTheirTarget() {
        ObjectLifecycleRuleRepository ruleRepository = mock(ObjectLifecycleRuleRepository.class);
        ObjectRetentionPolicyRepository policyRepository = mock(ObjectRetentionPolicyRepository.class);
        ObjectMetadataRepository metadataRepository = mock(ObjectMetadataRepository.class);
        ObjectVersionRepository versionRepository = mock(ObjectVersionRepository.class);
        ObjectRetentionPolicy policy = ObjectRetentionPolicy.initial(true, 30, 100, 90, 100);
        when(policyRepository.getPolicy()).thenReturn(policy);
        when(metadataRepository.findDeletedBefore(any(OffsetDateTime.class), anyInt())).thenReturn(List.of());
        when(versionRepository.findCreatedBefore(any(OffsetDateTime.class), anyInt())).thenReturn(List.of());
        when(ruleRepository.findEnabledByTargetType(ObjectLifecycleRule.TARGET_TRASH_OBJECT)).thenReturn(List.of());
        when(ruleRepository.findEnabledByTargetType(ObjectLifecycleRule.TARGET_OBJECT_VERSION)).thenReturn(List.of());

        ObjectRetentionPurgeJob objectJob = new ObjectRetentionPurgeJob(
                metadataRepository,
                ruleRepository,
                policyRepository,
                versionRepository,
                mock(ObjectStorageAdapter.class),
                mock(BucketService.class),
                mock(AuditLogService.class),
                new SimpleMeterRegistry()
        );
        ObjectVersionRetentionPurgeJob versionJob = new ObjectVersionRetentionPurgeJob(
                policyRepository,
                ruleRepository,
                versionRepository,
                mock(ObjectStorageAdapter.class),
                mock(BucketService.class),
                mock(AuditLogService.class),
                new SimpleMeterRegistry()
        );

        objectJob.runNow(OffsetDateTime.now());
        versionJob.runNow(OffsetDateTime.now());

        verify(ruleRepository).findEnabledByTargetType(ObjectLifecycleRule.TARGET_TRASH_OBJECT);
        verify(ruleRepository).findEnabledByTargetType(ObjectLifecycleRule.TARGET_OBJECT_VERSION);
        verify(ruleRepository, never()).findAllForExport();
    }
}