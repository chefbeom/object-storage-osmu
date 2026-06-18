package com.example.osmu.accesskey.repository;

import com.example.osmu.accesskey.AccessKeyEntity;
import com.example.osmu.accesskey.AccessKeyBucketScope;
import com.example.osmu.accesskey.AccessKeyCredential;
import com.example.osmu.accesskey.AccessKeyRecord;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface AccessKeyRepository {

    List<AccessKeyRecord> findAllRecords();

    List<AccessKeyRecord> findRecordsByOwnerId(long ownerId);

    Optional<AccessKeyRecord> findRecordById(long id);

    Optional<AccessKeyCredential> findCredentialByAccessKey(String accessKey);

    long nextId();

    AccessKeyRecord save(AccessKeyEntity accessKey);

    void updateScope(long id, List<String> allowedBuckets, List<String> permissions, List<AccessKeyBucketScope> bucketScopes);

    void updateStatus(long id, String status);

    void updateSecret(long id, String secretKeyHash, String secretKeyCiphertext);

    void markUsed(long id, OffsetDateTime usedAt);

    boolean isHealthy();
}
