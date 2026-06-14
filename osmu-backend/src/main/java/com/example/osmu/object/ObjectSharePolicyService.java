package com.example.osmu.object;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.repository.ObjectSharePolicyRepository;
import java.time.OffsetDateTime;
import org.springframework.stereotype.Service;

@Service
public class ObjectSharePolicyService {

    private static final int MIN_EXPIRES_SECONDS = 60;
    private static final int MAX_EXPIRES_SECONDS = ObjectSharePolicy.DEFAULT_MAX_EXPIRES_SECONDS;
    private static final int MAX_DOWNLOAD_LIMIT = 100_000;

    private final ObjectSharePolicyRepository repository;

    public ObjectSharePolicyService(ObjectSharePolicyRepository repository) {
        this.repository = repository;
    }

    public ObjectSharePolicy current() {
        return repository.get();
    }

    public ObjectSharePolicy save(ObjectSharePolicyRequest request) {
        ObjectSharePolicy current = repository.get();
        if (request == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Object share policy request is required.");
        }
        ObjectSharePolicy next = new ObjectSharePolicy(
                request.requirePassword() == null ? current.requirePassword() : request.requirePassword(),
                request.requireIpAllowlist() == null ? current.requireIpAllowlist() : request.requireIpAllowlist(),
                maxExpiresSeconds(request.maxExpiresSeconds(), current.maxExpiresSeconds()),
                maxDownloadsLimit(request.maxDownloadsLimit()),
                OffsetDateTime.now()
        );
        return repository.save(next);
    }

    public boolean isHealthy() {
        return repository.isHealthy();
    }

    private int maxExpiresSeconds(Integer value, int current) {
        int normalized = value == null ? current : value;
        if (normalized < MIN_EXPIRES_SECONDS || normalized > MAX_EXPIRES_SECONDS) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "maxExpiresSeconds must be between 60 and 604800.");
        }
        return normalized;
    }

    private Integer maxDownloadsLimit(Integer value) {
        if (value == null) {
            return null;
        }
        if (value < 1 || value > MAX_DOWNLOAD_LIMIT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "maxDownloadsLimit must be between 1 and 100000.");
        }
        return value;
    }
}
