package com.example.osmu.bucket;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.admin.ObjectLifecycleS3XmlService;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class BucketLifecycleServiceQueryTest {

    @Test
    void exportLoadsOnlyTheSelectedBucketRules() {
        BucketService bucketService = mock(BucketService.class);
        ObjectLifecycleRuleRepository ruleRepository = mock(ObjectLifecycleRuleRepository.class);
        ObjectLifecycleS3XmlService xmlService = mock(ObjectLifecycleS3XmlService.class);
        AuthenticatedUser user = new AuthenticatedUser(7L, "developer", "USER", null);
        BucketRecord bucket = new BucketRecord(
                1L,
                "alpha",
                "USER",
                7L,
                1024L,
                0L,
                0L,
                OffsetDateTime.now()
        );
        when(bucketService.get("alpha", user)).thenReturn(bucket);
        when(ruleRepository.findByBucketName("alpha")).thenReturn(List.of());
        when(xmlService.exportRules(List.of())).thenReturn("<LifecycleConfiguration/>");
        BucketLifecycleService service = new BucketLifecycleService(
                bucketService,
                ruleRepository,
                xmlService,
                mock(AuditLogService.class),
                mock(ObjectStorageAdapter.class)
        );

        service.exportXml("alpha", user);

        verify(ruleRepository).findByBucketName("alpha");
        verify(ruleRepository, never()).findAllForExport();
    }
}