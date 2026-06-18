package com.example.osmu.common.error;

import java.util.Locale;

public final class S3ErrorCodeMapper {

    private S3ErrorCodeMapper() {
    }

    public static String codeFor(ApiErrorCode code, String message) {
        return switch (code) {
            case AUTHENTICATION_REQUIRED, AUTHORIZATION_FAILED -> "AccessDenied";
            case NOT_FOUND -> isBucketError(message) ? "NoSuchBucket" : "NoSuchKey";
            case PRECONDITION_FAILED -> "PreconditionFailed";
            case RANGE_NOT_SATISFIABLE -> "InvalidRange";
            case INVALID_DIGEST -> "InvalidDigest";
            case BAD_DIGEST -> "BadDigest";
            case VALIDATION_ERROR -> "InvalidRequest";
            case QUOTA_EXCEEDED -> "EntityTooLarge";
            case CONFLICT -> isBucketNotEmpty(message) ? "BucketNotEmpty" : "OperationAborted";
            case STORAGE_ERROR, INTERNAL_ERROR -> "InternalError";
        };
    }

    private static boolean isBucketError(String message) {
        return message != null && message.toLowerCase(Locale.ROOT).contains("bucket");
    }

    private static boolean isBucketNotEmpty(String message) {
        String normalized = message == null ? "" : message.toLowerCase(Locale.ROOT);
        return normalized.contains("bucket") && normalized.contains("not empty");
    }
}
