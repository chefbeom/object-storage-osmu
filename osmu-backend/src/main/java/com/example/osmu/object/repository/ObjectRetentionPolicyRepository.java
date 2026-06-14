package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectRetentionPolicy;

public interface ObjectRetentionPolicyRepository {

    ObjectRetentionPolicy getPolicy();

    ObjectRetentionPolicy save(ObjectRetentionPolicy policy);

    boolean isHealthy();
}
