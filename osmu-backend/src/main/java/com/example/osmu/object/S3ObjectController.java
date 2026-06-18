package com.example.osmu.object;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.S3RequestAuthService;
import com.example.osmu.bucket.S3SignatureV4Verifier;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.common.error.S3ErrorCodeMapper;
import com.example.osmu.monitoring.DataFlowMonitoringService;
import jakarta.servlet.http.HttpServletRequest;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringReader;
import java.io.StringWriter;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.security.DigestInputStream;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Enumeration;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.zip.CRC32;
import java.util.zip.CRC32C;
import java.util.zip.Checksum;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.stream.XMLOutputFactory;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamWriter;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

@RestController
@RequestMapping({"/api/s3/{bucketName}", "/{bucketName}"})
public class S3ObjectController {

    private static final String OSMU_TAGS_HEADER = "X-OSMU-Tags";
    private static final String AWS_TAGGING_HEADER = "x-amz-tagging";
    private static final String AWS_METADATA_DIRECTIVE_HEADER = "x-amz-metadata-directive";
    private static final String AWS_TAGGING_DIRECTIVE_HEADER = "x-amz-tagging-directive";
    private static final String AWS_USER_METADATA_PREFIX = "x-amz-meta-";
    private static final String AWS_COPY_SOURCE_IF_MATCH_HEADER = "x-amz-copy-source-if-match";
    private static final String AWS_COPY_SOURCE_IF_NONE_MATCH_HEADER = "x-amz-copy-source-if-none-match";
    private static final String AWS_COPY_SOURCE_IF_MODIFIED_SINCE_HEADER = "x-amz-copy-source-if-modified-since";
    private static final String AWS_COPY_SOURCE_IF_UNMODIFIED_SINCE_HEADER = "x-amz-copy-source-if-unmodified-since";
    private static final String AWS_CONTENT_MD5_HEADER = "Content-MD5";
    private static final String AWS_CONTENT_SHA256_HEADER = "x-amz-content-sha256";
    private static final String AWS_DECODED_CONTENT_LENGTH_HEADER = "x-amz-decoded-content-length";
    private static final String AWS_TRAILER_HEADER = "x-amz-trailer";
    private static final String AWS_CHECKSUM_SHA256_HEADER = "x-amz-checksum-sha256";
    private static final String AWS_CHECKSUM_SHA1_HEADER = "x-amz-checksum-sha1";
    private static final String AWS_CHECKSUM_CRC32_HEADER = "x-amz-checksum-crc32";
    private static final String AWS_CHECKSUM_CRC32C_HEADER = "x-amz-checksum-crc32c";
    private static final String AWS_CHECKSUM_CRC64NVME_HEADER = "x-amz-checksum-crc64nvme";
    private static final String AWS_CHECKSUM_ALGORITHM_HEADER = "x-amz-checksum-algorithm";
    private static final String HTTP_IF_RANGE_HEADER = "If-Range";
    private static final String AWS_UNSIGNED_PAYLOAD = "UNSIGNED-PAYLOAD";
    private static final String AWS_STREAMING_PAYLOAD_PREFIX = "STREAMING-";
    private static final String AWS_CHUNKED_CONTENT_ENCODING = "aws-chunked";
    private static final String OSMU_MULTIPART_SIZE_HEADER = "X-OSMU-Multipart-Size-Bytes";
    private static final String AWS_META_OSMU_SIZE_HEADER = "x-amz-meta-osmu-size-bytes";
    private static final String OSMU_MULTIPART_PART_SIZE_HEADER = "X-OSMU-Multipart-Part-Size-Bytes";
    private static final String AWS_META_OSMU_PART_SIZE_HEADER = "x-amz-meta-osmu-part-size-bytes";
    private static final String OSMU_MULTIPART_EXPIRES_HEADER = "X-OSMU-Multipart-Expires-In-Seconds";
    private static final int DEFAULT_MAX_KEYS = 1000;
    private static final int DEFAULT_MAX_UPLOADS = 1000;
    private static final int DEFAULT_MAX_PARTS = 1000;
    private static final int MAX_MULTIPART_PART_NUMBER = 10_000;

    private final ObjectService objectService;
    private final S3RequestAuthService s3RequestAuthService;
    private final AuditLogService auditLogService;
    private final DataFlowMonitoringService dataFlowMonitoringService;

    public S3ObjectController(
            ObjectService objectService,
            S3RequestAuthService s3RequestAuthService,
            AuditLogService auditLogService,
            DataFlowMonitoringService dataFlowMonitoringService
    ) {
        this.objectService = objectService;
        this.s3RequestAuthService = s3RequestAuthService;
        this.auditLogService = auditLogService;
        this.dataFlowMonitoringService = dataFlowMonitoringService;
    }

    @GetMapping(value = {"", "/"}, params = "list-type=2", produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> listObjectsV2(
            @PathVariable("bucketName") String bucketName,
            @RequestParam(name = "prefix", required = false) String prefix,
            @RequestParam(name = "delimiter", required = false) String delimiter,
            @RequestParam(name = "max-keys", required = false) Integer maxKeys,
            @RequestParam(name = "continuation-token", required = false) String continuationToken,
            @RequestParam(name = "encoding-type", required = false) String encodingType,
            @RequestParam(name = "fetch-owner", required = false) String fetchOwner,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "READ");
        int normalizedMaxKeys = normalizeMaxKeys(maxKeys);
        boolean urlEncode = useUrlEncoding(encodingType);
        boolean includeOwner = useFetchOwner(fetchOwner);
        StoredObjectPage page = objectService.list(
                bucketName,
                prefix,
                delimiter,
                "",
                null,
                continuationToken,
                normalizedMaxKeys,
                user
        );
        auditLogService.record("S3_OBJECT_LIST", user.loginId(), "BUCKET", bucketName, "SUCCESS", "S3-style object list read", request);
        dataFlowMonitoringService.recordList(bucketName, user.loginId(), "S3");
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(listObjectsXml(bucketName, prefix, delimiter, continuationToken, normalizedMaxKeys, urlEncode, includeOwner, user, page));
    }

    @GetMapping(value = {"", "/"}, params = {"!list-type", "!uploads", "!location", "!lifecycle", "!delete", "!tagging"}, produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> listObjectsV1(
            @PathVariable("bucketName") String bucketName,
            @RequestParam(name = "prefix", required = false) String prefix,
            @RequestParam(name = "delimiter", required = false) String delimiter,
            @RequestParam(name = "max-keys", required = false) Integer maxKeys,
            @RequestParam(name = "marker", required = false) String marker,
            @RequestParam(name = "encoding-type", required = false) String encodingType,
            @RequestParam(name = "fetch-owner", required = false) String fetchOwner,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "READ");
        int normalizedMaxKeys = normalizeMaxKeys(maxKeys);
        boolean urlEncode = useUrlEncoding(encodingType);
        boolean includeOwner = useFetchOwner(fetchOwner);
        StoredObjectPage page = objectService.list(
                bucketName,
                prefix,
                delimiter,
                "",
                null,
                marker,
                normalizedMaxKeys,
                user
        );
        auditLogService.record("S3_OBJECT_LIST", user.loginId(), "BUCKET", bucketName, "SUCCESS", "S3-style object list read", request);
        dataFlowMonitoringService.recordList(bucketName, user.loginId(), "S3");
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(listObjectsV1Xml(bucketName, prefix, delimiter, marker, normalizedMaxKeys, urlEncode, includeOwner, user, page));
    }

    @GetMapping(value = {"", "/"}, params = "uploads", produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> listMultipartUploads(
            @PathVariable("bucketName") String bucketName,
            @RequestParam(name = "prefix", required = false) String prefix,
            @RequestParam(name = "key-marker", required = false) String keyMarker,
            @RequestParam(name = "upload-id-marker", required = false) String uploadIdMarker,
            @RequestParam(name = "max-uploads", required = false) Integer maxUploads,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "WRITE");
        MultipartUploadListResponse response = objectService.listActiveMultipartUploads(
                bucketName,
                prefix,
                keyMarker,
                uploadIdMarker,
                normalizeMaxUploads(maxUploads),
                user
        );
        auditLogService.record("S3_OBJECT_MULTIPART_UPLOADS_LIST", user.loginId(), "BUCKET", response.bucketName(), "SUCCESS", "S3-style multipart uploads listed", request);
        dataFlowMonitoringService.recordList(bucketName, user.loginId(), "S3");
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(listMultipartUploadsXml(response));
    }

    @GetMapping(value = "/{*objectKey}", params = "tagging", produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> getObjectTagging(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "READ");
        ObjectMetadataDetail metadata = objectService.metadata(bucketName, objectKey, user);
        auditLogService.record("S3_OBJECT_TAGGING_GET", user.loginId(), "OBJECT", bucketName + "/" + metadata.key(), "SUCCESS", "S3-style object tags read", request);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(taggingXml(metadata.tags()));
    }

