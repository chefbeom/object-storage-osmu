package com.example.osmu.accesskey;

public interface S3AccessPolicyProvisioner {

    void provision(AccessKeyRecord accessKey, String secretKey, S3AccessPolicy policy);

    void syncPolicy(AccessKeyRecord accessKey, S3AccessPolicy policy);

    void deactivate(AccessKeyRecord accessKey);

    boolean isHealthy();
}
