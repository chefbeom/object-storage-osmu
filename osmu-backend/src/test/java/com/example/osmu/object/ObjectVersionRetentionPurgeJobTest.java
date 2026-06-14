package com.example.osmu.object;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.object.repository.InMemoryObjectLifecycleRuleRepository;
import com.example.osmu.object.repository.InMemoryObjectRetentionPolicyRepository;
import com.example.osmu.object.repository.InMemoryObjectVersionRepository;
import com.example.osmu.storage.memory.InMemoryObjectStorageAdapter;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.io.ByteArrayInputStream;
import java.time.OffsetDateTime;
import java.util.Map;
import org.junit.jupiter.api.Test;

class ObjectVersionRetentionPurgeJobTest {

    private final InMemoryObjectRetentionPolicyRepository retentionPolicyRepository =
            new InMemoryObjectRetentionPolicyRepository(true, 30, 100, 7, 100);
    private final InMemoryObjectLifecycleRuleRepository lifecycleRuleRepository =
            new InMemoryObjectLifecycleRuleRepository();
    private final InMemoryObjectVersionRepository objectVersionRepository = new InMemoryObjectVersionRepository();
    private final InMemoryObjectStorageAdapter storageAdapter = new InMemoryObjectStorageAdapter();
    private final BucketService bucketService = mock(BucketService.class);
    private final AuditLogService auditLogService = mock(AuditLogService.class);
    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();
    private final ObjectVersionRetentionPurgeJob purgeJob = new ObjectVersionRetentionPurgeJob(
            retentionPolicyRepository,
            lifecycleRuleRepository,
            objectVersionRepository,
            storageAdapter,
            bucketService,
            auditLogService,
            meterRegistry
    );

    @Test
    void purgeExpiredVersionsDeletesStorageMetadataAndUpdatesUsage() {
        OffsetDateTime now = OffsetDateTime.now();
        storageAdapter.createBucket("bucket");
        String oldStorageKey = ObjectVersionStorageKeys.PREFIX + "docs/v1";
        String freshStorageKey = ObjectVersionStorageKeys.PREFIX + "docs/v2";
        storageAdapter.putObject(
                "bucket",
                oldStorageKey,
                new ByteArrayInputStream("old".getBytes()),
                3L,
                "text/plain",
                Map.of()
        );
        storageAdapter.putObject(
                "bucket",
                freshStorageKey,
                new ByteArrayInputStream("fresh".getBytes()),
                5L,
                "text/plain",
                Map.of()
        );
        objectVersionRepository.save("bucket", new ObjectVersionRecord(
                "v1",
                "docs/sample.txt",
                oldStorageKey,
                3L,
                "text/plain",
                now.minusDays(20),
                now.minusDays(8),
                Map.of()
        ));
        objectVersionRepository.save("bucket", new ObjectVersionRecord(
                "v2",
                "docs/sample.txt",
                freshStorageKey,
                5L,
                "text/plain",
                now.minusDays(5),
                now.minusDays(3),
                Map.of()
        ));

        int purged = purgeJob.runNow(now);

        assertThat(purged).isEqualTo(1);
        assertThat(storageAdapter.statObject("bucket", oldStorageKey)).isEmpty();
        assertThat(storageAdapter.statObject("bucket", freshStorageKey)).isPresent();
        assertThat(objectVersionRepository.findByObjectKey("bucket", "docs/sample.txt"))
                .extracting(ObjectVersionRecord::versionId)
                .containsExactly("v2");
        verify(bucketService).applyObjectChange("bucket", -3L, -1L);
        verify(auditLogService).record(
                "OBJECT_VERSION_RETENTION_PURGE",
                "system",
                "OBJECT_VERSION",
                "bucket/docs/sample.txt#v1",
                "SUCCESS",
                "Object version purged by retention policy"
        );
        assertThat(purgeVersionCount("success")).isEqualTo(1.0);
        assertThat(purgeVersionCount("failure")).isZero();
    }

    @Test
    void purgeExpiredVersionsSkipsWhenPolicyDisabled() {
        OffsetDateTime now = OffsetDateTime.now();
        retentionPolicyRepository.save(new ObjectRetentionPolicy(false, 30, 100, 7, 100, now));
        objectVersionRepository.save("bucket", new ObjectVersionRecord(
                "v1",
                "docs/sample.txt",
                ObjectVersionStorageKeys.PREFIX + "docs/v1",
                3L,
                "text/plain",
                now.minusDays(20),
                now.minusDays(8),
                Map.of()
        ));

        int purged = purgeJob.runNow(now);

        assertThat(purged).isZero();
        assertThat(objectVersionRepository.findByObjectKey("bucket", "docs/sample.txt")).hasSize(1);
        verifyNoInteractions(bucketService, auditLogService);
        assertThat(purgeVersionCount("success")).isZero();
        assertThat(purgeVersionCount("failure")).isZero();
    }

