package com.example.osmu.object.repository;

import com.example.osmu.object.ObjectSharePolicy;

public interface ObjectSharePolicyRepository {

    ObjectSharePolicy get();

    ObjectSharePolicy save(ObjectSharePolicy policy);

    boolean isHealthy();
}
