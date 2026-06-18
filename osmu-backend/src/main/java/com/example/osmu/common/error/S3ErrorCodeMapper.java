package com.example.osmu.common.error;

import java.util.Locale;

public final class S3ErrorCodeMapper {

    private S3ErrorCodeMapper() {
    }

    public static String codeFor(ApiErrorCode code, String message) {
        return switch (code) {
            case AUTHENTICATION_REQUIRED, AUTHORIZATION_FAILED -> "AccessDenied";
            case NOT_FOUND -> notFoundCode(message);
            case PRECONDITION_FAILED -> "PreconditionFailed";
            case RANGE_NOT_SATISFIABLE -> "InvalidRange";
            case INVALID_DIGEST -> "InvalidDigest";
            case BAD_DIGEST -> "BadDigest";
            case VALIDATION_ERROR -> "InvalidRequest";
            case QUOTA_EXCEEDED -> "EntityTooLarge";
            case CONFLICT -> conflictCode(message);
            case STORAGE_ERROR, INTERNAL_ERROR -> "InternalError";
        };
    }

    private static boolean isBucketError(String message) {
        return message != null && message.toLowerCase(Locale.ROOT).contains("bucket");
    }

    private static String notFoundCode(String message) {
        if (isUploadError(message)) {
            return "NoSuchUpload";
        }
        return isBucketError(message) ? "NoSuchBucket" : "NoSuchKey";
    }

    private static boolean isUploadError(String message) {
        String normalized = message == null ? "" : message.toLowerCase(Locale.ROOT);
        return normalized.contains("upload session") || normalized.contains("multipart upload");
    }

    private static boolean isBucketNotEmpty(String message) {
        String normalized = message == null ? "" : message.toLowerCase(Locale.ROOT);
        return normalized.contains("bucket") && normalized.contains("not empty");
    }

    private static String conflictCode(String message) {
        String normalized = message == null ? "" : message.toLowerCase(Locale.ROOT);
        if (isBucketNotEmpty(message)) {
            return "BucketNotEmpty";
        }
        if (normalized.contains("bucket") && normalized.contains("already owned by you")) {
            return "BucketAlreadyOwnedByYou";
        }
        if (normalized.contains("bucket") && normalized.contains("already exists")) {
            return "BucketAlreadyExists";
        }
        return "OperationAborted";
    }
}
