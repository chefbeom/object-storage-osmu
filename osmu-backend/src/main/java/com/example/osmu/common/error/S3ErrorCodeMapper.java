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
            case VALIDATION_ERROR -> validationCode(message);
            case QUOTA_EXCEEDED -> "EntityTooLarge";
            case CONFLICT -> conflictCode(message);
            case STORAGE_ERROR, INTERNAL_ERROR -> "InternalError";
        };
    }

    public static String messageFor(String s3Code, String message) {
        if ("AccessDenied".equals(s3Code)) {
            return "Access Denied";
        }
        if ("InvalidRange".equals(s3Code)) {
            return "The requested range cannot be satisfied.";
        }
        if ("NoSuchBucket".equals(s3Code)) {
            return "The specified bucket does not exist";
        }
        if ("NoSuchKey".equals(s3Code)) {
            return "The specified key does not exist.";
        }
        if ("NoSuchUpload".equals(s3Code)) {
            return "The specified multipart upload does not exist. The upload ID might be invalid, or the multipart upload might have been aborted or completed.";
        }
        if ("PreconditionFailed".equals(s3Code)) {
            return "At least one of the pre-conditions you specified did not hold";
        }
        return message == null || message.isBlank() ? s3Code : message;
    }

    private static boolean isBucketError(String message) {
        return message != null && message.toLowerCase(Locale.ROOT).contains("bucket");
    }

    private static String validationCode(String message) {
        String normalized = message == null ? "" : message.toLowerCase(Locale.ROOT);
        return normalized.contains("invalid s3 bucket name") ? "InvalidBucketName" : "InvalidRequest";
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
