package com.example.osmu.accesskey;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

@Component
public class S3AccessPolicyGenerator {

    private final ObjectMapper objectMapper = new ObjectMapper();

    public S3AccessPolicy generate(long accessKeyId, List<String> allowedBuckets, List<String> permissions) {
        return generate(accessKeyId, allowedBuckets.stream()
                .map(bucketName -> new AccessKeyBucketScope(bucketName, permissions))
                .toList());
    }

    public S3AccessPolicy generate(long accessKeyId, List<AccessKeyBucketScope> bucketScopes) {
        String policyName = AccessKeyPolicyNames.policyName(accessKeyId);
        Map<String, Object> document = new LinkedHashMap<>();
        document.put("Version", "2012-10-17");
        document.put("Statement", statements(bucketScopes));
        try {
            return new S3AccessPolicy(policyName, objectMapper.writeValueAsString(document));
        } catch (JsonProcessingException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to generate S3 access policy.");
        }
    }

    private List<Map<String, Object>> statements(List<AccessKeyBucketScope> bucketScopes) {
        List<Map<String, Object>> statements = new ArrayList<>();
        for (AccessKeyBucketScope bucketScope : bucketScopes) {
            statements.addAll(statements(bucketScope.bucketName(), bucketScope.permissions()));
        }
        return statements;
    }

    private List<Map<String, Object>> statements(String bucketName, List<String> permissions) {
        Set<String> bucketActions = new LinkedHashSet<>();
        Set<String> objectActions = new LinkedHashSet<>();

        if (permissions.contains("READ")) {
            bucketActions.add("s3:GetBucketLocation");
            bucketActions.add("s3:ListBucket");
            objectActions.add("s3:GetObject");
        }
        if (permissions.contains("WRITE")) {
            bucketActions.add("s3:GetBucketLocation");
            bucketActions.add("s3:ListBucketMultipartUploads");
            objectActions.add("s3:PutObject");
            objectActions.add("s3:AbortMultipartUpload");
            objectActions.add("s3:ListMultipartUploadParts");
        }
        if (permissions.contains("DELETE")) {
            bucketActions.add("s3:GetBucketLocation");
            objectActions.add("s3:DeleteObject");
        }
        if (permissions.contains("ADMIN")) {
            bucketActions.add("s3:GetBucketLocation");
            bucketActions.add("s3:ListBucket");
            bucketActions.add("s3:ListBucketMultipartUploads");
            bucketActions.add("s3:GetLifecycleConfiguration");
            bucketActions.add("s3:PutLifecycleConfiguration");
            bucketActions.add("s3:GetBucketTagging");
            bucketActions.add("s3:PutBucketTagging");
            bucketActions.add("s3:DeleteBucketTagging");
            objectActions.add("s3:GetObject");
            objectActions.add("s3:PutObject");
            objectActions.add("s3:DeleteObject");
            objectActions.add("s3:AbortMultipartUpload");
            objectActions.add("s3:ListMultipartUploadParts");
        }

        List<Map<String, Object>> statements = new ArrayList<>();
        if (!bucketActions.isEmpty()) {
            statements.add(statement(bucketActions, bucketResources(List.of(bucketName))));
        }
        if (!objectActions.isEmpty()) {
            statements.add(statement(objectActions, objectResources(List.of(bucketName))));
        }
        return statements;
    }

    private Map<String, Object> statement(Set<String> actions, List<String> resources) {
        Map<String, Object> statement = new LinkedHashMap<>();
        statement.put("Effect", "Allow");
        statement.put("Action", List.copyOf(actions));
        statement.put("Resource", resources);
        return statement;
    }

    private List<String> bucketResources(List<String> allowedBuckets) {
        return allowedBuckets.stream()
                .map(bucketName -> "*".equals(bucketName) ? "arn:aws:s3:::*" : "arn:aws:s3:::" + bucketName)
                .toList();
    }

    private List<String> objectResources(List<String> allowedBuckets) {
        return allowedBuckets.stream()
                .map(bucketName -> "*".equals(bucketName) ? "arn:aws:s3:::*/*" : "arn:aws:s3:::" + bucketName + "/*")
                .toList();
    }
}
