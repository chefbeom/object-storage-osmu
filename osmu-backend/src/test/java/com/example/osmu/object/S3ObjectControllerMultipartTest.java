package com.example.osmu.object;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.S3RequestAuthService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.monitoring.DataFlowMonitoringService;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletRequest;

class S3ObjectControllerMultipartTest {

    private final ObjectService objectService = mock(ObjectService.class);
    private final S3RequestAuthService s3RequestAuthService = mock(S3RequestAuthService.class);
    private final AuditLogService auditLogService = mock(AuditLogService.class);
    private final DataFlowMonitoringService dataFlowMonitoringService = mock(DataFlowMonitoringService.class);
    private final S3ObjectController controller = new S3ObjectController(
            objectService,
            s3RequestAuthService,
            auditLogService,
            dataFlowMonitoringService
    );
    private final AuthenticatedUser user = new AuthenticatedUser(1L, "admin", "ADMIN", null);

    @Test
    void createMultipartUploadReturnsS3InitiateXml() {
        MockHttpServletRequest request = request("POST");
        request.setContentType(MediaType.APPLICATION_OCTET_STREAM_VALUE);
        request.addHeader("X-OSMU-Multipart-Size-Bytes", "10485760");
        request.addHeader("X-OSMU-Multipart-Part-Size-Bytes", "5242880");
        request.addHeader("X-OSMU-Tags", "project=osmu");
        when(s3RequestAuthService.currentUser(request, "bucket", "WRITE")).thenReturn(user);
        when(objectService.createMultipartUpload(
                eq("bucket"),
                argThat(body -> body.key().equals("videos/input.mp4")
                        && body.sizeBytes().equals(10485760L)
                        && body.partSizeBytes().equals(5242880L)
                        && body.tags().equals("project=osmu")),
                eq(user)
        )).thenReturn(new MultipartUploadCreateResponse(
                "upload-1",
                "videos/input.mp4",
                10485760L,
                5242880L,
                2,
                900,
                OffsetDateTime.now().plusMinutes(15),
                List.of()
        ));

        var response = controller.createMultipartUpload("bucket", "videos/input.mp4", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).contains("<InitiateMultipartUploadResult");
        assertThat(response.getBody()).contains("<Bucket>bucket</Bucket>");
        assertThat(response.getBody()).contains("<Key>videos/input.mp4</Key>");
        assertThat(response.getBody()).contains("<UploadId>upload-1</UploadId>");
    }

    @Test
    void listMultipartUploadsReturnsS3Xml() {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/s3/bucket");
        when(s3RequestAuthService.currentUser(request, "bucket", "WRITE")).thenReturn(user);
        when(objectService.listActiveMultipartUploads(
                eq("bucket"),
                eq("docs/"),
                eq("docs/a.txt"),
                eq("upload-a"),
                eq(2),
                eq(user)
        )).thenReturn(new MultipartUploadListResponse(
                "bucket",
                "docs/",
                "docs/a.txt",
                "upload-a",
                2,
                true,
                "docs/b.txt",
                "upload-b",
                List.of(new MultipartUploadListItem(
                        "docs/b.txt",
                        "upload-b",
                        OffsetDateTime.parse("2026-06-13T00:00:00Z")
                ))
        ));

        var response = controller.listMultipartUploads(
                "bucket",
                "docs/",
                "docs/a.txt",
                "upload-a",
                2,
                request
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).contains("<ListMultipartUploadsResult");
        assertThat(response.getBody()).contains("<NextKeyMarker>docs/b.txt</NextKeyMarker>");
        assertThat(response.getBody()).contains("<NextUploadIdMarker>upload-b</NextUploadIdMarker>");
        assertThat(response.getBody()).contains("<UploadId>upload-b</UploadId>");
        assertThat(response.getBody()).contains("<IsTruncated>true</IsTruncated>");
    }

