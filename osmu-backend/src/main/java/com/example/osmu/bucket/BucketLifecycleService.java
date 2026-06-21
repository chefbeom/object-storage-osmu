package com.example.osmu.bucket;

import com.example.osmu.admin.ObjectLifecycleS3XmlService;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.object.ObjectLifecycleRule;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.example.osmu.storage.ObjectStorageFailures;
import jakarta.servlet.http.HttpServletRequest;
import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class BucketLifecycleService {

    private final BucketService bucketService;
    private final ObjectLifecycleRuleRepository lifecycleRuleRepository;
    private final ObjectLifecycleS3XmlService lifecycleS3XmlService;
    private final AuditLogService auditLogService;
    private final ObjectStorageAdapter storageAdapter;

    public BucketLifecycleService(
            BucketService bucketService,
            ObjectLifecycleRuleRepository lifecycleRuleRepository,
            ObjectLifecycleS3XmlService lifecycleS3XmlService,
            AuditLogService auditLogService,
            ObjectStorageAdapter storageAdapter
    ) {
        this.bucketService = bucketService;
        this.lifecycleRuleRepository = lifecycleRuleRepository;
        this.lifecycleS3XmlService = lifecycleS3XmlService;
        this.auditLogService = auditLogService;
        this.storageAdapter = storageAdapter;
    }

    public BucketLifecycleXml exportXml(String bucketName, AuthenticatedUser user) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.assertCanManage(user, bucket);
        List<ObjectLifecycleRule> rules = bucketRules(bucket.name());
        return new BucketLifecycleXml(rules.size(), lifecycleS3XmlService.exportRules(rules));
    }

    public List<ObjectLifecycleRule> replaceXml(
            String bucketName,
            String rawXml,
            AuthenticatedUser user,
            HttpServletRequest request
    ) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.assertCanManage(user, bucket);
        List<ObjectLifecycleRule> importedRules = lifecycleS3XmlService.importRules(
                rawXml,
                OffsetDateTime.now(),
                bucket.name()
        );
        List<ObjectLifecycleRule> previousRules = bucketRules(bucket.name());
        ObjectStorageFailures.run(
                "bucket lifecycle sync",
                () -> storageAdapter.applyBucketLifecycle(bucket.name(), importedRules)
        );
        List<ObjectLifecycleRule> savedRules;
        try {
            deleteBucketRules(bucket.name());
            savedRules = importedRules.stream()
                    .map(lifecycleRuleRepository::save)
                    .toList();
        } catch (RuntimeException exception) {
            restoreBucketLifecycle(bucket.name(), previousRules, exception);
            throw exception;
        }
        auditLogService.record(
                "BUCKET_LIFECYCLE_PUT",
                user.loginId(),
                "BUCKET",
                bucket.name(),
                "SUCCESS",
                "Bucket lifecycle configuration replaced",
                request
        );
        return savedRules;
    }

    public void deleteXml(String bucketName, AuthenticatedUser user, HttpServletRequest request) {
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.assertCanManage(user, bucket);
        List<ObjectLifecycleRule> previousRules = bucketRules(bucket.name());
        ObjectStorageFailures.run(
                "bucket lifecycle delete sync",
                () -> storageAdapter.deleteBucketLifecycle(bucket.name())
        );
        try {
            deleteBucketRules(bucket.name());
        } catch (RuntimeException exception) {
            restoreBucketLifecycle(bucket.name(), previousRules, exception);
            throw exception;
        }
        auditLogService.record(
                "BUCKET_LIFECYCLE_DELETE",
                user.loginId(),
                "BUCKET",
                bucket.name(),
                "SUCCESS",
                "Bucket lifecycle configuration deleted",
                request
        );
    }

    private List<ObjectLifecycleRule> bucketRules(String bucketName) {
        return lifecycleRuleRepository.findAll()
                .stream()
                .filter(rule -> bucketName.equals(rule.bucketName()))
                .toList();
    }

    private void deleteBucketRules(String bucketName) {
        for (ObjectLifecycleRule rule : bucketRules(bucketName)) {
            lifecycleRuleRepository.delete(rule.ruleId());
        }
    }

    private void restoreBucketLifecycle(
            String bucketName,
            List<ObjectLifecycleRule> previousRules,
            RuntimeException originalException
    ) {
        try {
            if (previousRules.isEmpty()) {
                ObjectStorageFailures.run(
                        "bucket lifecycle restore delete",
                        () -> storageAdapter.deleteBucketLifecycle(bucketName)
                );
            } else {
                ObjectStorageFailures.run(
                        "bucket lifecycle restore",
                        () -> storageAdapter.applyBucketLifecycle(bucketName, previousRules)
                );
            }
        } catch (RuntimeException restoreException) {
            originalException.addSuppressed(restoreException);
        }
    }

    public record BucketLifecycleXml(int ruleCount, String xml) {
    }
}
