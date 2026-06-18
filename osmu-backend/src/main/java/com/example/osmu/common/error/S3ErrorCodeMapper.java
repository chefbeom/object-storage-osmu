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
        if ("InvalidDigest".equals(s3Code) && isContentMd5Error(message)) {
            return "The Content-MD5 you specified is not valid.";
        }
        if ("BadDigest".equals(s3Code) && isContentMd5Error(message)) {
            return "The Content-MD5 you specified did not match what we received.";
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
        if ("InvalidBucketName".equals(s3Code)) {
            return "The specified bucket is not valid.";
        }
        if ("BucketAlreadyOwnedByYou".equals(s3Code)) {
            return "Your previous request to create the named bucket succeeded and you already own it.";
        }
        if ("BucketAlreadyExists".equals(s3Code)) {
            return "The requested bucket name is not available. "
                    + "The bucket namespace is shared by all users of the system. "
                    + "Please select a different name and try again.";
        }
        if ("BucketNotEmpty".equals(s3Code)) {
            return "The bucket you tried to delete is not empty.";
        }
        if ("InvalidPart".equals(s3Code)) {
            return "One or more of the specified parts could not be found. "
                    + "The part might not have been uploaded, "
                    + "or the specified ETag might not have matched the uploaded part's ETag.";
        }
        if ("InvalidPartOrder".equals(s3Code)) {
            return "The list of parts was not in ascending order. "
                    + "The parts list must be specified in order by part number.";
        }
        if ("EntityTooSmall".equals(s3Code)) {
            return "Your proposed upload is smaller than the minimum allowed object size. "
                    + "Each part must be at least 5 MB in size, except the last part.";
        }
        if ("EntityTooLarge".equals(s3Code)) {
            return "Your proposed upload exceeds the maximum allowed object size.";
        }
        if ("OperationAborted".equals(s3Code)) {
            return "A conflicting conditional action is currently in progress against this resource. Try again.";
        }
        if ("InternalError".equals(s3Code)) {
            return "We encountered an internal error. Please try again.";
        }
        if ("MissingContentLength".equals(s3Code)) {
            return "You must provide the Content-Length HTTP header.";
        }
        return message == null || message.isBlank() ? s3Code : message;
    }

    private static boolean isBucketError(String message) {
        return message != null && message.toLowerCase(Locale.ROOT).contains("bucket");
    }

    private static boolean isContentMd5Error(String message) {
        return message != null && message.toLowerCase(Locale.ROOT).contains("content-md5");
    }

    private static String validationCode(String message) {
        String normalized = message == null ? "" : message.toLowerCase(Locale.ROOT);
        if (normalized.contains("invalid s3 bucket name")) {
            return "InvalidBucketName";
        }
        if (normalized.contains("multipart upload part")
                && (normalized.contains("has not been uploaded")
                        || normalized.contains("etag does not match uploaded part"))) {
            return "InvalidPart";
        }
        if (normalized.contains("completemultipartupload parts must be in ascending partnumber order")) {
            return "InvalidPartOrder";
        }
        if (normalized.contains("minimum allowed object size")) {
            return "EntityTooSmall";
        }
        if (normalized.contains("content-length is required")) {
            return "MissingContentLength";
        }
        return "InvalidRequest";
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
