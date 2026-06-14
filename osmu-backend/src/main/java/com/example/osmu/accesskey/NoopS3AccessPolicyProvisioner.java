package com.example.osmu.accesskey;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.access-key", name = "provisioning-mode", havingValue = "noop", matchIfMissing = true)
public class NoopS3AccessPolicyProvisioner implements S3AccessPolicyProvisioner {

    @Override
    public void provision(AccessKeyRecord accessKey, String secretKey, S3AccessPolicy policy) {
    }

    @Override
    public void syncPolicy(AccessKeyRecord accessKey, S3AccessPolicy policy) {
    }

    @Override
    public void deactivate(AccessKeyRecord accessKey) {
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
