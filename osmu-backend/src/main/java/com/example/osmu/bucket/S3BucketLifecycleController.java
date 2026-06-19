package com.example.osmu.bucket;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketLifecycleService.BucketLifecycleXml;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.Crc64NvmeChecksum;
import jakarta.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import java.util.zip.CRC32;
import java.util.zip.CRC32C;
import java.util.zip.Checksum;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping({"/api/s3/{bucketName}", "/{bucketName}"})
public class S3BucketLifecycleController {

    private static final String AWS_CONTENT_MD5_HEADER = "Content-MD5";
    private static final String AWS_CHECKSUM_SHA256_HEADER = "x-amz-checksum-sha256";
    private static final String AWS_CHECKSUM_SHA1_HEADER = "x-amz-checksum-sha1";
    private static final String AWS_CHECKSUM_CRC32_HEADER = "x-amz-checksum-crc32";
    private static final String AWS_CHECKSUM_CRC32C_HEADER = "x-amz-checksum-crc32c";
    private static final String AWS_CHECKSUM_CRC64NVME_HEADER = "x-amz-checksum-crc64nvme";
    private static final String AWS_SDK_CHECKSUM_ALGORITHM_HEADER = "x-amz-sdk-checksum-algorithm";
    private static final String AWS_TRANSITION_DEFAULT_MINIMUM_OBJECT_SIZE_HEADER =
            "x-amz-transition-default-minimum-object-size";

    private final BucketLifecycleService bucketLifecycleService;
    private final S3RequestAuthService s3RequestAuthService;

    public S3BucketLifecycleController(
            BucketLifecycleService bucketLifecycleService,
            S3RequestAuthService s3RequestAuthService
    ) {
        this.bucketLifecycleService = bucketLifecycleService;
        this.s3RequestAuthService = s3RequestAuthService;
    }

