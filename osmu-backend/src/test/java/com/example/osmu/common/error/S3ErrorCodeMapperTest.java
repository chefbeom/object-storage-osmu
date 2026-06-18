package com.example.osmu.common.error;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class S3ErrorCodeMapperTest {

    @Test
    void mapsApiErrorsToS3XmlErrorCodes() {
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.AUTHENTICATION_REQUIRED, "expired")).isEqualTo("AccessDenied");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.AUTHORIZATION_FAILED, "denied")).isEqualTo("AccessDenied");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.NOT_FOUND, "Bucket not found.")).isEqualTo("NoSuchBucket");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.NOT_FOUND, "Object not found.")).isEqualTo("NoSuchKey");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.NOT_FOUND, "Upload session not found.")).isEqualTo("NoSuchUpload");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.PRECONDITION_FAILED, "failed")).isEqualTo("PreconditionFailed");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.RANGE_NOT_SATISFIABLE, "range")).isEqualTo("InvalidRange");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.INVALID_DIGEST, "digest")).isEqualTo("InvalidDigest");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.BAD_DIGEST, "digest")).isEqualTo("BadDigest");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.VALIDATION_ERROR, "invalid")).isEqualTo("InvalidRequest");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.VALIDATION_ERROR, "Invalid S3 bucket name.")).isEqualTo("InvalidBucketName");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.VALIDATION_ERROR,
                "Multipart upload part 1 has not been uploaded.")).isEqualTo("InvalidPart");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.VALIDATION_ERROR,
                "Multipart upload part 2 ETag does not match uploaded part.")).isEqualTo("InvalidPart");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.VALIDATION_ERROR,
                "CompleteMultipartUpload parts must be in ascending PartNumber order without duplicates.")).isEqualTo("InvalidPartOrder");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.VALIDATION_ERROR,
                "Multipart upload part 1 is smaller than the minimum allowed object size.")).isEqualTo("EntityTooSmall");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.VALIDATION_ERROR,
                "Content-Length is required for S3 object upload.")).isEqualTo("MissingContentLength");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.VALIDATION_ERROR,
                "Request body length does not match expected content length.")).isEqualTo("IncompleteBody");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.QUOTA_EXCEEDED, "quota")).isEqualTo("EntityTooLarge");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.CONFLICT, "conflict")).isEqualTo("OperationAborted");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.CONFLICT, "Bucket is not empty.")).isEqualTo("BucketNotEmpty");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.CONFLICT, "Bucket already owned by you.")).isEqualTo("BucketAlreadyOwnedByYou");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.CONFLICT, "Bucket already exists.")).isEqualTo("BucketAlreadyExists");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.STORAGE_ERROR, "storage")).isEqualTo("InternalError");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.INTERNAL_ERROR, "server")).isEqualTo("InternalError");
    }

    @Test
    void normalizesS3ErrorMessages() {
        assertThat(S3ErrorCodeMapper.messageFor("AccessDenied", "Missing access key credentials.")).isEqualTo("Access Denied");
        assertThat(S3ErrorCodeMapper.messageFor("InvalidRange", "Invalid Range header.")).isEqualTo("The requested range cannot be satisfied.");
        assertThat(S3ErrorCodeMapper.messageFor("BadDigest", "Content-MD5 does not match request body."))
                .isEqualTo("The Content-MD5 you specified did not match what we received.");
        assertThat(S3ErrorCodeMapper.messageFor("InvalidDigest", "Content-MD5 must be a valid base64 MD5 digest."))
                .isEqualTo("The Content-MD5 you specified is not valid.");
        assertThat(S3ErrorCodeMapper.messageFor("BadDigest", "x-amz-checksum-sha256 does not match uploaded object body."))
                .isEqualTo("x-amz-checksum-sha256 does not match uploaded object body.");
        assertThat(S3ErrorCodeMapper.messageFor("NoSuchBucket", "Bucket not found.")).isEqualTo("The specified bucket does not exist");
        assertThat(S3ErrorCodeMapper.messageFor("NoSuchKey", "Object not found.")).isEqualTo("The specified key does not exist.");
        assertThat(S3ErrorCodeMapper.messageFor("NoSuchUpload", "Upload session not found."))
                .isEqualTo("The specified multipart upload does not exist. The upload ID might be invalid, or the multipart upload might have been aborted or completed.");
        assertThat(S3ErrorCodeMapper.messageFor("PreconditionFailed", "Object precondition failed."))
                .isEqualTo("At least one of the pre-conditions you specified did not hold");
        assertThat(S3ErrorCodeMapper.messageFor("InvalidBucketName", "Invalid S3 bucket name."))
                .isEqualTo("The specified bucket is not valid.");
        assertThat(S3ErrorCodeMapper.messageFor("BucketAlreadyOwnedByYou", "Bucket already owned by you."))
                .isEqualTo("Your previous request to create the named bucket succeeded and you already own it.");
        assertThat(S3ErrorCodeMapper.messageFor("BucketAlreadyExists", "Bucket already exists."))
                .isEqualTo("The requested bucket name is not available. "
                        + "The bucket namespace is shared by all users of the system. "
                        + "Please select a different name and try again.");
        assertThat(S3ErrorCodeMapper.messageFor("BucketNotEmpty", "Bucket is not empty."))
                .isEqualTo("The bucket you tried to delete is not empty.");
        assertThat(S3ErrorCodeMapper.messageFor("InvalidPart", "Multipart upload part 1 has not been uploaded."))
                .isEqualTo("One or more of the specified parts could not be found. "
                        + "The part might not have been uploaded, "
                        + "or the specified ETag might not have matched the uploaded part's ETag.");
        assertThat(S3ErrorCodeMapper.messageFor("InvalidPartOrder", "part order"))
                .isEqualTo("The list of parts was not in ascending order. "
                        + "The parts list must be specified in order by part number.");
        assertThat(S3ErrorCodeMapper.messageFor("EntityTooSmall", "small part"))
                .isEqualTo("Your proposed upload is smaller than the minimum allowed object size. "
                        + "Each part must be at least 5 MB in size, except the last part.");
        assertThat(S3ErrorCodeMapper.messageFor("EntityTooLarge", "Bucket quota exceeded."))
                .isEqualTo("Your proposed upload exceeds the maximum allowed object size.");
        assertThat(S3ErrorCodeMapper.messageFor("OperationAborted", "conflict"))
                .isEqualTo("A conflicting conditional action is currently in progress against this resource. Try again.");
        assertThat(S3ErrorCodeMapper.messageFor("InternalError", "storage unavailable"))
                .isEqualTo("We encountered an internal error. Please try again.");
        assertThat(S3ErrorCodeMapper.messageFor("MissingContentLength", "Content-Length is required for S3 object upload."))
                .isEqualTo("You must provide the Content-Length HTTP header.");
        assertThat(S3ErrorCodeMapper.messageFor("IncompleteBody", "Request body length does not match expected content length."))
                .isEqualTo("You did not provide the number of bytes specified by the Content-Length HTTP header");
    }
}
