package com.example.osmu.bucket;

import com.example.osmu.admin.ObjectLifecycleS3XmlService;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.object.ObjectLifecycleRule;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
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

    public BucketLifecycleService(
            BucketService bucketService,
            ObjectLifecycleRuleRepository lifecycleRuleRepository,
            ObjectLifecycleS3XmlService lifecycleS3XmlService,
            AuditLogService auditLogService
    ) {
        this.bucketService = bucketService;
        this.lifecycleRuleRepository = lifecycleRuleRepository;
        this.lifecycleS3XmlService = lifecycleS3XmlService;
        this.auditLogService = auditLogService;
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
        deleteBucketRules(bucket.name());
        List<ObjectLifecycleRule> savedRules = importedRules.stream()
                .map(lifecycleRuleRepository::save)
                .toList();
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
        deleteBucketRules(bucket.name());
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

    public record BucketLifecycleXml(int ruleCount, String xml) {
    }
}