    @GetMapping(value = {"", "/"}, params = "lifecycle", produces = {MediaType.APPLICATION_XML_VALUE, MediaType.TEXT_XML_VALUE})
    public ResponseEntity<String> getBucketLifecycle(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        BucketLifecycleXml lifecycle = bucketLifecycleService.exportXml(bucketName, currentUser(request, bucketName));
        if (lifecycle.ruleCount() == 0) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Lifecycle configuration not found.");
        }
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(lifecycle.xml());
    }

    @PutMapping(value = {"", "/"}, params = "lifecycle", consumes = {MediaType.APPLICATION_XML_VALUE, MediaType.TEXT_XML_VALUE})
    public ResponseEntity<Void> putBucketLifecycle(
            @PathVariable("bucketName") String bucketName,
            @RequestBody(required = false) String rawXml,
            HttpServletRequest request
    ) {
        if (rawXml == null || rawXml.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Lifecycle XML is required.");
        }
        validateUnsupportedTransitionDefaultMinimumObjectSize(request);
        validateLifecycleChecksumHeaders(rawXml, request);
        AuthenticatedUser user = currentUser(request, bucketName);
        bucketLifecycleService.replaceXml(bucketName, rawXml, user, request);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping(value = {"", "/"}, params = "lifecycle")
    public ResponseEntity<Void> deleteBucketLifecycle(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        bucketLifecycleService.deleteXml(bucketName, currentUser(request, bucketName), request);
        return ResponseEntity.noContent().build();
    }

    private AuthenticatedUser currentUser(HttpServletRequest request, String bucketName) {
        return s3RequestAuthService.currentUser(request, bucketName, "ADMIN");
    }

    private void validateUnsupportedTransitionDefaultMinimumObjectSize(HttpServletRequest request) {
        String value = request.getHeader(AWS_TRANSITION_DEFAULT_MINIMUM_OBJECT_SIZE_HEADER);
        if (value != null && !value.isBlank()) {
            throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    AWS_TRANSITION_DEFAULT_MINIMUM_OBJECT_SIZE_HEADER + " is not supported for OSMU S3 Bucket lifecycle."
            );
        }
    }

    private void validateLifecycleChecksumHeaders(String rawXml, HttpServletRequest request) {
        byte[] body = rawXml.getBytes(StandardCharsets.UTF_8);
        validateContentMd5(body, request.getHeader(AWS_CONTENT_MD5_HEADER));

        String checksumHeader = explicitChecksumHeader(request);
        String sdkChecksumHeader = sdkChecksumHeader(request);
        if (!sdkChecksumHeader.isBlank() && checksumHeader.isBlank()) {
            throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    AWS_SDK_CHECKSUM_ALGORITHM_HEADER + " requires a matching x-amz-checksum-* header for S3 Bucket lifecycle."
            );
        }
        if (!sdkChecksumHeader.isBlank() && !sdkChecksumHeader.equals(checksumHeader)) {
            throw new ApiException(
                    ApiErrorCode.BAD_DIGEST,
                    AWS_SDK_CHECKSUM_ALGORITHM_HEADER + " does not match lifecycle checksum."
            );
        }
        if (!checksumHeader.isBlank()) {
            validateChecksum(body, checksumHeader, request.getHeader(checksumHeader));
        }
    }

    private void validateContentMd5(byte[] body, String expectedContentMd5) {
        if (expectedContentMd5 == null || expectedContentMd5.isBlank()) {
            return;
        }
        byte[] expected = decodeChecksum(AWS_CONTENT_MD5_HEADER, expectedContentMd5, 16);
        byte[] actual = messageDigest("MD5").digest(body);
        if (!MessageDigest.isEqual(expected, actual)) {
            throw new ApiException(ApiErrorCode.BAD_DIGEST, "Content-MD5 does not match lifecycle XML body.");
        }
    }

    private String explicitChecksumHeader(HttpServletRequest request) {
        List<String> headers = new ArrayList<>();
        for (String headerName : List.of(
                AWS_CHECKSUM_SHA256_HEADER,
                AWS_CHECKSUM_SHA1_HEADER,
                AWS_CHECKSUM_CRC32_HEADER,
                AWS_CHECKSUM_CRC32C_HEADER,
                AWS_CHECKSUM_CRC64NVME_HEADER
        )) {
            String value = request.getHeader(headerName);
            if (value != null && !value.isBlank()) {
                headers.add(headerName);
            }
        }
        if (headers.size() > 1) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, "Only one x-amz-checksum-* header is supported.");
        }
        return headers.isEmpty() ? "" : headers.get(0);
    }

    private String sdkChecksumHeader(HttpServletRequest request) {
        String rawAlgorithm = request.getHeader(AWS_SDK_CHECKSUM_ALGORITHM_HEADER);
        if (rawAlgorithm == null || rawAlgorithm.isBlank()) {
            return "";
        }
        if (rawAlgorithm.contains(",")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, AWS_SDK_CHECKSUM_ALGORITHM_HEADER + " must specify one checksum algorithm.");
        }
        return checksumHeaderForAlgorithm(rawAlgorithm.trim());
    }

    private String checksumHeaderForAlgorithm(String algorithm) {
        return switch (algorithm == null ? "" : algorithm.trim().toUpperCase(Locale.ROOT)) {
            case "SHA256" -> AWS_CHECKSUM_SHA256_HEADER;
            case "SHA1" -> AWS_CHECKSUM_SHA1_HEADER;
            case "CRC32" -> AWS_CHECKSUM_CRC32_HEADER;
            case "CRC32C" -> AWS_CHECKSUM_CRC32C_HEADER;
            case "CRC64NVME" -> AWS_CHECKSUM_CRC64NVME_HEADER;
            default -> throw new ApiException(ApiErrorCode.VALIDATION_ERROR, AWS_SDK_CHECKSUM_ALGORITHM_HEADER + " is not supported.");
        };
    }

    private void validateChecksum(byte[] body, String headerName, String rawChecksum) {
        byte[] expected = decodeChecksum(headerName, rawChecksum, checksumLength(headerName));
        byte[] actual = switch (headerName) {
            case AWS_CHECKSUM_SHA256_HEADER -> messageDigest("SHA-256").digest(body);
            case AWS_CHECKSUM_SHA1_HEADER -> messageDigest("SHA-1").digest(body);
            case AWS_CHECKSUM_CRC32_HEADER -> crcDigest(body, new CRC32(), 4);
            case AWS_CHECKSUM_CRC32C_HEADER -> crcDigest(body, new CRC32C(), 4);
            case AWS_CHECKSUM_CRC64NVME_HEADER -> crcDigest(body, new Crc64NvmeChecksum(), Crc64NvmeChecksum.DIGEST_LENGTH_BYTES);
            default -> throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " is not supported.");
        };
        if (!MessageDigest.isEqual(expected, actual)) {
            throw new ApiException(ApiErrorCode.BAD_DIGEST, headerName + " does not match lifecycle XML body.");
        }
    }

    private int checksumLength(String headerName) {
        return switch (headerName) {
            case AWS_CHECKSUM_SHA256_HEADER -> 32;
            case AWS_CHECKSUM_SHA1_HEADER -> 20;
            case AWS_CHECKSUM_CRC32_HEADER, AWS_CHECKSUM_CRC32C_HEADER -> 4;
            case AWS_CHECKSUM_CRC64NVME_HEADER -> Crc64NvmeChecksum.DIGEST_LENGTH_BYTES;
            default -> throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " is not supported.");
        };
    }

    private byte[] crcDigest(byte[] body, Checksum checksum, int length) {
        checksum.update(body, 0, body.length);
        long value = checksum.getValue();
        return length == 8 ? longDigest(value) : intDigest(value);
    }

    private byte[] intDigest(long value) {
        long normalized = value & 0xffffffffL;
        return new byte[]{
                (byte) (normalized >>> 24),
                (byte) (normalized >>> 16),
                (byte) (normalized >>> 8),
                (byte) normalized
        };
    }

    private byte[] longDigest(long value) {
        return new byte[]{
                (byte) (value >>> 56),
                (byte) (value >>> 48),
                (byte) (value >>> 40),
                (byte) (value >>> 32),
                (byte) (value >>> 24),
                (byte) (value >>> 16),
                (byte) (value >>> 8),
                (byte) value
        };
    }

    private byte[] decodeChecksum(String headerName, String rawChecksum, int expectedLength) {
        byte[] decoded;
        try {
            decoded = Base64.getDecoder().decode(rawChecksum.trim());
        } catch (RuntimeException exception) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " must be a valid base64 checksum.");
        }
        if (decoded.length != expectedLength) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " has invalid checksum length.");
        }
        return decoded;
    }

    private MessageDigest messageDigest(String algorithm) {
        try {
            return MessageDigest.getInstance(algorithm);
        } catch (NoSuchAlgorithmException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, algorithm + " checksum is unavailable.");
        }
    }
}
