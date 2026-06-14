package com.example.osmu.common.error;

import org.springframework.http.HttpStatusCode;

public enum ApiErrorCode {
    VALIDATION_ERROR(HttpStatusCode.valueOf(400)),
    AUTHENTICATION_REQUIRED(HttpStatusCode.valueOf(401)),
    AUTHORIZATION_FAILED(HttpStatusCode.valueOf(403)),
    NOT_FOUND(HttpStatusCode.valueOf(404)),
    CONFLICT(HttpStatusCode.valueOf(409)),
    PRECONDITION_FAILED(HttpStatusCode.valueOf(412)),
    RANGE_NOT_SATISFIABLE(HttpStatusCode.valueOf(416)),
    QUOTA_EXCEEDED(HttpStatusCode.valueOf(413)),
    INVALID_DIGEST(HttpStatusCode.valueOf(400)),
    BAD_DIGEST(HttpStatusCode.valueOf(400)),
    STORAGE_ERROR(HttpStatusCode.valueOf(502)),
    INTERNAL_ERROR(HttpStatusCode.valueOf(500));

    private final HttpStatusCode status;

    ApiErrorCode(HttpStatusCode status) {
        this.status = status;
    }

    public HttpStatusCode status() {
        return status;
    }
}
