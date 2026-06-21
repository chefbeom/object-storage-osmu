package com.example.osmu.bucket;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.example.osmu.admin.ObjectLifecycleS3XmlService;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectLifecycleRule;
import com.example.osmu.object.repository.InMemoryObjectLifecycleRuleRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class BucketLifecycleServiceStorageSyncTest {

    private static final String BUCKET_NAME = "sync-bucket";

    private final BucketService bucketService = mock(BucketService.class);
    private final InMemoryObjectLifecycleRuleRepository lifecycleRuleRepository =
            new InMemoryObjectLifecycleRuleRepository();
    private final AuditLogService auditLogService = mock(AuditLogService.class);
    private final ObjectStorageAdapter storageAdapter = mock(ObjectStorageAdapter.class);
    private final BucketLifecycleService service = new BucketLifecycleService(
            bucketService,
            lifecycleRuleRepository,
            new ObjectLifecycleS3XmlService(),
            auditLogService,
            storageAdapter
    );
    private final AuthenticatedUser user = new AuthenticatedUser(1L, "admin", "ADMIN", null);
    private final BucketRecord bucket = new BucketRecord(
            10L,
            BUCKET_NAME,
            "USER",
            1L,
            1024L,
            0L,
            0L,
            OffsetDateTime.now()
    );

    @BeforeEach
    void setUp() {
        when(bucketService.get(BUCKET_NAME, user)).thenReturn(bucket);
    }

    @Test
    void replaceXmlSyncsStorageLifecycleBeforeSavingRules() {
        List<ObjectLifecycleRule> savedRules = service.replaceXml(BUCKET_NAME, lifecycleXml(), user, null);

        assertThat(savedRules).hasSize(1);
        assertThat(lifecycleRuleRepository.findAll()).hasSize(1);

        @SuppressWarnings({"unchecked", "rawtypes"})
        ArgumentCaptor<List<ObjectLifecycleRule>> rulesCaptor = ArgumentCaptor.forClass((Class) List.class);
        verify(storageAdapter).applyBucketLifecycle(eq(BUCKET_NAME), rulesCaptor.capture());
        assertThat(rulesCaptor.getValue())
                .hasSize(1)
                .first()
                .satisfies(rule -> {
                    assertThat(rule.bucketName()).isEqualTo(BUCKET_NAME);
                    assertThat(rule.name()).isEqualTo("Storage sync");
                    assertThat(rule.prefix()).isEqualTo("tmp/");
                });
    }

    @Test
    void replaceXmlKeepsRepositoryUnchangedWhenStorageSyncFails() {
        doThrow(new RuntimeException("minio unavailable"))
                .when(storageAdapter)
                .applyBucketLifecycle(eq(BUCKET_NAME), anyList());

        assertThatThrownBy(() -> service.replaceXml(BUCKET_NAME, lifecycleXml(), user, null))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("Object storage bucket lifecycle sync failed");

        assertThat(lifecycleRuleRepository.findAll()).isEmpty();
        verifyNoInteractions(auditLogService);
    }

    @Test
    void deleteXmlKeepsRepositoryUnchangedWhenStorageDeleteFails() {
        ObjectLifecycleRule existing = lifecycleRuleRepository.save(new ObjectLifecycleRule(
                "rule-1",
                "Existing rule",
                true,
                10,
                BUCKET_NAME,
                ObjectLifecycleRule.TARGET_TRASH_OBJECT,
                "tmp/",
                java.util.Map.of(),
                7,
                100,
                OffsetDateTime.now(),
                OffsetDateTime.now()
        ));
        doThrow(new RuntimeException("delete failed"))
                .when(storageAdapter)
                .deleteBucketLifecycle(BUCKET_NAME);

        assertThatThrownBy(() -> service.deleteXml(BUCKET_NAME, user, null))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("Object storage bucket lifecycle delete sync failed");

        assertThat(lifecycleRuleRepository.findById(existing.ruleId())).isPresent();
        verifyNoInteractions(auditLogService);
    }

    private String lifecycleXml() {
        return """
                <LifecycleConfiguration>
                  <Rule>
                    <ID>Storage sync</ID>
                    <Status>Enabled</Status>
                    <Filter><Prefix>tmp/</Prefix></Filter>
                    <Expiration><Days>7</Days></Expiration>
                  </Rule>
                </LifecycleConfiguration>
                """;
    }
}