    @PutMapping(value = "/{*objectKey}", params = "tagging", consumes = {MediaType.APPLICATION_XML_VALUE, MediaType.TEXT_XML_VALUE})
    public ResponseEntity<Void> putObjectTagging(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) throws IOException {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "WRITE");
        StoredObjectRecord object = objectService.updateTags(bucketName, objectKey, tagsFromTaggingXml(requestBody(request)), user);
        auditLogService.record("S3_OBJECT_TAGGING_PUT", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "S3-style object tags updated", request);
        return ResponseEntity.ok()
                .header("x-amz-tagging-count", String.valueOf(object.tags().size()))
                .build();
    }

    @DeleteMapping(value = "/{*objectKey}", params = "tagging")
    public ResponseEntity<Void> deleteObjectTagging(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "WRITE");
        StoredObjectRecord object = objectService.updateTags(bucketName, objectKey, "", user);
        auditLogService.record("S3_OBJECT_TAGGING_DELETE", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "S3-style object tags deleted", request);
        return ResponseEntity.noContent().build();
    }

    @PostMapping(value = {"", "/"}, params = "delete", consumes = MediaType.ALL_VALUE, produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> deleteObjects(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) throws IOException {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "DELETE");
        DeleteObjectsRequest deleteRequest = deleteObjectsFromXml(requestBody(request, true));
        List<String> deletedKeys = new ArrayList<>();
        List<DeleteObjectError> errors = new ArrayList<>();
        for (String objectKey : deleteRequest.keys()) {
            try {
                StoredObjectRecord object = objectService.delete(bucketName, objectKey, user);
                deletedKeys.add(object.key());
            } catch (ApiException exception) {
                if (exception.code() != ApiErrorCode.NOT_FOUND || !exception.getMessage().toLowerCase().contains("object")) {
                    errors.add(new DeleteObjectError(
                            objectKey,
                            S3ErrorCodeMapper.codeFor(exception.code(), exception.getMessage()),
                            exception.getMessage()
                    ));
                    continue;
                }
                deletedKeys.add(objectKey);
            }
        }
        auditLogService.record("S3_OBJECT_DELETE_MULTI", user.loginId(), "BUCKET", bucketName, "SUCCESS", "S3-style multi-object delete", request);
        deletedKeys.forEach(key -> dataFlowMonitoringService.recordDelete(bucketName, key, user.loginId(), "S3"));
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(deleteResultXml(deleteRequest.quiet() ? List.of() : deletedKeys, errors));
    }

    @PostMapping(value = "/{*objectKey}", params = "uploads", produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> createMultipartUpload(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "WRITE");
        MultipartUploadCreateResponse response = objectService.createS3MultipartUpload(
                bucketName,
                new MultipartUploadCreateRequest(
                        objectKey,
                        contentType(request),
                        optionalLongHeader(request, OSMU_MULTIPART_SIZE_HEADER, AWS_META_OSMU_SIZE_HEADER),
                        optionalLongHeader(request, OSMU_MULTIPART_PART_SIZE_HEADER, AWS_META_OSMU_PART_SIZE_HEADER),
                        optionalIntHeader(request, OSMU_MULTIPART_EXPIRES_HEADER),
                        tags(request)
                ),
                user
        );
        auditLogService.record("S3_OBJECT_MULTIPART_CREATE", user.loginId(), "OBJECT", bucketName + "/" + response.key(), "SUCCESS", "S3-style multipart upload created", request);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(initiateMultipartUploadResultXml(bucketName, response.key(), response.uploadId()));
    }

    @PutMapping(value = "/{*objectKey}", params = {"partNumber", "uploadId"}, consumes = MediaType.ALL_VALUE)
    public ResponseEntity<Void> uploadMultipartPart(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            @RequestParam("partNumber") int partNumber,
            @RequestParam("uploadId") String uploadId,
            HttpServletRequest request
    ) throws IOException {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "WRITE");
        RequestBodyContent requestContent = requestBodyContent(request, "multipart part upload");
        long contentLength = requestContent.contentLength();
        MultipartUploadUploadedPart part;
        ChecksumValidation checksumValidation = requestBodyChecksumValidation(request, requestContent);
        try (S3ChecksumValidatingInputStream content = new S3ChecksumValidatingInputStream(
                requestContent.inputStream(),
                contentLength,
                request.getHeader(AWS_CONTENT_MD5_HEADER),
                payloadHashValidator(request),
                checksumValidation.validators()
        )) {
            part = objectService.uploadMultipartPart(bucketName, objectKey, uploadId, partNumber, content, contentLength, user);
            content.finish();
        }
        auditLogService.record("S3_OBJECT_MULTIPART_PART_PUT", user.loginId(), "OBJECT", bucketName + "/" + objectKey, "SUCCESS", "S3-style multipart part uploaded", request);
        ResponseEntity.BodyBuilder builder = ResponseEntity.ok();
        if (part.etag() != null && !part.etag().isBlank()) {
            builder.eTag(quoted(unquote(part.etag())));
        }
        checksumValidation.responseHeader().apply(builder);
        return builder.build();
    }

    @GetMapping(value = "/{*objectKey}", params = "uploadId", produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> listMultipartUploadParts(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            @RequestParam("uploadId") String uploadId,
            @RequestParam(name = "max-parts", required = false) Integer maxParts,
            @RequestParam(name = "part-number-marker", required = false) Integer partNumberMarker,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "WRITE");
        int normalizedMaxParts = normalizeMaxParts(maxParts);
        int normalizedPartNumberMarker = normalizePartNumberMarker(partNumberMarker);
        MultipartUploadPartsResponse response = objectService.listMultipartUploadParts(
                bucketName,
                new MultipartUploadPartsRequest(uploadId, objectKey),
                user
        );
        MultipartUploadPartsPage page = multipartUploadPartsPage(
                response,
                normalizedMaxParts,
                normalizedPartNumberMarker
        );
        auditLogService.record("S3_OBJECT_MULTIPART_PARTS_LIST", user.loginId(), "OBJECT", bucketName + "/" + response.key(), "SUCCESS", "S3-style multipart parts listed", request);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(listMultipartUploadPartsXml(bucketName, response, page));
    }

    @PostMapping(value = "/{*objectKey}", params = "uploadId", consumes = {MediaType.APPLICATION_XML_VALUE, MediaType.TEXT_XML_VALUE}, produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> completeMultipartUpload(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            @RequestParam("uploadId") String uploadId,
            HttpServletRequest request
    ) throws IOException {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "WRITE");
        ChecksumResponseHeader checksumResponseHeader = checksumResponseHeader(request);
        StoredObjectRecord object = objectService.completeMultipartUpload(
                bucketName,
                new MultipartUploadCompleteRequest(uploadId, objectKey, completedPartsFromXml(requestBody(request))),
                user,
                checksumResponseHeader.asMap()
        );
        auditLogService.record("S3_OBJECT_MULTIPART_COMPLETE", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "S3-style multipart upload completed", request);
        dataFlowMonitoringService.recordUpload(bucketName, object.key(), object.sizeBytes(), user.loginId(), "S3");
        ResponseEntity.BodyBuilder builder = ResponseEntity.ok().contentType(MediaType.APPLICATION_XML);
        if (!object.etag().isBlank()) {
            builder.eTag(etag(object));
        }
        object.checksums().forEach(builder::header);
        return builder.body(completeMultipartUploadResultXml(bucketName, object));
    }

    @DeleteMapping(value = "/{*objectKey}", params = "uploadId")
    public ResponseEntity<Void> abortMultipartUpload(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            @RequestParam("uploadId") String uploadId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "WRITE");
        objectService.abortMultipartUpload(bucketName, new MultipartUploadAbortRequest(uploadId, objectKey), user);
        auditLogService.record("S3_OBJECT_MULTIPART_ABORT", user.loginId(), "OBJECT", bucketName + "/" + objectKey, "SUCCESS", "S3-style multipart upload aborted", request);
        dataFlowMonitoringService.recordCancel("upload", bucketName, objectKey, user.loginId(), "S3");
        return ResponseEntity.noContent().build();
    }

    @PutMapping(value = "/{*objectKey}", params = {"!tagging", "!partNumber", "!uploadId"}, consumes = MediaType.ALL_VALUE)
    public ResponseEntity<?> putObject(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) throws IOException {
        String copySourceHeader = request.getHeader("x-amz-copy-source");
        if (copySourceHeader != null && !copySourceHeader.isBlank()) {
            return copyObject(bucketName, objectKey, copySourceHeader, request);
        }
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "WRITE");
        RequestBodyContent requestContent = requestBodyContent(request, "S3 object upload");
        long contentLength = requestContent.contentLength();
        StoredObjectRecord object;
        ChecksumValidation checksumValidation = requestBodyChecksumValidation(request, requestContent);
        try (S3ChecksumValidatingInputStream content = new S3ChecksumValidatingInputStream(
                requestContent.inputStream(),
                contentLength,
                request.getHeader(AWS_CONTENT_MD5_HEADER),
                payloadHashValidator(request),
                checksumValidation.validators()
        )) {
            object = objectService.upload(
                    bucketName,
                    objectKey,
                    tags(request),
                    content,
                    contentLength,
                    contentType(request),
                    user,
                    checksumValidation.values(),
                    userMetadata(request)
            );
            content.finish();
            String calculatedMd5 = content.md5Hex();
            auditLogService.record("S3_OBJECT_PUT", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "S3-style object uploaded", request);
            dataFlowMonitoringService.recordUpload(bucketName, object.key(), object.sizeBytes(), user.loginId(), "S3");
            ResponseEntity.BodyBuilder builder = ResponseEntity.ok()
                    .eTag(quoted(object.etag().isBlank() ? calculatedMd5 : object.etag()))
                    .header("x-amz-tagging-count", String.valueOf(object.tags().size()));
            checksumValidation.responseHeader().apply(builder);
            return builder.build();
        } catch (IOException | RuntimeException exception) {
            dataFlowMonitoringService.recordFailure("upload", bucketName, objectKey, user.loginId(), exception.getMessage(), "S3");
            throw exception;
        }
    }

    private ResponseEntity<String> copyObject(
            String targetBucketName,
            String targetObjectKey,
            String copySourceHeader,
            HttpServletRequest request
    ) throws IOException {
        CopySource copySource = copySource(copySourceHeader);
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, targetBucketName, "WRITE");
        s3RequestAuthService.currentUser(request, copySource.bucketName(), "READ");
        assertCopyTargetPreconditions(request, targetBucketName, targetObjectKey, user);
        String checksumHeaderName = copyObjectChecksumHeader(request);
        String metadataDirective = copyDirective(request.getHeader(AWS_METADATA_DIRECTIVE_HEADER), AWS_METADATA_DIRECTIVE_HEADER);
        String taggingDirective = copyDirective(request.getHeader(AWS_TAGGING_DIRECTIVE_HEADER), AWS_TAGGING_DIRECTIVE_HEADER);
        StoredObjectStream sourceObject = copySourceObject(copySource, user);
        String copyTags = "REPLACE".equals(taggingDirective) ? tags(request) : tagsHeader(sourceObject.metadata());
        String copyContentType = "REPLACE".equals(metadataDirective) ? contentType(request) : sourceObject.metadata().contentType();
        Map<String, String> copyUserMetadata = "REPLACE".equals(metadataDirective)
                ? userMetadata(request)
                : sourceObject.metadata().userMetadata();
        MessageDigest md5 = messageDigest("MD5");
        StoredObjectRecord copiedObject;
        try (InputStream sourceContent = sourceObject.content()) {
            assertCopySourcePreconditions(request, sourceObject.metadata());
            Map<String, String> copyChecksums = checksumHeaderName == null
                    ? sourceObject.metadata().checksums()
                    : Map.of(checksumHeaderName, copyObjectChecksum(copySource, user, checksumHeaderName));
            try (DigestInputStream content = new DigestInputStream(sourceContent, md5)) {
                copiedObject = objectService.upload(
                        targetBucketName,
                        targetObjectKey,
                        copyTags,
                        content,
                        sourceObject.metadata().sizeBytes(),
                        copyContentType,
                        user,
                        copyChecksums,
                        copyUserMetadata
                );
            }
        }
        String etag = HexFormat.of().formatHex(md5.digest());
        auditLogService.record("S3_OBJECT_COPY", user.loginId(), "OBJECT", targetBucketName + "/" + copiedObject.key(), "SUCCESS", "S3-style object copied", request);
        dataFlowMonitoringService.recordCopy(targetBucketName, copiedObject.key(), copiedObject.sizeBytes(), user.loginId(), "S3-COPY");
        ResponseEntity.BodyBuilder builder = ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .eTag(quoted(etag));
        copiedObject.checksums().forEach(builder::header);
        return builder.body(copyObjectResultXml(copiedObject, etag));
    }

    @GetMapping(value = "/{*objectKey}", params = {"!tagging", "!uploadId"})
    public ResponseEntity<StreamingResponseBody> getObject(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "READ");
        StoredObjectStream object = objectService.downloadStream(bucketName, objectKey, user);
        auditLogService.record("S3_OBJECT_GET", user.loginId(), "OBJECT", bucketName + "/" + object.metadata().key(), "SUCCESS", "S3-style object download started", request);
        ResponseEntity<StreamingResponseBody> conditionalResponse = conditionalGetResponse(request, object);
        if (conditionalResponse != null) {
            closeQuietly(object.content());
            return conditionalResponse;
        }
        ByteRange range = byteRange(request, object.metadata());
        long responseBytes = range == null ? object.metadata().sizeBytes() : range.length();
        dataFlowMonitoringService.recordDownload(bucketName, object.metadata().key(), responseBytes, user.loginId(), "S3");
        StreamingResponseBody body = outputStream -> {
            try (InputStream inputStream = object.content()) {
                if (range == null) {
                    inputStream.transferTo(outputStream);
                } else {
                    skipFully(inputStream, range.start());
                    transferRange(inputStream, outputStream, range.length());
                }
            } catch (IOException | RuntimeException exception) {
                dataFlowMonitoringService.recordFailure("download", bucketName, object.metadata().key(), user.loginId(), exception.getMessage(), "S3");
                throw exception;
            }
        };
        if (range != null) {
            return objectHeaders(ResponseEntity.status(206), object.metadata())
                    .contentLength(range.length())
                    .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                    .header(HttpHeaders.CONTENT_RANGE, "bytes %d-%d/%d".formatted(
                            range.start(),
                            range.end(),
                            object.metadata().sizeBytes()
                    ))
                    .body(body);
        }
        return objectHeaders(ResponseEntity.ok(), object.metadata()).body(body);
    }

    @RequestMapping(value = "/{*objectKey}", params = "!tagging", method = org.springframework.web.bind.annotation.RequestMethod.HEAD)
    public ResponseEntity<Void> headObject(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "READ");
        ObjectMetadataDetail metadata = objectService.metadata(bucketName, objectKey, user);
        auditLogService.record("S3_OBJECT_HEAD", user.loginId(), "OBJECT", bucketName + "/" + metadata.key(), "SUCCESS", "S3-style object metadata read", request);
        ResponseEntity<Void> conditionalResponse = conditionalHeadResponse(request, metadata);
        if (conditionalResponse != null) {
            return conditionalResponse;
        }
        ResponseEntity.BodyBuilder builder = ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(metadata.contentType()))
                .contentLength(metadata.sizeBytes())
                .lastModified(metadata.lastModifiedAt().toInstant().toEpochMilli())
                .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                .header("x-amz-tagging-count", String.valueOf(metadata.tags().size()));
        if (!metadata.etag().isBlank()) {
            builder.eTag(quoted(metadata.etag()));
        }
        metadata.checksums().forEach(builder::header);
        applyUserMetadataHeaders(builder, metadata.userMetadata());
        return builder.build();
    }

    @DeleteMapping(value = "/{*objectKey}", params = {"!tagging", "!uploadId"})
    public ResponseEntity<Void> deleteObject(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUser(request, bucketName, "DELETE");
        StoredObjectRecord object = objectService.delete(bucketName, objectKey, user);
        auditLogService.record("S3_OBJECT_DELETE", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "S3-style object moved to trash", request);
        dataFlowMonitoringService.recordDelete(bucketName, object.key(), user.loginId(), "S3");
        return ResponseEntity.noContent().build();
    }

    private ResponseEntity.BodyBuilder objectHeaders(ResponseEntity.BodyBuilder builder, StoredObjectRecord metadata) {
        ResponseEntity.BodyBuilder result = builder
                .contentType(MediaType.parseMediaType(metadata.contentType()))
                .contentLength(metadata.sizeBytes())
                .lastModified(metadata.lastModifiedAt().toInstant().toEpochMilli())
                .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                .header("x-amz-tagging-count", String.valueOf(metadata.tags().size()))
                .header("X-OSMU-Tags", tagsHeader(metadata));
        if (!metadata.etag().isBlank()) {
            result.eTag(etag(metadata));
        }
        metadata.checksums().forEach(result::header);
        applyUserMetadataHeaders(result, metadata.userMetadata());
        return result;
    }

    private ResponseEntity<StreamingResponseBody> conditionalGetResponse(HttpServletRequest request, StoredObjectStream object) {
        ConditionalDecision decision = conditionalDecision(
                request,
                object.metadata().etag(),
                object.metadata().lastModifiedAt().toInstant()
        );
        if (decision == ConditionalDecision.NONE) {
            return null;
        }
        ResponseEntity.BodyBuilder builder = objectHeadersWithoutBody(ResponseEntity.status(decision.status()), object.metadata());
        return builder.body(null);
    }

    private ResponseEntity.BodyBuilder objectHeadersWithoutBody(ResponseEntity.BodyBuilder builder, StoredObjectRecord metadata) {
        ResponseEntity.BodyBuilder result = builder
                .lastModified(metadata.lastModifiedAt().toInstant().toEpochMilli())
                .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                .header("x-amz-tagging-count", String.valueOf(metadata.tags().size()))
                .header("X-OSMU-Tags", tagsHeader(metadata));
        if (!metadata.etag().isBlank()) {
            result.eTag(etag(metadata));
        }
        metadata.checksums().forEach(result::header);
        applyUserMetadataHeaders(result, metadata.userMetadata());
        return result;
    }

    private ResponseEntity<Void> conditionalHeadResponse(HttpServletRequest request, ObjectMetadataDetail metadata) {
        ConditionalDecision decision = conditionalDecision(request, metadata.etag(), metadata.lastModifiedAt().toInstant());
        if (decision == ConditionalDecision.NONE) {
            return null;
        }
        ResponseEntity.BodyBuilder builder = ResponseEntity.status(decision.status())
                .lastModified(metadata.lastModifiedAt().toInstant().toEpochMilli())
                .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                .header("x-amz-tagging-count", String.valueOf(metadata.tags().size()));
        if (!metadata.etag().isBlank()) {
            builder.eTag(quoted(metadata.etag()));
        }
        metadata.checksums().forEach(builder::header);
        applyUserMetadataHeaders(builder, metadata.userMetadata());
        return builder.build();
    }

    private ConditionalDecision conditionalDecision(HttpServletRequest request, String rawEtag, Instant lastModifiedAt) {
        boolean etagAvailable = rawEtag != null && !rawEtag.isBlank();
        Instant roundedLastModified = roundedLastModified(lastModifiedAt);
        String ifMatch = request.getHeader(HttpHeaders.IF_MATCH);
        boolean ifMatchPresent = etagAvailable && ifMatch != null && !ifMatch.isBlank();
        boolean ifMatchSatisfied = ifMatchPresent && matchesEtag(ifMatch, rawEtag);
        Instant ifUnmodifiedSince = httpDate(request.getHeader(HttpHeaders.IF_UNMODIFIED_SINCE));
        if (ifMatchPresent && !ifMatchSatisfied) {
            return ConditionalDecision.PRECONDITION_FAILED;
        }
        if (ifUnmodifiedSince != null && roundedLastModified.isAfter(ifUnmodifiedSince)) {
            return ifMatchSatisfied ? ConditionalDecision.NONE : ConditionalDecision.PRECONDITION_FAILED;
        }
        String ifNoneMatch = request.getHeader(HttpHeaders.IF_NONE_MATCH);
        if (etagAvailable && ifNoneMatch != null && !ifNoneMatch.isBlank()) {
            return matchesEtag(ifNoneMatch, rawEtag) ? ConditionalDecision.NOT_MODIFIED : ConditionalDecision.NONE;
        }
        Instant ifModifiedSince = httpDate(request.getHeader(HttpHeaders.IF_MODIFIED_SINCE));
        if (ifModifiedSince != null && !roundedLastModified.isAfter(ifModifiedSince)) {
            return ConditionalDecision.NOT_MODIFIED;
        }
        return ConditionalDecision.NONE;
    }

    private void assertCopySourcePreconditions(HttpServletRequest request, StoredObjectRecord sourceObject) {
        String ifMatch = request.getHeader(AWS_COPY_SOURCE_IF_MATCH_HEADER);
        boolean ifMatchPresent = ifMatch != null && !ifMatch.isBlank();
        boolean ifMatchSatisfied = ifMatchPresent && matchesEtag(ifMatch, sourceObject.etag());
        if (ifMatchPresent && !ifMatchSatisfied) {
            throw copySourcePreconditionFailed();
        }
        Instant roundedLastModified = roundedLastModified(sourceObject.lastModifiedAt().toInstant());
        Instant ifUnmodifiedSince = httpDate(request.getHeader(AWS_COPY_SOURCE_IF_UNMODIFIED_SINCE_HEADER));
        if (ifUnmodifiedSince != null && roundedLastModified.isAfter(ifUnmodifiedSince) && !ifMatchSatisfied) {
            throw copySourcePreconditionFailed();
        }
        String ifNoneMatch = request.getHeader(AWS_COPY_SOURCE_IF_NONE_MATCH_HEADER);
        if (ifNoneMatch != null && !ifNoneMatch.isBlank() && matchesEtag(ifNoneMatch, sourceObject.etag())) {
            throw copySourcePreconditionFailed();
        }
        Instant ifModifiedSince = httpDate(request.getHeader(AWS_COPY_SOURCE_IF_MODIFIED_SINCE_HEADER));
        if (ifModifiedSince != null && !roundedLastModified.isAfter(ifModifiedSince)) {
            throw copySourcePreconditionFailed();
        }
    }

    private void assertCopyTargetPreconditions(
            HttpServletRequest request,
            String targetBucketName,
            String targetObjectKey,
            AuthenticatedUser user
    ) {
        String ifMatch = request.getHeader(HttpHeaders.IF_MATCH);
        String ifNoneMatch = request.getHeader(HttpHeaders.IF_NONE_MATCH);
        if ((ifMatch == null || ifMatch.isBlank()) && (ifNoneMatch == null || ifNoneMatch.isBlank())) {
            return;
        }
        StoredObjectRecord targetObject = objectService.activeMetadataForWrite(targetBucketName, targetObjectKey, user).orElse(null);
        if (ifMatch != null && !ifMatch.isBlank()) {
            if (targetObject == null || !matchesEtag(ifMatch, targetObject.etag())) {
                throw copySourcePreconditionFailed();
            }
        }
        if (targetObject != null && ifNoneMatch != null && !ifNoneMatch.isBlank() && matchesEtag(ifNoneMatch, targetObject.etag())) {
            throw copySourcePreconditionFailed();
        }
    }

    private ApiException copySourcePreconditionFailed() {
        return new ApiException(
                ApiErrorCode.PRECONDITION_FAILED,
                "At least one of the preconditions you specified did not hold."
        );
    }

    private Instant roundedLastModified(Instant lastModifiedAt) {
        return (lastModifiedAt == null ? Instant.EPOCH : lastModifiedAt).truncatedTo(ChronoUnit.SECONDS);
    }

    private Instant httpDate(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return DateTimeFormatter.RFC_1123_DATE_TIME.parse(value, Instant::from);
        } catch (DateTimeParseException exception) {
            return null;
        }
    }

    private boolean matchesEtag(String candidates, String rawEtag) {
        String unquotedEtag = unquote(rawEtag);
        for (String candidate : candidates.split(",")) {
            String normalized = candidate.trim();
            if ("*".equals(normalized) || unquote(normalized).equals(unquotedEtag)) {
                return true;
            }
        }
        return false;
    }

    private String unquote(String value) {
        String normalized = value == null ? "" : value.trim();
        if (normalized.startsWith("W/")) {
            normalized = normalized.substring(2).trim();
        }
        if (normalized.length() >= 2 && normalized.startsWith("\"") && normalized.endsWith("\"")) {
            return normalized.substring(1, normalized.length() - 1);
        }
        return normalized;
    }

    private void closeQuietly(InputStream inputStream) {
        try {
            inputStream.close();
        } catch (IOException ignored) {
        }
    }

    private String tags(HttpServletRequest request) {
        String osmuTags = request.getHeader(OSMU_TAGS_HEADER);
        if (osmuTags != null && !osmuTags.isBlank()) {
            return osmuTags;
        }
        String awsTags = request.getHeader(AWS_TAGGING_HEADER);
        if (awsTags == null || awsTags.isBlank()) {
            return "";
        }
        return java.util.Arrays.stream(awsTags.split("&"))
                .map(String::trim)
                .filter(pair -> !pair.isBlank())
                .map(this::decodeTagPair)
                .collect(Collectors.joining(","));
    }

    private String decodeTagPair(String pair) {
        int separatorIndex = pair.indexOf('=');
        if (separatorIndex <= 0 || separatorIndex == pair.length() - 1) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "x-amz-tagging must use key=value pairs.");
        }
        return decode(pair.substring(0, separatorIndex)) + "=" + decode(pair.substring(separatorIndex + 1));
    }

    private String decode(String value) {
        return URLDecoder.decode(value, StandardCharsets.UTF_8);
    }

    private CopySource copySource(String rawCopySource) {
        String source = rawCopySource == null ? "" : rawCopySource.trim();
        if (source.startsWith("/")) {
            source = source.substring(1);
        }
        String versionId = null;
        int queryIndex = source.indexOf('?');
        if (queryIndex >= 0) {
            versionId = copySourceVersionId(source.substring(queryIndex + 1));
            source = source.substring(0, queryIndex);
        }
        int separatorIndex = source.indexOf('/');
        if (separatorIndex <= 0 || separatorIndex == source.length() - 1) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "x-amz-copy-source must use /bucket/key.");
        }
        String sourceBucketName = decode(source.substring(0, separatorIndex));
        String sourceObjectKey = decode(source.substring(separatorIndex + 1));
        if (sourceBucketName.isBlank() || sourceObjectKey.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "x-amz-copy-source must use /bucket/key.");
        }
        return new CopySource(sourceBucketName, sourceObjectKey, versionId);
    }

    private String copySourceVersionId(String query) {
        String versionId = null;
        for (String pair : query.split("&")) {
            if (pair.isBlank()) {
                continue;
            }
            int separatorIndex = pair.indexOf('=');
            String name = separatorIndex < 0 ? decode(pair) : decode(pair.substring(0, separatorIndex));
            String value = separatorIndex < 0 ? "" : decode(pair.substring(separatorIndex + 1));
            if (!"versionId".equals(name)) {
                throw new ApiException(
                        ApiErrorCode.VALIDATION_ERROR,
                        "Only x-amz-copy-source versionId query is supported."
                );
            }
            if (versionId != null) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "x-amz-copy-source versionId must be specified once.");
            }
            versionId = value;
        }
        if (versionId == null || versionId.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "x-amz-copy-source versionId is required.");
        }
        return versionId;
    }

    private StoredObjectStream copySourceObject(CopySource copySource, AuthenticatedUser user) {
        if (copySource.versionId() == null || copySource.versionId().isBlank()) {
            return objectService.downloadStream(copySource.bucketName(), copySource.objectKey(), user);
        }
        return objectService.downloadVersion(copySource.bucketName(), copySource.objectKey(), copySource.versionId(), user);
    }

    private String copyObjectChecksumHeader(HttpServletRequest request) {
        String rawAlgorithm = request.getHeader(AWS_CHECKSUM_ALGORITHM_HEADER);
        if (rawAlgorithm == null || rawAlgorithm.isBlank()) {
            return null;
        }
        if (rawAlgorithm.contains(",")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, AWS_CHECKSUM_ALGORITHM_HEADER + " must specify one checksum algorithm.");
        }
        return switch (rawAlgorithm.trim().toUpperCase(Locale.ROOT)) {
            case "SHA256" -> AWS_CHECKSUM_SHA256_HEADER;
            case "SHA1" -> AWS_CHECKSUM_SHA1_HEADER;
            case "CRC32" -> AWS_CHECKSUM_CRC32_HEADER;
            case "CRC32C" -> AWS_CHECKSUM_CRC32C_HEADER;
            case "CRC64NVME" -> AWS_CHECKSUM_CRC64NVME_HEADER;
            default -> throw new ApiException(ApiErrorCode.VALIDATION_ERROR, AWS_CHECKSUM_ALGORITHM_HEADER + " is not supported.");
        };
    }

    private String copyObjectChecksum(CopySource copySource, AuthenticatedUser user, String headerName) throws IOException {
        try (InputStream content = copySourceObject(copySource, user).content()) {
            return Base64.getEncoder().encodeToString(objectChecksum(headerName, content));
        }
    }

    private byte[] objectChecksum(String headerName, InputStream content) throws IOException {
        return switch (headerName) {
            case AWS_CHECKSUM_SHA256_HEADER -> digestObject("SHA-256", content);
            case AWS_CHECKSUM_SHA1_HEADER -> digestObject("SHA-1", content);
            case AWS_CHECKSUM_CRC32_HEADER -> crcObject(new CRC32(), content);
            case AWS_CHECKSUM_CRC32C_HEADER -> crcObject(new CRC32C(), content);
            case AWS_CHECKSUM_CRC64NVME_HEADER -> crcObject(
                    new Crc64NvmeChecksum(),
                    Crc64NvmeChecksum.DIGEST_LENGTH_BYTES,
                    content
            );
            default -> throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " is not supported.");
        };
    }

    private byte[] digestObject(String algorithm, InputStream content) throws IOException {
        MessageDigest digest = messageDigest(algorithm);
        byte[] buffer = new byte[8192];
        int count;
        while ((count = content.read(buffer)) >= 0) {
            digest.update(buffer, 0, count);
        }
        return digest.digest();
    }

    private byte[] crcObject(Checksum checksum, InputStream content) throws IOException {
        return crcObject(checksum, 4, content);
    }

    private byte[] crcObject(Checksum checksum, int digestLength, InputStream content) throws IOException {
        byte[] buffer = new byte[8192];
        int count;
        while ((count = content.read(buffer)) >= 0) {
            checksum.update(buffer, 0, count);
        }
        return BodyChecksumValidator.checksumDigest(checksum.getValue(), digestLength);
    }

    private String copyDirective(String rawDirective, String headerName) {
        if (rawDirective == null || rawDirective.isBlank()) {
            return "COPY";
        }
        String directive = rawDirective.trim().toUpperCase(java.util.Locale.ROOT);
        if (!"COPY".equals(directive) && !"REPLACE".equals(directive)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, headerName + " must be COPY or REPLACE.");
        }
        return directive;
    }

    private String tagsHeader(StoredObjectRecord metadata) {
        return metadata.tags().entrySet().stream()
                .map(entry -> entry.getKey() + "=" + entry.getValue())
                .collect(Collectors.joining(","));
    }

    private Map<String, String> userMetadata(HttpServletRequest request) {
        Map<String, String> metadata = new LinkedHashMap<>();
        Enumeration<String> headerNames = request.getHeaderNames();
        while (headerNames != null && headerNames.hasMoreElements()) {
            String headerName = headerNames.nextElement();
            String normalizedHeaderName = headerName.toLowerCase(Locale.ROOT);
            if (!normalizedHeaderName.startsWith(AWS_USER_METADATA_PREFIX)) {
                continue;
            }
            if (normalizedHeaderName.length() == AWS_USER_METADATA_PREFIX.length()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "x-amz-meta-* metadata name is required.");
            }
            String value = request.getHeader(headerName);
            metadata.put(normalizedHeaderName, value == null ? "" : value);
        }
        return Map.copyOf(metadata);
    }

    private void applyUserMetadataHeaders(ResponseEntity.BodyBuilder builder, Map<String, String> userMetadata) {
        if (userMetadata == null || userMetadata.isEmpty()) {
            return;
        }
        userMetadata.forEach(builder::header);
    }

    private String requestBody(HttpServletRequest request) throws IOException {
        return requestBody(request, false);
    }

    private String requestBody(HttpServletRequest request, boolean validateContentMd5) throws IOException {
        byte[] body = request.getInputStream().readAllBytes();
        if (validateContentMd5) {
            validateContentMd5(request.getHeader(AWS_CONTENT_MD5_HEADER), body);
        }
        return new String(body, StandardCharsets.UTF_8);
    }

    private RequestBodyContent requestBodyContent(HttpServletRequest request, String operation) throws IOException {
        if (isAwsChunkedPayload(request)) {
            long decodedContentLength = requiredNonNegativeLongHeader(request, AWS_DECODED_CONTENT_LENGTH_HEADER);
            AwsChunkedInputStream chunkedInputStream = new AwsChunkedInputStream(
                    request.getInputStream(),
                    decodedContentLength,
                    isAwsStreamingPayload(request),
                    streamingSignatureContext(request)
            );
            return new RequestBodyContent(
                    chunkedInputStream,
                    decodedContentLength,
                    chunkedInputStream
            );
        }
        long contentLength = request.getContentLengthLong();
        if (contentLength < 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Content-Length is required for " + operation + ".");
        }
        return new RequestBodyContent(request.getInputStream(), contentLength, null);
    }

    private boolean isAwsChunkedPayload(HttpServletRequest request) {
        String payloadHash = request.getHeader(AWS_CONTENT_SHA256_HEADER);
        String contentEncoding = request.getHeader(HttpHeaders.CONTENT_ENCODING);
        return payloadHash != null && payloadHash.trim().startsWith(AWS_STREAMING_PAYLOAD_PREFIX)
                || contentEncoding != null && contentEncoding.toLowerCase(java.util.Locale.ROOT).contains(AWS_CHUNKED_CONTENT_ENCODING);
    }

    private boolean isAwsStreamingPayload(HttpServletRequest request) {
        String payloadHash = request.getHeader(AWS_CONTENT_SHA256_HEADER);
        return payloadHash != null && payloadHash.trim().startsWith(AWS_STREAMING_PAYLOAD_PREFIX);
    }

    private S3SignatureV4Verifier.StreamingSignatureContext streamingSignatureContext(HttpServletRequest request) {
        Object context = request.getAttribute(S3SignatureV4Verifier.STREAMING_SIGNATURE_CONTEXT_ATTRIBUTE);
        return context instanceof S3SignatureV4Verifier.StreamingSignatureContext streamingContext
                ? streamingContext
                : null;
    }

    private long requiredLongHeader(HttpServletRequest request, String primaryName, String fallbackName) {
        String rawValue = firstHeader(request, primaryName, fallbackName);
        if (rawValue == null || rawValue.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, primaryName + " header is required.");
        }
        return parsePositiveLong(rawValue, primaryName);
    }

    private long requiredNonNegativeLongHeader(HttpServletRequest request, String name) {
        String rawValue = request.getHeader(name);
        if (rawValue == null || rawValue.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, name + " header is required.");
        }
        return parseNonNegativeLong(rawValue, name);
    }

    private Long optionalLongHeader(HttpServletRequest request, String primaryName, String fallbackName) {
        String rawValue = firstHeader(request, primaryName, fallbackName);
        if (rawValue == null || rawValue.isBlank()) {
            return null;
        }
        return parsePositiveLong(rawValue, primaryName);
    }

    private Integer optionalIntHeader(HttpServletRequest request, String name) {
        String rawValue = request.getHeader(name);
        if (rawValue == null || rawValue.isBlank()) {
            return null;
        }
        long parsed = parsePositiveLong(rawValue, name);
        if (parsed > Integer.MAX_VALUE) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, name + " is too large.");
        }
        return (int) parsed;
    }

    private String firstHeader(HttpServletRequest request, String primaryName, String fallbackName) {
        String value = request.getHeader(primaryName);
        if (value != null && !value.isBlank()) {
            return value;
        }
        return request.getHeader(fallbackName);
    }

    private long parsePositiveLong(String rawValue, String headerName) {
        try {
            long parsed = Long.parseLong(rawValue.trim());
            if (parsed <= 0) {
                throw new NumberFormatException("not positive");
            }
            return parsed;
        } catch (NumberFormatException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, headerName + " must be a positive number.");
        }
    }

    private long parseNonNegativeLong(String rawValue, String headerName) {
        try {
            long parsed = Long.parseLong(rawValue.trim());
            if (parsed < 0) {
                throw new NumberFormatException("negative");
            }
            return parsed;
        } catch (NumberFormatException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, headerName + " must be a non-negative number.");
        }
    }

    private void validateContentMd5(String expectedContentMd5, byte[] body) {
        byte[] expectedDigest = decodeContentMd5(expectedContentMd5);
        if (expectedDigest == null) {
            return;
        }
        byte[] actualDigest = messageDigest("MD5").digest(body);
        if (!MessageDigest.isEqual(expectedDigest, actualDigest)) {
            throw new ApiException(ApiErrorCode.BAD_DIGEST, "Content-MD5 does not match request body.");
        }
    }

    private String tagsFromTaggingXml(String rawXml) {
        if (rawXml == null || rawXml.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Tagging XML is required.");
        }
        try {
            Element root = xmlDocument(rawXml).getDocumentElement();
            NodeList tagNodes = root.getElementsByTagNameNS("*", "Tag");
            Map<String, String> tags = new LinkedHashMap<>();
            for (int i = 0; i < tagNodes.getLength(); i++) {
                Element tag = (Element) tagNodes.item(i);
                tags.put(requiredTagText(tag, "Key"), requiredTagText(tag, "Value"));
            }
            return tags.entrySet().stream()
                    .map(entry -> entry.getKey() + "=" + entry.getValue())
                    .collect(Collectors.joining(","));
        } catch (ParserConfigurationException | IOException | SAXException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid Tagging XML.");
        }
    }

    private List<CompletedMultipartUploadPart> completedPartsFromXml(String rawXml) {
        if (rawXml == null || rawXml.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "CompleteMultipartUpload XML is required.");
        }
        try {
            Element root = xmlDocument(rawXml).getDocumentElement();
            NodeList partNodes = root.getElementsByTagNameNS("*", "Part");
            if (partNodes.getLength() == 0) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "CompleteMultipartUpload requires at least one Part.");
            }
            if (partNodes.getLength() > MAX_MULTIPART_PART_NUMBER) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "CompleteMultipartUpload can contain at most 10000 parts.");
            }
            List<CompletedMultipartUploadPart> parts = new ArrayList<>();
            int lastPartNumber = 0;
            for (int i = 0; i < partNodes.getLength(); i++) {
                Element part = (Element) partNodes.item(i);
                int partNumber = parseMultipartPartNumber(requiredMultipartTagText(part, "PartNumber"));
                if (partNumber <= lastPartNumber) {
                    throw new ApiException(ApiErrorCode.VALIDATION_ERROR,
                            "CompleteMultipartUpload parts must be in ascending PartNumber order without duplicates.");
                }
                lastPartNumber = partNumber;
                String etag = unquote(requiredMultipartTagText(part, "ETag"));
                if (etag.isBlank()) {
                    throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "CompleteMultipartUpload Part ETag is required.");
                }
                Map<String, String> checksums = new LinkedHashMap<>();
                addOptionalChecksum(checksums, part, "ChecksumSHA256", AWS_CHECKSUM_SHA256_HEADER);
                addOptionalChecksum(checksums, part, "ChecksumSHA1", AWS_CHECKSUM_SHA1_HEADER);
                addOptionalChecksum(checksums, part, "ChecksumCRC32", AWS_CHECKSUM_CRC32_HEADER);
                addOptionalChecksum(checksums, part, "ChecksumCRC32C", AWS_CHECKSUM_CRC32C_HEADER);
                addOptionalChecksum(checksums, part, "ChecksumCRC64NVME", AWS_CHECKSUM_CRC64NVME_HEADER);
                parts.add(new CompletedMultipartUploadPart(partNumber, etag, checksums));
            }
            return parts;
        } catch (ParserConfigurationException | IOException | SAXException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid CompleteMultipartUpload XML.");
        }
    }

    private int parseMultipartPartNumber(String rawValue) {
        long partNumber = parsePositiveLong(rawValue, "PartNumber");
        if (partNumber > MAX_MULTIPART_PART_NUMBER) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "PartNumber must be between 1 and 10000.");
        }
        return (int) partNumber;
    }

    private String requiredMultipartTagText(Element parent, String localName) {
        NodeList nodes = parent.getElementsByTagNameNS("*", localName);
        if (nodes.getLength() == 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR,
                    "CompleteMultipartUpload Part requires PartNumber and ETag.");
        }
        return nodes.item(0).getTextContent();
    }

    private void addOptionalChecksum(Map<String, String> checksums, Element part, String xmlName, String headerName) {
        NodeList nodes = part.getElementsByTagNameNS("*", xmlName);
        if (nodes.getLength() == 0) {
            return;
        }
        String value = nodes.item(0).getTextContent();
        if (value != null && !value.isBlank()) {
            checksums.put(headerName, value.trim());
        }
    }

    private String copyObjectResultXml(StoredObjectRecord object, String etag) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("CopyObjectResult");
            xml.writeDefaultNamespace("http://s3.amazonaws.com/doc/2006-03-01/");
            writeElement(xml, "LastModified", object.lastModifiedAt().toInstant().toString());
            writeElement(xml, "ETag", quoted(etag));
            writeChecksumResultElements(xml, object);
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to render S3 copy result XML.");
        }
    }

    private DeleteObjectsRequest deleteObjectsFromXml(String rawXml) {
        if (rawXml == null || rawXml.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Delete XML is required.");
        }
        try {
            Element root = xmlDocument(rawXml).getDocumentElement();
            NodeList objectNodes = root.getElementsByTagNameNS("*", "Object");
            if (objectNodes.getLength() == 0) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Delete XML requires at least one Object.");
            }
            if (objectNodes.getLength() > 1000) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Delete XML can contain at most 1000 objects.");
            }
            List<String> keys = new ArrayList<>();
            for (int i = 0; i < objectNodes.getLength(); i++) {
                String key = requiredTagText((Element) objectNodes.item(i), "Key");
                if (key.isBlank()) {
                    throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Delete XML requires non-empty Key.");
                }
                keys.add(key);
            }
            return new DeleteObjectsRequest(List.copyOf(keys), quietDelete(root));
        } catch (ParserConfigurationException | IOException | SAXException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid Delete XML.");
        }
    }

    private boolean quietDelete(Element root) {
        NodeList quietNodes = root.getElementsByTagNameNS("*", "Quiet");
        if (quietNodes.getLength() == 0) {
            return false;
        }
        String value = quietNodes.item(0).getTextContent();
        if (value == null || value.isBlank()) {
            return false;
        }
        String normalized = value.trim().toLowerCase(java.util.Locale.ROOT);
        if ("true".equals(normalized)) {
            return true;
        }
        if ("false".equals(normalized)) {
            return false;
        }
        throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Delete Quiet must be true or false.");
    }

    private org.w3c.dom.Document xmlDocument(String rawXml)
            throws ParserConfigurationException, IOException, SAXException {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setXIncludeAware(false);
        factory.setExpandEntityReferences(false);
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
        factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
        return factory.newDocumentBuilder().parse(new InputSource(new StringReader(rawXml)));
    }

    private String requiredTagText(Element parent, String localName) {
        NodeList nodes = parent.getElementsByTagNameNS("*", localName);
        if (nodes.getLength() == 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Tagging XML requires Key and Value.");
        }
        return nodes.item(0).getTextContent();
    }

    private String taggingXml(Map<String, String> tags) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("Tagging");
            xml.writeDefaultNamespace("http://s3.amazonaws.com/doc/2006-03-01/");
            xml.writeStartElement("TagSet");
            for (Map.Entry<String, String> tag : tags.entrySet()) {
                xml.writeStartElement("Tag");
                writeElement(xml, "Key", tag.getKey());
                writeElement(xml, "Value", tag.getValue());
                xml.writeEndElement();
            }
            xml.writeEndElement();
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to render S3 tagging XML.");
        }
    }

    private String deleteResultXml(List<String> deletedKeys, List<DeleteObjectError> errors) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("DeleteResult");
            xml.writeDefaultNamespace("http://s3.amazonaws.com/doc/2006-03-01/");
            for (String key : deletedKeys) {
                xml.writeStartElement("Deleted");
                writeElement(xml, "Key", key);
                xml.writeEndElement();
            }
            for (DeleteObjectError error : errors) {
                xml.writeStartElement("Error");
                writeElement(xml, "Key", error.key());
                writeElement(xml, "Code", error.code());
                writeElement(xml, "Message", error.message());
                xml.writeEndElement();
            }
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to render S3 delete result XML.");
        }
    }

    private String initiateMultipartUploadResultXml(String bucketName, String key, String uploadId) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("InitiateMultipartUploadResult");
            xml.writeDefaultNamespace("http://s3.amazonaws.com/doc/2006-03-01/");
            writeElement(xml, "Bucket", bucketName);
            writeElement(xml, "Key", key);
            writeElement(xml, "UploadId", uploadId);
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to render S3 multipart initiate XML.");
        }
    }

    private String listMultipartUploadPartsXml(
            String bucketName,
            MultipartUploadPartsResponse response,
            MultipartUploadPartsPage page
    ) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("ListPartsResult");
            xml.writeDefaultNamespace("http://s3.amazonaws.com/doc/2006-03-01/");
            writeElement(xml, "Bucket", bucketName);
            writeElement(xml, "Key", response.key());
            writeElement(xml, "UploadId", response.uploadId());
            writeElement(xml, "PartNumberMarker", String.valueOf(page.partNumberMarker()));
            writeOptionalElement(xml, "NextPartNumberMarker", page.nextPartNumberMarkerValue());
            writeElement(xml, "MaxParts", String.valueOf(page.maxParts()));
            writeElement(xml, "IsTruncated", String.valueOf(page.isTruncated()));
            for (MultipartUploadUploadedPart part : page.parts()) {
                xml.writeStartElement("Part");
                writeElement(xml, "PartNumber", String.valueOf(part.partNumber()));
                writeElement(xml, "ETag", quoted(unquote(part.etag())));
                writeElement(xml, "Size", String.valueOf(part.sizeBytes()));
                xml.writeEndElement();
            }
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to render S3 multipart parts XML.");
        }
    }

    private String completeMultipartUploadResultXml(String bucketName, StoredObjectRecord object) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("CompleteMultipartUploadResult");
            xml.writeDefaultNamespace("http://s3.amazonaws.com/doc/2006-03-01/");
            writeElement(xml, "Bucket", bucketName);
            writeElement(xml, "Key", object.key());
            writeOptionalElement(xml, "ETag", etag(object));
            writeChecksumResultElements(xml, object);
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to render S3 multipart complete XML.");
        }
    }

    private String s3DeleteErrorCode(ApiErrorCode code, String message) {
        return switch (code) {
            case AUTHENTICATION_REQUIRED, AUTHORIZATION_FAILED -> "AccessDenied";
            case NOT_FOUND -> message != null && (
                    message.toLowerCase(java.util.Locale.ROOT).contains("upload session")
                            || message.toLowerCase(java.util.Locale.ROOT).contains("multipart upload")
            )
                    ? "NoSuchUpload"
                    : message != null && message.toLowerCase(java.util.Locale.ROOT).contains("bucket") ? "NoSuchBucket" : "NoSuchKey";
            case PRECONDITION_FAILED -> "PreconditionFailed";
            case RANGE_NOT_SATISFIABLE -> "InvalidRange";
            case INVALID_DIGEST -> "InvalidDigest";
            case BAD_DIGEST -> "BadDigest";
            case VALIDATION_ERROR -> "InvalidRequest";
            case QUOTA_EXCEEDED -> "EntityTooLarge";
            case CONFLICT -> message != null && message.toLowerCase(java.util.Locale.ROOT).contains("bucket")
                    && message.toLowerCase(java.util.Locale.ROOT).contains("not empty")
                    ? "BucketNotEmpty"
                    : "OperationAborted";
            case STORAGE_ERROR, INTERNAL_ERROR -> "InternalError";
        };
    }

    private String contentType(HttpServletRequest request) {
        String contentType = request.getContentType();
        return contentType == null || contentType.isBlank()
                ? MediaType.APPLICATION_OCTET_STREAM_VALUE
                : contentType;
    }

    private ByteRange byteRange(HttpServletRequest request, StoredObjectRecord metadata) {
        String rangeHeader = request.getHeader(HttpHeaders.RANGE);
        if (rangeHeader == null || rangeHeader.isBlank()) {
            return null;
        }
        if (!ifRangeAllowsRange(request.getHeader(HTTP_IF_RANGE_HEADER), metadata)) {
            return null;
        }
        return byteRange(rangeHeader, metadata.sizeBytes());
    }

    private boolean ifRangeAllowsRange(String ifRange, StoredObjectRecord metadata) {
        if (ifRange == null || ifRange.isBlank()) {
            return true;
        }
        String normalized = ifRange.trim();
        if (normalized.startsWith("\"") || normalized.startsWith("W/")) {
            return metadata.etag() != null
                    && !metadata.etag().isBlank()
                    && matchesEtag(normalized, metadata.etag());
        }
        Instant ifRangeDate = httpDate(normalized);
        return ifRangeDate != null
                && !roundedLastModified(metadata.lastModifiedAt().toInstant()).isAfter(ifRangeDate);
    }

    private ByteRange byteRange(String header, long sizeBytes) {
        if (header == null || header.isBlank()) {
            return null;
        }
        if (!header.startsWith("bytes=") || header.contains(",") || sizeBytes <= 0) {
            throw invalidRange();
        }
        String spec = header.substring("bytes=".length()).trim();
        if (spec.isBlank()) {
            throw invalidRange();
        }
        int separatorIndex = spec.indexOf('-');
        if (separatorIndex < 0) {
            throw invalidRange();
        }
        String rawStart = spec.substring(0, separatorIndex).trim();
        String rawEnd = spec.substring(separatorIndex + 1).trim();
        try {
            if (rawStart.isBlank()) {
                long suffixLength = Long.parseLong(rawEnd);
                if (suffixLength <= 0) {
                    throw invalidRange();
                }
                long start = Math.max(0, sizeBytes - suffixLength);
                return new ByteRange(start, sizeBytes - 1);
            }
            long start = Long.parseLong(rawStart);
            long end = rawEnd.isBlank() ? sizeBytes - 1 : Long.parseLong(rawEnd);
            if (start < 0 || end < start || start >= sizeBytes) {
                throw invalidRange();
            }
            return new ByteRange(start, Math.min(end, sizeBytes - 1));
        } catch (NumberFormatException exception) {
            throw invalidRange();
        }
    }

    private ApiException invalidRange() {
        return new ApiException(ApiErrorCode.RANGE_NOT_SATISFIABLE, "Invalid Range header.");
    }

    private void skipFully(InputStream inputStream, long bytesToSkip) throws IOException {
        long remaining = bytesToSkip;
        while (remaining > 0) {
            long skipped = inputStream.skip(remaining);
            if (skipped <= 0 && inputStream.read() == -1) {
                throw new IOException("Unexpected end of stream while skipping range.");
            }
            remaining -= skipped <= 0 ? 1 : skipped;
        }
    }

    private void transferRange(InputStream inputStream, java.io.OutputStream outputStream, long length) throws IOException {
        byte[] buffer = new byte[8192];
        long remaining = length;
        while (remaining > 0) {
            int read = inputStream.read(buffer, 0, (int) Math.min(buffer.length, remaining));
            if (read < 0) {
                return;
            }
            outputStream.write(buffer, 0, read);
            remaining -= read;
        }
    }

    private int normalizeMaxKeys(Integer maxKeys) {
        if (maxKeys == null) {
            return DEFAULT_MAX_KEYS;
        }
        if (maxKeys < 1 || maxKeys > DEFAULT_MAX_KEYS) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "max-keys must be between 1 and 1000.");
        }
        return maxKeys;
    }

    private int normalizeMaxUploads(Integer maxUploads) {
        if (maxUploads == null) {
            return DEFAULT_MAX_UPLOADS;
        }
        if (maxUploads < 1 || maxUploads > DEFAULT_MAX_UPLOADS) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "max-uploads must be between 1 and 1000.");
        }
        return maxUploads;
    }

    private int normalizeMaxParts(Integer maxParts) {
        if (maxParts == null) {
            return DEFAULT_MAX_PARTS;
        }
        if (maxParts < 1 || maxParts > DEFAULT_MAX_PARTS) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "max-parts must be between 1 and 1000.");
        }
        return maxParts;
    }

    private int normalizePartNumberMarker(Integer partNumberMarker) {
        if (partNumberMarker == null) {
            return 0;
        }
        if (partNumberMarker < 0 || partNumberMarker > MAX_MULTIPART_PART_NUMBER) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "part-number-marker must be between 0 and 10000.");
        }
        return partNumberMarker;
    }

    private MultipartUploadPartsPage multipartUploadPartsPage(
            MultipartUploadPartsResponse response,
            int maxParts,
            int partNumberMarker
    ) {
        List<MultipartUploadUploadedPart> afterMarker = response.parts().stream()
                .filter(part -> part.partNumber() > partNumberMarker)
                .sorted(java.util.Comparator.comparingInt(MultipartUploadUploadedPart::partNumber))
                .toList();
        boolean isTruncated = afterMarker.size() > maxParts;
        List<MultipartUploadUploadedPart> pageParts = afterMarker.stream()
                .limit(maxParts)
                .toList();
        Integer nextPartNumberMarker = isTruncated && !pageParts.isEmpty()
                ? pageParts.get(pageParts.size() - 1).partNumber()
                : null;
        return new MultipartUploadPartsPage(partNumberMarker, maxParts, isTruncated, nextPartNumberMarker, pageParts);
    }

    private boolean useUrlEncoding(String encodingType) {
        if (encodingType == null || encodingType.isBlank()) {
            return false;
        }
        if ("url".equals(encodingType)) {
            return true;
        }
        throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "encoding-type must be url.");
    }

    private boolean useFetchOwner(String fetchOwner) {
        if (fetchOwner == null || fetchOwner.isBlank()) {
            return false;
        }
        if ("true".equalsIgnoreCase(fetchOwner)) {
            return true;
        }
        if ("false".equalsIgnoreCase(fetchOwner)) {
            return false;
        }
        throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "fetch-owner must be true or false.");
    }

    private String listMultipartUploadsXml(MultipartUploadListResponse response) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("ListMultipartUploadsResult");
            xml.writeDefaultNamespace("http://s3.amazonaws.com/doc/2006-03-01/");
            writeElement(xml, "Bucket", response.bucketName());
            writeElement(xml, "KeyMarker", response.keyMarker());
            writeElement(xml, "UploadIdMarker", response.uploadIdMarker());
            writeOptionalElement(xml, "NextKeyMarker", response.nextKeyMarker());
            writeOptionalElement(xml, "NextUploadIdMarker", response.nextUploadIdMarker());
            writeOptionalElement(xml, "Prefix", response.prefix());
            writeElement(xml, "MaxUploads", String.valueOf(response.maxUploads()));
            writeElement(xml, "IsTruncated", String.valueOf(response.truncated()));
            for (MultipartUploadListItem upload : response.uploads()) {
                xml.writeStartElement("Upload");
                writeElement(xml, "Key", upload.key());
                writeElement(xml, "UploadId", upload.uploadId());
                writeElement(xml, "Initiated", upload.initiatedAt().toInstant().toString());
                xml.writeEndElement();
            }
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to render S3 multipart uploads XML.");
        }
    }

    private String listObjectsXml(
            String bucketName,
            String prefix,
            String delimiter,
            String continuationToken,
            int maxKeys,
            boolean urlEncode,
            boolean includeOwner,
            AuthenticatedUser user,
            StoredObjectPage page
    ) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("ListBucketResult");
            xml.writeDefaultNamespace("http://s3.amazonaws.com/doc/2006-03-01/");
            writeElement(xml, "Name", bucketName);
            writeElement(xml, "Prefix", listValue(prefix, urlEncode));
            writeEncodingType(xml, urlEncode);
            writeElement(xml, "KeyCount", String.valueOf(page.items().size() + page.prefixes().size()));
            writeElement(xml, "MaxKeys", String.valueOf(maxKeys));
            writeElement(xml, "IsTruncated", String.valueOf(page.nextCursor() != null));
            writeOptionalListElement(xml, "Delimiter", delimiter, urlEncode);
            writeOptionalListElement(xml, "ContinuationToken", continuationToken, urlEncode);
            writeOptionalListElement(xml, "NextContinuationToken", page.nextCursor(), urlEncode);
            for (StoredObjectRecord object : page.items()) {
                xml.writeStartElement("Contents");
                writeElement(xml, "Key", listValue(object.key(), urlEncode));
                writeElement(xml, "LastModified", object.lastModifiedAt().toInstant().toString());
                writeOptionalElement(xml, "ETag", etag(object));
                writeChecksumAlgorithms(xml, object);
                writeElement(xml, "Size", String.valueOf(object.sizeBytes()));
                writeElement(xml, "StorageClass", "STANDARD");
                writeOptionalOwner(xml, includeOwner, user);
                xml.writeEndElement();
            }
            for (String commonPrefix : page.prefixes()) {
                xml.writeStartElement("CommonPrefixes");
                writeElement(xml, "Prefix", listValue(commonPrefix, urlEncode));
                xml.writeEndElement();
            }
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to render S3 ListObjectsV2 XML.");
        }
    }

    private String listObjectsV1Xml(
            String bucketName,
            String prefix,
            String delimiter,
            String marker,
            int maxKeys,
            boolean urlEncode,
            boolean includeOwner,
            AuthenticatedUser user,
            StoredObjectPage page
    ) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("ListBucketResult");
            xml.writeDefaultNamespace("http://s3.amazonaws.com/doc/2006-03-01/");
            writeElement(xml, "Name", bucketName);
            writeElement(xml, "Prefix", listValue(prefix, urlEncode));
            writeElement(xml, "Marker", listValue(marker, urlEncode));
            writeEncodingType(xml, urlEncode);
            writeOptionalListElement(xml, "NextMarker", page.nextCursor(), urlEncode);
            writeElement(xml, "MaxKeys", String.valueOf(maxKeys));
            writeElement(xml, "IsTruncated", String.valueOf(page.nextCursor() != null));
            writeOptionalListElement(xml, "Delimiter", delimiter, urlEncode);
            for (StoredObjectRecord object : page.items()) {
                xml.writeStartElement("Contents");
                writeElement(xml, "Key", listValue(object.key(), urlEncode));
                writeElement(xml, "LastModified", object.lastModifiedAt().toInstant().toString());
                writeOptionalElement(xml, "ETag", etag(object));
                writeChecksumAlgorithms(xml, object);
                writeElement(xml, "Size", String.valueOf(object.sizeBytes()));
                writeElement(xml, "StorageClass", "STANDARD");
                writeOptionalOwner(xml, includeOwner, user);
                xml.writeEndElement();
            }
            for (String commonPrefix : page.prefixes()) {
                xml.writeStartElement("CommonPrefixes");
                writeElement(xml, "Prefix", listValue(commonPrefix, urlEncode));
                xml.writeEndElement();
            }
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to render S3 ListObjects XML.");
        }
    }

    private void writeEncodingType(XMLStreamWriter xml, boolean urlEncode) throws XMLStreamException {
        if (urlEncode) {
            writeElement(xml, "EncodingType", "url");
        }
    }

    private void writeOptionalOwner(XMLStreamWriter xml, boolean includeOwner, AuthenticatedUser user) throws XMLStreamException {
        if (!includeOwner) {
            return;
        }
        xml.writeStartElement("Owner");
        writeElement(xml, "ID", String.valueOf(user.id()));
        writeElement(xml, "DisplayName", user.loginId());
        xml.writeEndElement();
    }

    private void writeChecksumAlgorithms(XMLStreamWriter xml, StoredObjectRecord object) throws XMLStreamException {
        for (String headerName : object.checksums().keySet()) {
            String algorithm = checksumAlgorithm(headerName);
            if (!algorithm.isBlank()) {
                writeElement(xml, "ChecksumAlgorithm", algorithm);
            }
        }
    }

    private String checksumAlgorithm(String headerName) {
        return switch (headerName == null ? "" : headerName.toLowerCase(java.util.Locale.ROOT)) {
            case AWS_CHECKSUM_SHA256_HEADER -> "SHA256";
            case AWS_CHECKSUM_SHA1_HEADER -> "SHA1";
            case AWS_CHECKSUM_CRC32_HEADER -> "CRC32";
            case AWS_CHECKSUM_CRC32C_HEADER -> "CRC32C";
            case AWS_CHECKSUM_CRC64NVME_HEADER -> "CRC64NVME";
            default -> "";
        };
    }

    private void writeChecksumResultElements(XMLStreamWriter xml, StoredObjectRecord object) throws XMLStreamException {
        for (Map.Entry<String, String> checksum : object.checksums().entrySet()) {
            String elementName = checksumResultElementName(checksum.getKey());
            if (!elementName.isBlank() && checksum.getValue() != null && !checksum.getValue().isBlank()) {
                writeElement(xml, elementName, checksum.getValue());
            }
        }
    }

    private String checksumResultElementName(String headerName) {
        return switch (headerName == null ? "" : headerName.toLowerCase(java.util.Locale.ROOT)) {
            case AWS_CHECKSUM_SHA256_HEADER -> "ChecksumSHA256";
            case AWS_CHECKSUM_SHA1_HEADER -> "ChecksumSHA1";
            case AWS_CHECKSUM_CRC32_HEADER -> "ChecksumCRC32";
            case AWS_CHECKSUM_CRC32C_HEADER -> "ChecksumCRC32C";
            case AWS_CHECKSUM_CRC64NVME_HEADER -> "ChecksumCRC64NVME";
            default -> "";
        };
    }

    private void writeOptionalListElement(XMLStreamWriter xml, String name, String value, boolean urlEncode) throws XMLStreamException {
        if (value == null || value.isBlank()) {
            return;
        }
        writeElement(xml, name, listValue(value, urlEncode));
    }

    private void writeOptionalElement(XMLStreamWriter xml, String name, String value) throws XMLStreamException {
        if (value == null || value.isBlank()) {
            return;
        }
        writeElement(xml, name, value);
    }

    private void writeElement(XMLStreamWriter xml, String name, String value) throws XMLStreamException {
        xml.writeStartElement(name);
        xml.writeCharacters(value == null ? "" : value);
        xml.writeEndElement();
    }

    private String blankIfNull(String value) {
        return value == null ? "" : value;
    }

    private String listValue(String value, boolean urlEncode) {
        String normalized = blankIfNull(value);
        return urlEncode ? s3UrlEncode(normalized) : normalized;
    }

    private String s3UrlEncode(String value) {
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        StringBuilder encoded = new StringBuilder(bytes.length);
        for (byte b : bytes) {
            int ch = b & 0xff;
            if ((ch >= 'A' && ch <= 'Z')
                    || (ch >= 'a' && ch <= 'z')
                    || (ch >= '0' && ch <= '9')
                    || ch == '-' || ch == '_' || ch == '.' || ch == '~') {
                encoded.append((char) ch);
            } else {
                encoded.append('%')
                        .append(Character.toUpperCase(Character.forDigit((ch >>> 4) & 0x0f, 16)))
                        .append(Character.toUpperCase(Character.forDigit(ch & 0x0f, 16)));
            }
        }
        return encoded.toString();
    }

    private String quoted(String value) {
        return "\"" + value + "\"";
    }

    private String etag(StoredObjectRecord object) {
        return object.etag() == null || object.etag().isBlank() ? "" : quoted(object.etag());
    }

    private static MessageDigest messageDigest(String algorithm) {
        try {
            return MessageDigest.getInstance(algorithm);
        } catch (NoSuchAlgorithmException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, algorithm + " digest is unavailable.");
        }
    }

    private static String sha256Hex(byte[] value) {
        return HexFormat.of().formatHex(messageDigest("SHA-256").digest(value));
    }

    private static byte[] hmacSha256(byte[] key, String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            return mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "HMAC-SHA256 is unavailable.");
        }
    }

    private static byte[] decodeContentMd5(String expectedContentMd5) {
        if (expectedContentMd5 == null || expectedContentMd5.isBlank()) {
            return null;
        }
        byte[] decoded;
        try {
            decoded = Base64.getDecoder().decode(expectedContentMd5.trim());
        } catch (IllegalArgumentException exception) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, "Content-MD5 must be a valid base64 MD5 digest.");
        }
        if (decoded.length != 16) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, "Content-MD5 must be a 128-bit MD5 digest.");
        }
        return decoded;
    }

    private ChecksumValidation requestBodyChecksumValidation(HttpServletRequest request, RequestBodyContent requestContent) {
        Map<String, String> checksumValues = new LinkedHashMap<>();
        List<BodyChecksumValidator> validators = new ArrayList<>();
        addMessageDigestChecksum(validators, checksumValues, request, AWS_CHECKSUM_SHA256_HEADER, "SHA-256", 32);
        addMessageDigestChecksum(validators, checksumValues, request, AWS_CHECKSUM_SHA1_HEADER, "SHA-1", 20);
        addCrcChecksum(validators, checksumValues, request, AWS_CHECKSUM_CRC32_HEADER, new CRC32());
        addCrcChecksum(validators, checksumValues, request, AWS_CHECKSUM_CRC32C_HEADER, new CRC32C());
        addCrcChecksum(
                validators,
                checksumValues,
                request,
                AWS_CHECKSUM_CRC64NVME_HEADER,
                new Crc64NvmeChecksum(),
                Crc64NvmeChecksum.DIGEST_LENGTH_BYTES
        );
        String trailerChecksumHeader = requestedTrailerChecksumHeader(request, requestContent);
        if (trailerChecksumHeader != null) {
            addTrailerChecksum(validators, checksumValues, requestContent.chunkedInputStream(), trailerChecksumHeader);
        }
        if (validators.size() > 1) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, "Only one x-amz-checksum-* header is supported.");
        }
        String responseHeaderName = !checksumValues.isEmpty()
                ? checksumValues.keySet().iterator().next()
                : trailerChecksumHeader == null ? "" : trailerChecksumHeader;
        return new ChecksumValidation(
                validators,
                new ChecksumResponseHeader(responseHeaderName, checksumValues),
                checksumValues
        );
    }

    private ChecksumResponseHeader checksumResponseHeader(HttpServletRequest request) {
        for (String headerName : List.of(
                AWS_CHECKSUM_SHA256_HEADER,
                AWS_CHECKSUM_SHA1_HEADER,
                AWS_CHECKSUM_CRC32_HEADER,
                AWS_CHECKSUM_CRC32C_HEADER,
                AWS_CHECKSUM_CRC64NVME_HEADER
        )) {
            String value = request.getHeader(headerName);
            if (value != null && !value.isBlank()) {
                return new ChecksumResponseHeader(headerName, Map.of(headerName, value.trim()));
            }
        }
        return ChecksumResponseHeader.empty();
    }

    private BodyChecksumValidator payloadHashValidator(HttpServletRequest request) {
        String payloadHash = request.getHeader(AWS_CONTENT_SHA256_HEADER);
        if (payloadHash == null || payloadHash.isBlank()) {
            return null;
        }
        String normalized = payloadHash.trim();
        if (AWS_UNSIGNED_PAYLOAD.equals(normalized)) {
            return null;
        }
        if (normalized.startsWith(AWS_STREAMING_PAYLOAD_PREFIX)) {
            return null;
        }
        return BodyChecksumValidator.messageDigest(
                AWS_CONTENT_SHA256_HEADER,
                messageDigest("SHA-256"),
                decodeHexChecksum(AWS_CONTENT_SHA256_HEADER, normalized, 32)
        );
    }

    private void addMessageDigestChecksum(
            List<BodyChecksumValidator> validators,
            Map<String, String> checksumValues,
            HttpServletRequest request,
            String headerName,
            String algorithm,
            int expectedLength
    ) {
        String rawChecksum = request.getHeader(headerName);
        if (rawChecksum == null || rawChecksum.isBlank()) {
            return;
        }
        checksumValues.put(headerName, rawChecksum.trim());
        validators.add(BodyChecksumValidator.messageDigest(
                headerName,
                messageDigest(algorithm),
                decodeChecksum(headerName, rawChecksum, expectedLength)
        ));
    }

    private void addCrcChecksum(
            List<BodyChecksumValidator> validators,
            Map<String, String> checksumValues,
            HttpServletRequest request,
            String headerName,
            Checksum checksum
    ) {
        addCrcChecksum(validators, checksumValues, request, headerName, checksum, 4);
    }

    private void addCrcChecksum(
            List<BodyChecksumValidator> validators,
            Map<String, String> checksumValues,
            HttpServletRequest request,
            String headerName,
            Checksum checksum,
            int expectedLength
    ) {
        String rawChecksum = request.getHeader(headerName);
        if (rawChecksum == null || rawChecksum.isBlank()) {
            return;
        }
        checksumValues.put(headerName, rawChecksum.trim());
        validators.add(BodyChecksumValidator.crc(
                headerName,
                checksum,
                decodeChecksum(headerName, rawChecksum, expectedLength)
        ));
    }

    private String requestedTrailerChecksumHeader(HttpServletRequest request, RequestBodyContent requestContent) {
        String rawTrailer = request.getHeader(AWS_TRAILER_HEADER);
        if (rawTrailer == null || rawTrailer.isBlank()) {
            return null;
        }
        if (requestContent.chunkedInputStream() == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "x-amz-trailer requires aws-chunked request body.");
        }
        List<String> checksumTrailers = new ArrayList<>();
        for (String token : rawTrailer.split(",")) {
            String name = token.trim().toLowerCase(Locale.ROOT);
            if (name.isBlank()) {
                continue;
            }
            if (isSupportedChecksumHeader(name)) {
                checksumTrailers.add(name);
            } else if (name.startsWith("x-amz-checksum-")) {
                throw new ApiException(ApiErrorCode.INVALID_DIGEST, name + " trailer is not supported.");
            }
        }
        if (checksumTrailers.size() > 1) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, "Only one x-amz-checksum-* trailer is supported.");
        }
        return checksumTrailers.isEmpty() ? null : checksumTrailers.get(0);
    }

    private boolean isSupportedChecksumHeader(String headerName) {
        return AWS_CHECKSUM_SHA256_HEADER.equals(headerName)
                || AWS_CHECKSUM_SHA1_HEADER.equals(headerName)
                || AWS_CHECKSUM_CRC32_HEADER.equals(headerName)
                || AWS_CHECKSUM_CRC32C_HEADER.equals(headerName)
                || AWS_CHECKSUM_CRC64NVME_HEADER.equals(headerName);
    }

    private void addTrailerChecksum(
            List<BodyChecksumValidator> validators,
            Map<String, String> checksumValues,
            AwsChunkedInputStream chunkedInputStream,
            String headerName
    ) {
        switch (headerName) {
            case AWS_CHECKSUM_SHA256_HEADER -> validators.add(BodyChecksumValidator.trailerMessageDigest(
                    headerName,
                    messageDigest("SHA-256"),
                    32,
                    chunkedInputStream,
                    checksumValues
            ));
            case AWS_CHECKSUM_SHA1_HEADER -> validators.add(BodyChecksumValidator.trailerMessageDigest(
                    headerName,
                    messageDigest("SHA-1"),
                    20,
                    chunkedInputStream,
                    checksumValues
            ));
            case AWS_CHECKSUM_CRC32_HEADER -> validators.add(BodyChecksumValidator.trailerCrc(
                    headerName,
                    new CRC32(),
                    4,
                    chunkedInputStream,
                    checksumValues
            ));
            case AWS_CHECKSUM_CRC32C_HEADER -> validators.add(BodyChecksumValidator.trailerCrc(
                    headerName,
                    new CRC32C(),
                    4,
                    chunkedInputStream,
                    checksumValues
            ));
            case AWS_CHECKSUM_CRC64NVME_HEADER -> validators.add(BodyChecksumValidator.trailerCrc(
                    headerName,
                    new Crc64NvmeChecksum(),
                    Crc64NvmeChecksum.DIGEST_LENGTH_BYTES,
                    chunkedInputStream,
                    checksumValues
            ));
            default -> throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " trailer is not supported.");
        }
    }

    private static byte[] decodeChecksum(String headerName, String rawChecksum, int expectedLength) {
        byte[] decoded;
        try {
            decoded = Base64.getDecoder().decode(rawChecksum.trim());
        } catch (IllegalArgumentException exception) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " must be a valid base64 checksum.");
        }
        if (decoded.length != expectedLength) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " has invalid checksum length.");
        }
        return decoded;
    }

    private static byte[] decodeHexChecksum(String headerName, String rawChecksum, int expectedLength) {
        if (rawChecksum.length() != expectedLength * 2) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " has invalid checksum length.");
        }
        try {
            return HexFormat.of().parseHex(rawChecksum);
        } catch (IllegalArgumentException exception) {
            throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " must be a valid hex checksum.");
        }
    }

    private record RequestBodyContent(InputStream inputStream, long contentLength, AwsChunkedInputStream chunkedInputStream) {
    }

    private static final class AwsChunkedInputStream extends InputStream {
        private final InputStream input;
        private final long expectedDecodedLength;
        private final boolean requireChunkSignature;
        private final S3SignatureV4Verifier.StreamingSignatureContext signatureContext;
        private byte[] chunk = new byte[0];
        private int offset;
        private boolean finished;
        private long decodedLength;
        private String previousSignature;
        private final Map<String, String> trailers = new LinkedHashMap<>();

        private AwsChunkedInputStream(
                InputStream input,
                long expectedDecodedLength,
                boolean requireChunkSignature,
                S3SignatureV4Verifier.StreamingSignatureContext signatureContext
        ) {
            this.input = input;
            this.expectedDecodedLength = expectedDecodedLength;
            this.requireChunkSignature = requireChunkSignature;
            this.signatureContext = signatureContext;
            this.previousSignature = signatureContext == null ? null : signatureContext.seedSignature();
        }

        @Override
        public int read() throws IOException {
            if (!ensureChunk()) {
                return -1;
            }
            return chunk[offset++] & 0xff;
        }

        @Override
        public int read(byte[] buffer, int bufferOffset, int length) throws IOException {
            if (buffer == null) {
                throw new NullPointerException("buffer");
            }
            if (bufferOffset < 0 || length < 0 || length > buffer.length - bufferOffset) {
                throw new IndexOutOfBoundsException();
            }
            if (length == 0) {
                return 0;
            }
            if (!ensureChunk()) {
                return -1;
            }
            int count = Math.min(length, chunk.length - offset);
            System.arraycopy(chunk, offset, buffer, bufferOffset, count);
            offset += count;
            return count;
        }

        @Override
        public void close() throws IOException {
            input.close();
        }

        private boolean ensureChunk() throws IOException {
            while (!finished && offset >= chunk.length) {
                readNextChunk();
            }
            return !finished || offset < chunk.length;
        }

        private void readNextChunk() throws IOException {
            String header = readAsciiLine();
            while (header != null && header.isEmpty()) {
                header = readAsciiLine();
            }
            if (header == null) {
                throw new IOException("Unexpected end of aws-chunked stream.");
            }

            String[] headerParts = header.split(";", -1);
            String rawSize = headerParts[0].trim();
            String declaredSignature = null;
            if (requireChunkSignature) {
                declaredSignature = requireValidChunkSignature(headerParts);
            }
            long size;
            try {
                size = Long.parseLong(rawSize, 16);
            } catch (NumberFormatException exception) {
                throw new IOException("Invalid aws-chunked size.", exception);
            }
            if (size < 0 || size > Integer.MAX_VALUE) {
                throw new IOException("Unsupported aws-chunked size.");
            }
            if (decodedLength + size > expectedDecodedLength) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "aws-chunked decoded content length exceeded.");
            }
            if (size == 0) {
                verifyChunkSignature(declaredSignature, new byte[0]);
                drainTrailers();
                if (decodedLength != expectedDecodedLength) {
                    throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "aws-chunked decoded content length mismatch.");
                }
                chunk = new byte[0];
                offset = 0;
                finished = true;
                return;
            }

            chunk = input.readNBytes((int) size);
            if (chunk.length != size) {
                throw new IOException("Unexpected end of aws-chunked data.");
            }
            verifyChunkSignature(declaredSignature, chunk);
            decodedLength += chunk.length;
            consumeCrlf();
            offset = 0;
        }

        private String requireValidChunkSignature(String[] headerParts) {
            String signature = null;
            for (int i = 1; i < headerParts.length; i++) {
                String extension = headerParts[i].trim();
                int separator = extension.indexOf('=');
                if (separator <= 0) {
                    continue;
                }
                String name = extension.substring(0, separator).trim();
                if ("chunk-signature".equalsIgnoreCase(name)) {
                    signature = extension.substring(separator + 1).trim();
                    break;
                }
            }
            if (signature == null || !isLowerHex(signature)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR,
                        "aws-chunked chunk-signature must be a 64-character lowercase hex value.");
            }
            return signature;
        }

        private void verifyChunkSignature(String declaredSignature, byte[] chunkData) {
            if (signatureContext == null) {
                return;
            }
            String stringToSign = signatureContext.algorithm() + "\n"
                    + signatureContext.requestDate() + "\n"
                    + signatureContext.credentialScope() + "\n"
                    + previousSignature + "\n"
                    + sha256Hex(new byte[0]) + "\n"
                    + sha256Hex(chunkData);
            String expectedSignature = HexFormat.of()
                    .formatHex(hmacSha256(signatureContext.signingKey(), stringToSign));
            if (!MessageDigest.isEqual(
                    expectedSignature.getBytes(StandardCharsets.UTF_8),
                    declaredSignature.getBytes(StandardCharsets.UTF_8)
            )) {
                throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid AWS SigV4 chunk signature.");
            }
            previousSignature = declaredSignature;
        }

        private boolean isLowerHex(String value) {
            if (value.length() != 64) {
                return false;
            }
            for (int i = 0; i < value.length(); i++) {
                char current = value.charAt(i);
                if (!((current >= '0' && current <= '9') || (current >= 'a' && current <= 'f'))) {
                    return false;
                }
            }
            return true;
        }

        private void drainTrailers() throws IOException {
            String line;
            do {
                line = readAsciiLine();
                if (line != null && !line.isEmpty()) {
                    int separator = line.indexOf(':');
                    if (separator <= 0) {
                        throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid aws-chunked trailer header.");
                    }
                    trailers.put(
                            line.substring(0, separator).trim().toLowerCase(Locale.ROOT),
                            line.substring(separator + 1).trim()
                    );
                }
            } while (line != null && !line.isEmpty());
        }

        private String trailer(String headerName) {
            return trailers.get(headerName.toLowerCase(Locale.ROOT));
        }

        private void consumeCrlf() throws IOException {
            int first = input.read();
            if (first == '\n') {
                return;
            }
            if (first != '\r') {
                throw new IOException("Invalid aws-chunked chunk terminator.");
            }
            int second = input.read();
            if (second != '\n') {
                throw new IOException("Invalid aws-chunked chunk terminator.");
            }
        }

        private String readAsciiLine() throws IOException {
            StringBuilder line = new StringBuilder();
            while (true) {
                int value = input.read();
                if (value < 0) {
                    return line.isEmpty() ? null : line.toString();
                }
                if (value == '\n') {
                    return line.toString();
                }
                if (value != '\r') {
                    line.append((char) value);
                }
            }
        }
    }

    private static final class S3ChecksumValidatingInputStream extends FilterInputStream {
        private final long expectedLength;
        private final MessageDigest md5;
        private final byte[] expectedDigest;
        private final BodyChecksumValidator payloadHashValidator;
        private final List<BodyChecksumValidator> checksumValidators;
        private long bytesRead;
        private byte[] actualDigest;

        private S3ChecksumValidatingInputStream(
                InputStream content,
                long expectedLength,
                String expectedContentMd5,
                BodyChecksumValidator payloadHashValidator,
                List<BodyChecksumValidator> checksumValidators
        ) {
            super(content);
            this.expectedLength = expectedLength;
            this.md5 = messageDigest("MD5");
            this.expectedDigest = decodeContentMd5(expectedContentMd5);
            this.payloadHashValidator = payloadHashValidator;
            this.checksumValidators = checksumValidators;
        }

        @Override
        public int read() throws IOException {
            int value = super.read();
            if (value < 0) {
                finish();
                return value;
            }
            if (actualDigest == null) {
                md5.update((byte) value);
                if (payloadHashValidator != null) {
                    payloadHashValidator.update(value);
                }
                checksumValidators.forEach(validator -> validator.update(value));
                bytesRead++;
                finishIfTrailerChecksumReady();
            }
            return value;
        }

        @Override
        public int read(byte[] buffer, int offset, int length) throws IOException {
            int count = super.read(buffer, offset, length);
            if (count < 0) {
                finish();
                return count;
            }
            if (count > 0 && actualDigest == null) {
                md5.update(buffer, offset, count);
                if (payloadHashValidator != null) {
                    payloadHashValidator.update(buffer, offset, count);
                }
                checksumValidators.forEach(validator -> validator.update(buffer, offset, count));
                bytesRead += count;
                finishIfTrailerChecksumReady();
            }
            return count;
        }

        private void finishIfTrailerChecksumReady() {
            if (expectedLength >= 0
                    && bytesRead == expectedLength
                    && checksumValidators.stream().anyMatch(BodyChecksumValidator::requiresTrailerFinish)) {
                finish();
            }
        }

        private void finish() {
            if (actualDigest != null) {
                return;
            }
            assertNoUnreadBody();
            if (expectedLength >= 0 && bytesRead != expectedLength) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Request body length does not match expected content length.");
            }
            actualDigest = md5.digest();
            if (expectedDigest != null && !MessageDigest.isEqual(expectedDigest, actualDigest)) {
                throw new ApiException(ApiErrorCode.BAD_DIGEST, "Content-MD5 does not match uploaded object body.");
            }
            if (payloadHashValidator != null) {
                payloadHashValidator.validate();
            }
            checksumValidators.forEach(BodyChecksumValidator::validate);
        }

        private void assertNoUnreadBody() {
            if (expectedLength < 0 || bytesRead != expectedLength) {
                return;
            }
            try {
                int nextByte = super.read();
                if (nextByte >= 0) {
                    throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Request body length does not match expected content length.");
                }
            } catch (IOException exception) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, exception.getMessage());
            }
        }

        private String md5Hex() {
            finish();
            return HexFormat.of().formatHex(actualDigest);
        }

    }

    private static final class BodyChecksumValidator {
        private final String headerName;
        private final MessageDigest messageDigest;
        private final Checksum checksum;
        private final byte[] expectedDigest;
        private final int expectedLength;
        private final AwsChunkedInputStream trailerSource;
        private final Map<String, String> checksumValues;

        private BodyChecksumValidator(
                String headerName,
                MessageDigest messageDigest,
                Checksum checksum,
                byte[] expectedDigest,
                int expectedLength,
                AwsChunkedInputStream trailerSource,
                Map<String, String> checksumValues
        ) {
            this.headerName = headerName;
            this.messageDigest = messageDigest;
            this.checksum = checksum;
            this.expectedDigest = expectedDigest;
            this.expectedLength = expectedLength;
            this.trailerSource = trailerSource;
            this.checksumValues = checksumValues;
        }

        private static BodyChecksumValidator messageDigest(String headerName, MessageDigest messageDigest, byte[] expectedDigest) {
            return new BodyChecksumValidator(headerName, messageDigest, null, expectedDigest, expectedDigest.length, null, null);
        }

        private static BodyChecksumValidator crc(String headerName, Checksum checksum, byte[] expectedDigest) {
            return new BodyChecksumValidator(headerName, null, checksum, expectedDigest, expectedDigest.length, null, null);
        }

        private static BodyChecksumValidator trailerMessageDigest(
                String headerName,
                MessageDigest messageDigest,
                int expectedLength,
                AwsChunkedInputStream trailerSource,
                Map<String, String> checksumValues
        ) {
            return new BodyChecksumValidator(headerName, messageDigest, null, null, expectedLength, trailerSource, checksumValues);
        }

        private static BodyChecksumValidator trailerCrc(
                String headerName,
                Checksum checksum,
                int expectedLength,
                AwsChunkedInputStream trailerSource,
                Map<String, String> checksumValues
        ) {
            return new BodyChecksumValidator(headerName, null, checksum, null, expectedLength, trailerSource, checksumValues);
        }

        private void update(int value) {
            if (messageDigest != null) {
                messageDigest.update((byte) value);
            } else {
                checksum.update(value);
            }
        }

        private void update(byte[] buffer, int offset, int length) {
            if (messageDigest != null) {
                messageDigest.update(buffer, offset, length);
            } else {
                checksum.update(buffer, offset, length);
            }
        }

        private void validate() {
            byte[] expected = expectedDigest();
            byte[] actualDigest = messageDigest != null
                    ? messageDigest.digest()
                    : checksumDigest(checksum.getValue(), expectedLength);
            if (!MessageDigest.isEqual(expected, actualDigest)) {
                throw new ApiException(ApiErrorCode.BAD_DIGEST, headerName + " does not match uploaded object body.");
            }
        }

        private boolean requiresTrailerFinish() {
            return trailerSource != null;
        }

        private byte[] expectedDigest() {
            if (expectedDigest != null) {
                return expectedDigest;
            }
            if (trailerSource == null) {
                throw new ApiException(ApiErrorCode.INVALID_DIGEST, headerName + " checksum is unavailable.");
            }
            String rawChecksum = trailerSource.trailer(headerName);
            if (rawChecksum == null || rawChecksum.isBlank()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, headerName + " trailer is required.");
            }
            if (checksumValues != null) {
                checksumValues.put(headerName, rawChecksum.trim());
            }
            return decodeChecksum(headerName, rawChecksum, expectedLength);
        }

        private static byte[] checksumDigest(long value, int length) {
            return length == 8 ? longDigest(value) : intDigest(value);
        }

        private static byte[] intDigest(long value) {
            long normalized = value & 0xffffffffL;
            return new byte[]{
                    (byte) (normalized >>> 24),
                    (byte) (normalized >>> 16),
                    (byte) (normalized >>> 8),
                    (byte) normalized
            };
        }

        private static byte[] longDigest(long value) {
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
    }

    private record ByteRange(long start, long end) {

        long length() {
            return end - start + 1;
        }
    }

    private record CopySource(String bucketName, String objectKey, String versionId) {
    }

    private record DeleteObjectsRequest(List<String> keys, boolean quiet) {
    }

    private record DeleteObjectError(String key, String code, String message) {
    }

    private record ChecksumValidation(
            List<BodyChecksumValidator> validators,
            ChecksumResponseHeader responseHeader,
            Map<String, String> values
    ) {
    }

    private record MultipartUploadPartsPage(
            int partNumberMarker,
            int maxParts,
            boolean isTruncated,
            Integer nextPartNumberMarker,
            List<MultipartUploadUploadedPart> parts
    ) {
        private String nextPartNumberMarkerValue() {
            return nextPartNumberMarker == null ? "" : String.valueOf(nextPartNumberMarker);
        }
    }

    private record ChecksumResponseHeader(String name, Map<String, String> values) {

        private static ChecksumResponseHeader empty() {
            return new ChecksumResponseHeader("", Map.of());
        }

        private void apply(ResponseEntity.BodyBuilder builder) {
            String value = values.get(name);
            if (name != null && !name.isBlank() && value != null && !value.isBlank()) {
                builder.header(name, value);
            }
        }

        private Map<String, String> asMap() {
            if (name == null || name.isBlank()) {
                return Map.of();
            }
            String value = values.get(name);
            return value == null || value.isBlank() ? Map.of() : Map.of(name, value);
        }
    }

    private enum ConditionalDecision {
        NONE(0),
        NOT_MODIFIED(304),
        PRECONDITION_FAILED(412);

        private final int status;

        ConditionalDecision(int status) {
            this.status = status;
        }

        int status() {
            return status;
        }
    }
}
