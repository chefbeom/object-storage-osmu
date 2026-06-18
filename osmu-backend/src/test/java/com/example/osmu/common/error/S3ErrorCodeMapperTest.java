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
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.QUOTA_EXCEEDED, "quota")).isEqualTo("EntityTooLarge");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.CONFLICT, "conflict")).isEqualTo("OperationAborted");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.CONFLICT, "Bucket is not empty.")).isEqualTo("BucketNotEmpty");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.CONFLICT, "Bucket already owned by you.")).isEqualTo("BucketAlreadyOwnedByYou");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.CONFLICT, "Bucket already exists.")).isEqualTo("BucketAlreadyExists");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.STORAGE_ERROR, "storage")).isEqualTo("InternalError");
        assertThat(S3ErrorCodeMapper.codeFor(ApiErrorCode.INTERNAL_ERROR, "server")).isEqualTo("InternalError");
    }
}