    @Test
    void uploadMultipartPartReturnsPartEtag() throws Exception {
        MockHttpServletRequest request = request("PUT");
        request.setContent("hello".getBytes(StandardCharsets.UTF_8));
        when(s3RequestAuthService.currentUser(request, "bucket", "WRITE")).thenReturn(user);
        when(objectService.uploadMultipartPart(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("upload-1"),
                eq(1),
                any(),
                eq(5L),
                eq(user)
        )).thenAnswer(invocation -> {
            InputStream content = invocation.getArgument(4);
            assertThat(new String(content.readAllBytes(), StandardCharsets.UTF_8)).isEqualTo("hello");
            return new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L);
        });

        var response = controller.uploadMultipartPart("bucket", "videos/input.mp4", 1, "upload-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getETag()).isEqualTo("\"etag-1\"");
    }

    @Test
    void uploadMultipartPartValidatesContentMd5() throws Exception {
        MockHttpServletRequest request = request("PUT");
        request.setContent("hello".getBytes(StandardCharsets.UTF_8));
        request.addHeader("Content-MD5", contentMd5("hello"));
        when(s3RequestAuthService.currentUser(request, "bucket", "WRITE")).thenReturn(user);
        when(objectService.uploadMultipartPart(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("upload-1"),
                eq(1),
                any(),
                eq(5L),
                eq(user)
        )).thenAnswer(invocation -> {
            InputStream content = invocation.getArgument(4);
            assertThat(new String(content.readAllBytes(), StandardCharsets.UTF_8)).isEqualTo("hello");
            return new MultipartUploadUploadedPart(1, "\"%s\"".formatted(md5Hex("hello")), 5L);
        });

        var response = controller.uploadMultipartPart("bucket", "videos/input.mp4", 1, "upload-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getETag()).isEqualTo("\"%s\"".formatted(md5Hex("hello")));

        MockHttpServletRequest mismatchRequest = request("PUT");
        mismatchRequest.setContent("hello".getBytes(StandardCharsets.UTF_8));
        mismatchRequest.addHeader("Content-MD5", contentMd5("other"));
        when(s3RequestAuthService.currentUser(mismatchRequest, "bucket", "WRITE")).thenReturn(user);
        when(objectService.uploadMultipartPart(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("upload-1"),
                eq(1),
                any(),
                eq(5L),
                eq(user)
        )).thenAnswer(invocation -> {
            InputStream content = invocation.getArgument(4);
            content.readAllBytes();
            return new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L);
        });

        assertThatThrownBy(() -> controller.uploadMultipartPart("bucket", "videos/input.mp4", 1, "upload-1", mismatchRequest))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.BAD_DIGEST));

        MockHttpServletRequest invalidRequest = request("PUT");
        invalidRequest.setContent("hello".getBytes(StandardCharsets.UTF_8));
        invalidRequest.addHeader("Content-MD5", "not-valid-base64");
        when(s3RequestAuthService.currentUser(invalidRequest, "bucket", "WRITE")).thenReturn(user);

        assertThatThrownBy(() -> controller.uploadMultipartPart("bucket", "videos/input.mp4", 1, "upload-1", invalidRequest))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.INVALID_DIGEST));
    }

    @Test
    void uploadMultipartPartValidatesAwsChecksumHeaders() throws Exception {
        MockHttpServletRequest request = request("PUT");
        request.setContent("hello".getBytes(StandardCharsets.UTF_8));
        String sha256Checksum = checksumBase64("SHA-256", "hello");
        request.addHeader("x-amz-checksum-sha256", sha256Checksum);
        when(s3RequestAuthService.currentUser(request, "bucket", "WRITE")).thenReturn(user);
        when(objectService.uploadMultipartPart(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("upload-1"),
                eq(1),
                any(),
                eq(5L),
                eq(user)
        )).thenAnswer(invocation -> {
            InputStream content = invocation.getArgument(4);
            assertThat(new String(content.readAllBytes(), StandardCharsets.UTF_8)).isEqualTo("hello");
            return new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L);
        });

        var response = controller.uploadMultipartPart("bucket", "videos/input.mp4", 1, "upload-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getFirst("x-amz-checksum-sha256")).isEqualTo(sha256Checksum);

        MockHttpServletRequest mismatchRequest = request("PUT");
        mismatchRequest.setContent("hello".getBytes(StandardCharsets.UTF_8));
        mismatchRequest.addHeader("x-amz-checksum-sha256", checksumBase64("SHA-256", "other"));
        when(s3RequestAuthService.currentUser(mismatchRequest, "bucket", "WRITE")).thenReturn(user);
        when(objectService.uploadMultipartPart(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("upload-1"),
                eq(1),
                any(),
                eq(5L),
                eq(user)
        )).thenAnswer(invocation -> {
            InputStream content = invocation.getArgument(4);
            content.readAllBytes();
            return new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L);
        });

        assertThatThrownBy(() -> controller.uploadMultipartPart("bucket", "videos/input.mp4", 1, "upload-1", mismatchRequest))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.BAD_DIGEST));
    }

    @Test
    void uploadMultipartPartValidatesPayloadHashHeader() throws Exception {
        MockHttpServletRequest request = request("PUT");
        request.setContent("hello".getBytes(StandardCharsets.UTF_8));
        request.addHeader("x-amz-content-sha256", sha256Hex("hello"));
        when(s3RequestAuthService.currentUser(request, "bucket", "WRITE")).thenReturn(user);
        when(objectService.uploadMultipartPart(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("upload-1"),
                eq(1),
                any(),
                eq(5L),
                eq(user)
        )).thenAnswer(invocation -> {
            InputStream content = invocation.getArgument(4);
            assertThat(new String(content.readAllBytes(), StandardCharsets.UTF_8)).isEqualTo("hello");
            return new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L);
        });

        var response = controller.uploadMultipartPart("bucket", "videos/input.mp4", 1, "upload-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);

        MockHttpServletRequest mismatchRequest = request("PUT");
        mismatchRequest.setContent("hello".getBytes(StandardCharsets.UTF_8));
        mismatchRequest.addHeader("x-amz-content-sha256", sha256Hex("other"));
        when(s3RequestAuthService.currentUser(mismatchRequest, "bucket", "WRITE")).thenReturn(user);
        when(objectService.uploadMultipartPart(
                eq("bucket"),
                eq("videos/input.mp4"),
                eq("upload-1"),
                eq(1),
                any(),
                eq(5L),
                eq(user)
        )).thenAnswer(invocation -> {
            InputStream content = invocation.getArgument(4);
            content.readAllBytes();
            return new MultipartUploadUploadedPart(1, "\"etag-1\"", 5L);
        });

        assertThatThrownBy(() -> controller.uploadMultipartPart("bucket", "videos/input.mp4", 1, "upload-1", mismatchRequest))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.BAD_DIGEST));

        MockHttpServletRequest streamingRequest = request("PUT");
        streamingRequest.setContent("hello".getBytes(StandardCharsets.UTF_8));
        streamingRequest.addHeader("x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD");
        when(s3RequestAuthService.currentUser(streamingRequest, "bucket", "WRITE")).thenReturn(user);

        assertThatThrownBy(() -> controller.uploadMultipartPart("bucket", "videos/input.mp4", 1, "upload-1", streamingRequest))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));
    }

    @Test
    void completeMultipartUploadParsesS3XmlAndReturnsResultXml() throws Exception {
        MockHttpServletRequest request = request("POST");
        request.setContentType(MediaType.APPLICATION_XML_VALUE);
        String crc64Checksum = "rosUhgp5mIg=";
        String partChecksum = "rosUhgp5mIg=";
        request.addHeader("x-amz-checksum-crc64nvme", crc64Checksum);
        request.setContent("""
                <CompleteMultipartUpload>
                  <Part>
                    <PartNumber>1</PartNumber>
                    <ETag>"etag-1"</ETag>
                    <ChecksumCRC64NVME>%s</ChecksumCRC64NVME>
                  </Part>
                  <Part><PartNumber>2</PartNumber><ETag>"etag-2"</ETag></Part>
                </CompleteMultipartUpload>
                """.formatted(partChecksum).getBytes(StandardCharsets.UTF_8));
        when(s3RequestAuthService.currentUser(request, "bucket", "WRITE")).thenReturn(user);
        when(objectService.completeMultipartUpload(
                eq("bucket"),
                any(MultipartUploadCompleteRequest.class),
                eq(user),
                argThat(headers -> crc64Checksum.equals(headers.get("x-amz-checksum-crc64nvme")))
        ))
                .thenReturn(new StoredObjectRecord(
                        "videos/input.mp4",
                        10485760L,
                        "video/mp4",
                        OffsetDateTime.now(),
                        Map.of(),
                        null,
                        "multipart-etag",
                        Map.of("x-amz-checksum-crc64nvme", crc64Checksum)
                ));

        var response = controller.completeMultipartUpload("bucket", "videos/input.mp4", "upload-1", request);

        ArgumentCaptor<MultipartUploadCompleteRequest> captor =
                ArgumentCaptor.forClass(MultipartUploadCompleteRequest.class);
        verify(objectService).completeMultipartUpload(
                eq("bucket"),
                captor.capture(),
                eq(user),
                argThat(headers -> crc64Checksum.equals(headers.get("x-amz-checksum-crc64nvme")))
        );
        assertThat(captor.getValue().uploadId()).isEqualTo("upload-1");
        assertThat(captor.getValue().parts()).extracting(CompletedMultipartUploadPart::partNumber)
                .containsExactly(1, 2);
        assertThat(captor.getValue().parts().get(0).checksums())
                .containsEntry("x-amz-checksum-crc64nvme", partChecksum);
        assertThat(captor.getValue().parts().get(1).checksums()).isEmpty();
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getETag()).isEqualTo("\"multipart-etag\"");
        assertThat(response.getHeaders().getFirst("x-amz-checksum-crc64nvme")).isEqualTo(crc64Checksum);
        assertThat(response.getBody()).contains("<CompleteMultipartUploadResult");
        assertThat(response.getBody()).contains("<ETag>\"multipart-etag\"</ETag>");
        assertThat(response.getBody()).contains("<ChecksumCRC64NVME>" + crc64Checksum + "</ChecksumCRC64NVME>");
    }

    @Test
    void completeMultipartUploadRejectsInvalidPartListXml() {
        assertInvalidCompleteMultipartXml("""
                <CompleteMultipartUpload></CompleteMultipartUpload>
                """);
        assertInvalidCompleteMultipartXml("""
                <CompleteMultipartUpload>
                  <Part><PartNumber>2</PartNumber><ETag>"etag-2"</ETag></Part>
                  <Part><PartNumber>1</PartNumber><ETag>"etag-1"</ETag></Part>
                </CompleteMultipartUpload>
                """);
        assertInvalidCompleteMultipartXml("""
                <CompleteMultipartUpload>
                  <Part><PartNumber>1</PartNumber><ETag>"etag-1"</ETag></Part>
                  <Part><PartNumber>1</PartNumber><ETag>"etag-1b"</ETag></Part>
                </CompleteMultipartUpload>
                """);
        assertInvalidCompleteMultipartXml("""
                <CompleteMultipartUpload>
                  <Part><PartNumber>0</PartNumber><ETag>"etag-0"</ETag></Part>
                </CompleteMultipartUpload>
                """);
        assertInvalidCompleteMultipartXml("""
                <CompleteMultipartUpload>
                  <Part><PartNumber>10001</PartNumber><ETag>"etag-10001"</ETag></Part>
                </CompleteMultipartUpload>
                """);
        assertInvalidCompleteMultipartXml("""
                <CompleteMultipartUpload>
                  <Part><PartNumber>1</PartNumber><ETag> </ETag></Part>
                </CompleteMultipartUpload>
                """);

        verifyNoInteractions(objectService);
    }

    @Test
    void listAndAbortMultipartUploadUseS3QueryAlias() {
        MockHttpServletRequest listRequest = request("GET");
        when(s3RequestAuthService.currentUser(listRequest, "bucket", "WRITE")).thenReturn(user);
        when(objectService.listMultipartUploadParts(
                eq("bucket"),
                argThat(body -> body.uploadId().equals("upload-1")
                        && body.key().equals("videos/input.mp4")),
                eq(user)
        )).thenReturn(new MultipartUploadPartsResponse(
                "upload-1",
                "videos/input.mp4",
                10485760L,
                5242880L,
                2,
                List.of(
                        new MultipartUploadUploadedPart(1, "\"etag-1\"", 5242880L),
                        new MultipartUploadUploadedPart(2, "\"etag-2\"", 5242880L),
                        new MultipartUploadUploadedPart(3, "\"etag-3\"", 5242880L)
                )
        ));

        var listResponse = controller.listMultipartUploadParts("bucket", "videos/input.mp4", "upload-1", 1, 1, listRequest);

        assertThat(listResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(listResponse.getBody()).contains("<ListPartsResult");
        assertThat(listResponse.getBody()).contains("<PartNumberMarker>1</PartNumberMarker>");
        assertThat(listResponse.getBody()).contains("<NextPartNumberMarker>2</NextPartNumberMarker>");
        assertThat(listResponse.getBody()).contains("<MaxParts>1</MaxParts>");
        assertThat(listResponse.getBody()).contains("<IsTruncated>true</IsTruncated>");
        assertThat(listResponse.getBody()).contains("<PartNumber>2</PartNumber>");
        assertThat(listResponse.getBody()).contains("<ETag>\"etag-2\"</ETag>");
        assertThat(listResponse.getBody()).doesNotContain("<PartNumber>1</PartNumber>");
        assertThat(listResponse.getBody()).doesNotContain("<PartNumber>3</PartNumber>");

        assertThatThrownBy(() -> controller.listMultipartUploadParts(
                "bucket",
                "videos/input.mp4",
                "upload-1",
                1001,
                0,
                listRequest
        )).isInstanceOfSatisfying(ApiException.class, exception ->
                assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));

        MockHttpServletRequest abortRequest = request("DELETE");
        when(s3RequestAuthService.currentUser(abortRequest, "bucket", "WRITE")).thenReturn(user);

        var abortResponse = controller.abortMultipartUpload("bucket", "videos/input.mp4", "upload-1", abortRequest);

        assertThat(abortResponse.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(objectService).abortMultipartUpload(
                eq("bucket"),
                argThat(body -> body.uploadId().equals("upload-1")
                        && body.key().equals("videos/input.mp4")),
                eq(user)
        );
    }

    private void assertInvalidCompleteMultipartXml(String rawXml) {
        MockHttpServletRequest request = request("POST");
        request.setContentType(MediaType.APPLICATION_XML_VALUE);
        request.setContent(rawXml.getBytes(StandardCharsets.UTF_8));
        when(s3RequestAuthService.currentUser(request, "bucket", "WRITE")).thenReturn(user);

        assertThatThrownBy(() -> controller.completeMultipartUpload("bucket", "videos/input.mp4", "upload-1", request))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));
    }

    private MockHttpServletRequest request(String method) {
        MockHttpServletRequest request = new MockHttpServletRequest(method, "/api/s3/bucket/videos/input.mp4");
        request.addHeader(HttpHeaders.HOST, "localhost");
        return request;
    }

    private String checksumBase64(String algorithm, String value) throws Exception {
        return Base64.getEncoder().encodeToString(MessageDigest.getInstance(algorithm).digest(value.getBytes(StandardCharsets.UTF_8)));
    }

    private String sha256Hex(String value) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
    }

    private String contentMd5(String value) throws Exception {
        return Base64.getEncoder().encodeToString(md5(value));
    }

    private String md5Hex(String value) throws Exception {
        return HexFormat.of().formatHex(md5(value));
    }

    private byte[] md5(String value) throws Exception {
        return MessageDigest.getInstance("MD5").digest(value.getBytes(StandardCharsets.UTF_8));
    }
}
