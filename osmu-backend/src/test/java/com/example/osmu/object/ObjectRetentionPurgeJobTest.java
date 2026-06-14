package com.example.osmu.object;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.object.repository.InMemoryObjectMetadataRepository;
import com.example.osmu.object.repository.InMemoryObjectLifecycleRuleRepository;
import com.example.osmu.object.repository.InMemoryObjectRetentionPolicyRepository;
import com.example.osmu.object.repository.InMemoryObjectVersionRepository;
import com.example.osmu.storage.memory.InMemoryObjectStorageAdapter;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.io.ByteArrayInputStream;
import java.time.OffsetDateTime;
import java.util.Map;
import org.junit.jupiter.api.Test;

class ObjectRetentionPurgeJobTest {

    private final InMemoryObjectMetadataRepository objectMetadataRepository = new InMemoryObjectMetadataRepository();
    private final InMemoryObjectLifecycleRuleRepository lifecycleRuleRepository =
            new InMemoryObjectLifecycleRuleRepository();
    private final InMemoryObjectRetentionPolicyRepository retentionPolicyRepository =
            new InMemoryObjectRetentionPolicyRepository(true, 30, 100);
    private final InMemoryObjectVersionRepository objectVersionRepository = new InMemoryObjectVersionRepository();
    private final InMemoryObjectStorageAdapter storageAdapter = new InMemoryObjectStorageAdapter();
    private final BucketService bucketService = mock(BucketService.class);
    private final AuditLogService auditLogService = mock(AuditLogService.class);
    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();
    private final ObjectRetentionPurgeJob purgeJob = new ObjectRetentionPurgeJob(
            objectMetadataRepository,
            lifecycleRuleRepository,
            retentionPolicyRepository,
            objectVersionRepository,
            storageAdapter,
            bucketService,
            auditLogService,
            meterRegistry
    );

    @Test
    void purgeExpiredDeletedObjectsDeletesStorageMetadataAndUpdatesUsage() {
        OffsetDateTime now = OffsetDateTime.now();
        storageAdapter.createBucket("bucket");
        StoredObjectRecord stored = storageAdapter.putObject(
                "bucket",
                "old.txt",
                new ByteArrayInputStream("old".getBytes()),
                3L,
                "text/plain",
                Map.of()
        );
        objectMetadataRepository.save("bucket", stored.withDeletedAt(now.minusDays(31)));
        String versionStorageKey = ObjectVersionStorageKeys.PREFIX + "old/v1";
        storageAdapter.putObject(
                "bucket",
                versionStorageKey,
                new ByteArrayInputStream("v1".getBytes()),
                2L,
                "text/plain",
                Map.of()
        );
        objectVersionRepository.save("bucket", new ObjectVersionRecord(
                "v1",
                "old.txt",
                versionStorageKey,
                2L,
                "text/plain",
                now.minusDays(40),
                now.minusDays(30),
                Map.of()
        ));

        int purged = purgeJob.runNow(now);

        assertThat(purged).isEqualTo(1);
        assertThat(storageAdapter.statObject("bucket", "old.txt")).isEmpty();
        assertThat(storageAdapter.statObject("bucket", versionStorageKey)).isEmpty();
        assertThat(objectVersionRepository.findByObjectKey("bucket", "old.txt")).isEmpty();
        assertThat(objectMetadataRepository.findByKey("bucket", "old.txt")).isEmpty();
        verify(bucketService).applyObjectChange("bucket", -5L, -2L);
        verify(auditLogService).record(
                "OBJECT_RETENTION_PURGE",
                "system",
                "OBJECT",
                "bucket/old.txt",
                "SUCCESS",
                "Deleted object purged by retention policy"
        );
        assertThat(purgeObjectCount("success")).isEqualTo(1.0);
        assertThat(purgeObjectCount("failure")).isZero();
    }

    @Test
    void purgeExpiredDeletedObjectsSkipsWhenPolicyDisabled() {
        OffsetDateTime now = OffsetDateTime.now();
        retentionPolicyRepository.save(new ObjectRetentionPolicy(false, 30, 100, now));
        objectMetadataRepository.save("bucket", new StoredObjectRecord(
                "old.txt",
                3L,
                "text/plain",
                now.minusDays(31),
                Map.of(),
                now.minusDays(31)
        ));

        int purged = purgeJob.runNow(now);

        assertThat(purged).isZero();
        assertThat(objectMetadataRepository.findByKey("bucket", "old.txt")).isPresent();
        verifyNoInteractions(bucketService, auditLogService);
        assertThat(purgeObjectCount("success")).isZero();
        assertThat(purgeObjectCount("failure")).isZero();
    }