    @Test
    void lifecycleRulePurgesMatchingVersionByPrefixAndTags() {
        OffsetDateTime now = OffsetDateTime.now();
        retentionPolicyRepository.save(new ObjectRetentionPolicy(true, 30, 100, 365, 100, now));
        storageAdapter.createBucket("bucket");
        String matchingStorageKey = ObjectVersionStorageKeys.PREFIX + "videos/raw/v1";
        String otherStorageKey = ObjectVersionStorageKeys.PREFIX + "videos/final/v1";
        storageAdapter.putObject(
                "bucket",
                matchingStorageKey,
                new ByteArrayInputStream("raw".getBytes()),
                3L,
                "video/mp4",
                Map.of("project", "osmu", "stage", "raw")
        );
        storageAdapter.putObject(
                "bucket",
                otherStorageKey,
                new ByteArrayInputStream("final".getBytes()),
                5L,
                "video/mp4",
                Map.of("project", "osmu", "stage", "final")
        );
        objectVersionRepository.save("bucket", new ObjectVersionRecord(
                "raw-v1",
                "videos/raw/input.mp4",
                matchingStorageKey,
                3L,
                "video/mp4",
                now.minusDays(20),
                now.minusDays(8),
                Map.of("project", "osmu", "stage", "raw")
        ));
        objectVersionRepository.save("bucket", new ObjectVersionRecord(
                "final-v1",
                "videos/final/input.mp4",
                otherStorageKey,
                5L,
                "video/mp4",
                now.minusDays(20),
                now.minusDays(8),
                Map.of("project", "osmu", "stage", "final")
        ));
        lifecycleRuleRepository.save(new ObjectLifecycleRule(
                "rule-1",
                "Raw video versions",
                true,
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "videos/raw/",
                Map.of("stage", "raw"),
                7,
                100,
                now.minusDays(1),
                now.minusDays(1)
        ));

        int purged = purgeJob.runNow(now);

        assertThat(purged).isEqualTo(1);
        assertThat(storageAdapter.statObject("bucket", matchingStorageKey)).isEmpty();
        assertThat(storageAdapter.statObject("bucket", otherStorageKey)).isPresent();
        assertThat(objectVersionRepository.findByObjectKey("bucket", "videos/raw/input.mp4")).isEmpty();
        assertThat(objectVersionRepository.findByObjectKey("bucket", "videos/final/input.mp4")).hasSize(1);
    }

    @Test
    void bucketScopedLifecycleRuleOnlyPurgesMatchingBucketVersions() {
        OffsetDateTime now = OffsetDateTime.now();
        retentionPolicyRepository.save(new ObjectRetentionPolicy(true, 30, 100, 365, 100, now));
        storageAdapter.createBucket("bucket-a");
        storageAdapter.createBucket("bucket-b");
        String bucketAStorageKey = ObjectVersionStorageKeys.PREFIX + "bucket-a/raw-v1";
        String bucketBStorageKey = ObjectVersionStorageKeys.PREFIX + "bucket-b/raw-v1";
        storageAdapter.putObject(
                "bucket-a",
                bucketAStorageKey,
                new ByteArrayInputStream("raw-a".getBytes()),
                5L,
                "video/mp4",
                Map.of("stage", "raw")
        );
        storageAdapter.putObject(
                "bucket-b",
                bucketBStorageKey,
                new ByteArrayInputStream("raw-b".getBytes()),
                5L,
                "video/mp4",
                Map.of("stage", "raw")
        );
        objectVersionRepository.save("bucket-a", new ObjectVersionRecord(
                "raw-a-v1",
                "videos/raw/input.mp4",
                bucketAStorageKey,
                5L,
                "video/mp4",
                now.minusDays(20),
                now.minusDays(8),
                Map.of("stage", "raw")
        ));
        objectVersionRepository.save("bucket-b", new ObjectVersionRecord(
                "raw-b-v1",
                "videos/raw/input.mp4",
                bucketBStorageKey,
                5L,
                "video/mp4",
                now.minusDays(20),
                now.minusDays(8),
                Map.of("stage", "raw")
        ));
        lifecycleRuleRepository.save(new ObjectLifecycleRule(
                "rule-bucket-a",
                "Bucket A raw versions",
                true,
                10,
                "bucket-a",
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "videos/raw/",
                Map.of("stage", "raw"),
                7,
                100,
                now.minusDays(1),
                now.minusDays(1)
        ));

        int purged = purgeJob.runNow(now);

        assertThat(purged).isEqualTo(1);
        assertThat(storageAdapter.statObject("bucket-a", bucketAStorageKey)).isEmpty();
        assertThat(storageAdapter.statObject("bucket-b", bucketBStorageKey)).isPresent();
        assertThat(objectVersionRepository.findByObjectKey("bucket-a", "videos/raw/input.mp4")).isEmpty();
        assertThat(objectVersionRepository.findByObjectKey("bucket-b", "videos/raw/input.mp4")).hasSize(1);
        verify(bucketService).applyObjectChange("bucket-a", -5L, -1L);
    }

    private double purgeVersionCount(String result) {
        return meterRegistry.counter("osmu.object.version.retention.purge.versions", "result", result).count();
    }
}