    @Test
    void purgeExpiredDeletedObjectsKeepsNewerTrashObjects() {
        OffsetDateTime now = OffsetDateTime.now();
        objectMetadataRepository.save("bucket", new StoredObjectRecord(
                "new.txt",
                3L,
                "text/plain",
                now.minusDays(2),
                Map.of(),
                now.minusDays(2)
        ));

        int purged = purgeJob.runNow(now);

        assertThat(purged).isZero();
        assertThat(objectMetadataRepository.findByKey("bucket", "new.txt")).isPresent();
        verifyNoInteractions(bucketService, auditLogService);
        assertThat(purgeObjectCount("success")).isZero();
        assertThat(purgeObjectCount("failure")).isZero();
    }

    @Test
    void lifecycleRulePurgesMatchingDeletedObjectByPrefixAndTags() {
        OffsetDateTime now = OffsetDateTime.now();
        retentionPolicyRepository.save(new ObjectRetentionPolicy(true, 365, 100, 90, 100, now));
        storageAdapter.createBucket("bucket");
        StoredObjectRecord matching = storageAdapter.putObject(
                "bucket",
                "videos/raw/input.mp4",
                new ByteArrayInputStream("raw".getBytes()),
                3L,
                "video/mp4",
                Map.of("stage", "raw")
        );
        StoredObjectRecord other = storageAdapter.putObject(
                "bucket",
                "videos/final/input.mp4",
                new ByteArrayInputStream("final".getBytes()),
                5L,
                "video/mp4",
                Map.of("stage", "final")
        );
        objectMetadataRepository.save("bucket", matching.withDeletedAt(now.minusDays(8)));
        objectMetadataRepository.save("bucket", other.withDeletedAt(now.minusDays(8)));
        lifecycleRuleRepository.save(new ObjectLifecycleRule(
                "rule-1",
                "Raw trash",
                true,
                ObjectLifecycleRule.TARGET_TRASH_OBJECT,
                "videos/raw/",
                Map.of("stage", "raw"),
                7,
                100,
                now.minusDays(1),
                now.minusDays(1)
        ));

        int purged = purgeJob.runNow(now);

        assertThat(purged).isEqualTo(1);
        assertThat(storageAdapter.statObject("bucket", "videos/raw/input.mp4")).isEmpty();
        assertThat(storageAdapter.statObject("bucket", "videos/final/input.mp4")).isPresent();
        assertThat(objectMetadataRepository.findByKey("bucket", "videos/raw/input.mp4")).isEmpty();
        assertThat(objectMetadataRepository.findByKey("bucket", "videos/final/input.mp4")).isPresent();
    }

    @Test
    void bucketScopedLifecycleRuleOnlyPurgesMatchingBucket() {
        OffsetDateTime now = OffsetDateTime.now();
        retentionPolicyRepository.save(new ObjectRetentionPolicy(true, 365, 100, 90, 100, now));
        storageAdapter.createBucket("bucket-a");
        storageAdapter.createBucket("bucket-b");
        StoredObjectRecord bucketAObject = storageAdapter.putObject(
                "bucket-a",
                "videos/raw/input.mp4",
                new ByteArrayInputStream("raw-a".getBytes()),
                5L,
                "video/mp4",
                Map.of("stage", "raw")
        );
        StoredObjectRecord bucketBObject = storageAdapter.putObject(
                "bucket-b",
                "videos/raw/input.mp4",
                new ByteArrayInputStream("raw-b".getBytes()),
                5L,
                "video/mp4",
                Map.of("stage", "raw")
        );
        objectMetadataRepository.save("bucket-a", bucketAObject.withDeletedAt(now.minusDays(8)));
        objectMetadataRepository.save("bucket-b", bucketBObject.withDeletedAt(now.minusDays(8)));
        lifecycleRuleRepository.save(new ObjectLifecycleRule(
                "rule-bucket-a",
                "Bucket A raw trash",
                true,
                10,
                "bucket-a",
                ObjectLifecycleRule.TARGET_TRASH_OBJECT,
                "videos/raw/",
                Map.of("stage", "raw"),
                7,
                100,
                now.minusDays(1),
                now.minusDays(1)
        ));

        int purged = purgeJob.runNow(now);

        assertThat(purged).isEqualTo(1);
        assertThat(storageAdapter.statObject("bucket-a", "videos/raw/input.mp4")).isEmpty();
        assertThat(storageAdapter.statObject("bucket-b", "videos/raw/input.mp4")).isPresent();
        assertThat(objectMetadataRepository.findByKey("bucket-a", "videos/raw/input.mp4")).isEmpty();
        assertThat(objectMetadataRepository.findByKey("bucket-b", "videos/raw/input.mp4")).isPresent();
        verify(bucketService).applyObjectChange("bucket-a", -5L, -1L);
    }

    private double purgeObjectCount(String result) {
        return meterRegistry.counter("osmu.object.retention.purge.objects", "result", result).count();
    }
}
