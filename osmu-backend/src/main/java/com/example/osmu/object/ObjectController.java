package com.example.osmu.object;

import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

@RestController
@RequestMapping("/api/buckets/{bucketName}/objects")
public class ObjectController {

    private final ObjectService objectService;
    private final ObjectShareLinkService shareLinkService;
    private final AuditLogService auditLogService;
    private final AuthContext authContext;

    public ObjectController(
            ObjectService objectService,
            ObjectShareLinkService shareLinkService,
            AuditLogService auditLogService,
            AuthContext authContext
    ) {
        this.objectService = objectService;
        this.shareLinkService = shareLinkService;
        this.auditLogService = auditLogService;
        this.authContext = authContext;
    }

    @GetMapping
    public StoredObjectPage listObjects(
            @PathVariable("bucketName") String bucketName,
            @RequestParam(name = "prefix", required = false) String prefix,
            @RequestParam(name = "delimiter", required = false) String delimiter,
            @RequestParam(name = "search", required = false) String search,
            @RequestParam(name = "tag", required = false) String tag,
            @RequestParam(name = "limit", required = false) Integer limit,
            @RequestParam(name = "cursor", required = false) String cursor,
            @RequestParam(name = "deleted", defaultValue = "false") boolean deleted,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        if (deleted) {
            return objectService.listDeleted(bucketName, prefix, search, tag, cursor, limit, user);
        }
        return objectService.list(bucketName, prefix, delimiter, search, tag, cursor, limit, user);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<StoredObjectRecord> uploadObject(
            @PathVariable("bucketName") String bucketName,
            @RequestParam("key") String key,
            @RequestParam(name = "tags", required = false) String tags,
            @RequestPart("file") MultipartFile file,
            HttpServletRequest request
    ) throws IOException {
        AuthenticatedUser user = authContext.currentUser(request);
        StoredObjectRecord object;
        try (InputStream stream = file.getInputStream()) {
            object = objectService.upload(bucketName, key, tags, stream, file.getSize(), file.getContentType(), user);
        }
        auditLogService.record("OBJECT_UPLOAD", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "Object uploaded", request);
        return ApiResponse.of(object);
    }

    @PostMapping("/presigned-upload")
    public ApiResponse<PresignedObjectUrl> createPresignedUploadUrl(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody PresignedObjectUrlRequest presignedRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        PresignedObjectUrl url = objectService.createPresignedUploadUrl(bucketName, presignedRequest, user);
        auditLogService.record("OBJECT_PRESIGNED_UPLOAD", user.loginId(), "OBJECT", bucketName + "/" + presignedRequest.key(), "SUCCESS", "Presigned upload URL issued", request);
        return ApiResponse.of(url);
    }

    @PostMapping("/presigned-download")
    public ApiResponse<PresignedObjectUrl> createPresignedDownloadUrl(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody PresignedObjectUrlRequest presignedRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        PresignedObjectUrl url = objectService.createPresignedDownloadUrl(bucketName, presignedRequest, user);
        auditLogService.record("OBJECT_PRESIGNED_DOWNLOAD", user.loginId(), "OBJECT", bucketName + "/" + presignedRequest.key(), "SUCCESS", "Presigned download URL issued", request);
        return ApiResponse.of(url);
    }

    @PostMapping("/share-links")
    public ApiResponse<ObjectShareLinkResponse> createShareLink(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody ObjectShareLinkCreateRequest shareRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        ObjectShareLinkIssue issue = shareLinkService.create(bucketName, shareRequest, user);
        String url = publicShareUrl(request, issue.token());
        auditLogService.record(
                "OBJECT_SHARE_LINK_CREATE",
                user.loginId(),
                "OBJECT",
                issue.link().bucketName() + "/" + issue.link().objectKey(),
                "SUCCESS",
                "Object share link issued",
                request
        );
        return ApiResponse.of(ObjectShareLinkResponse.of(issue.link(), issue.token(), url));
    }

    @GetMapping("/share-links")
    public ListResponse<ObjectShareLinkResponse> listShareLinks(
            @PathVariable("bucketName") String bucketName,
            @RequestParam(name = "key", required = false) String key,
            @RequestParam(name = "limit", required = false) Integer limit,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        List<ObjectShareLinkResponse> links = shareLinkService.list(bucketName, key, limit, user).stream()
                .map(link -> ObjectShareLinkResponse.of(link, null, null))
                .toList();
        return ListResponse.of(links);
    }

    @PostMapping("/share-links/cleanup")
    public ApiResponse<ObjectShareLinkCleanupResponse> cleanupExpiredShareLinks(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        ObjectShareLinkCleanupResponse result = shareLinkService.cleanupExpired(bucketName, user);
        auditLogService.record(
                "OBJECT_SHARE_LINK_CLEANUP",
                user.loginId(),
                "BUCKET",
                result.bucketName(),
                "SUCCESS",
                "Expired object share links cleaned",
                request
        );
        return ApiResponse.of(result);
    }

    @DeleteMapping("/share-links/{linkId}")
    public ResponseEntity<Void> revokeShareLink(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("linkId") long linkId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        ObjectShareLink link = shareLinkService.revoke(bucketName, linkId, user);
        auditLogService.record(
                "OBJECT_SHARE_LINK_REVOKE",
                user.loginId(),
                "OBJECT",
                link.bucketName() + "/" + link.objectKey(),
                "SUCCESS",
                "Object share link revoked",
                request
        );
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/presigned-upload/complete")
    public ApiResponse<StoredObjectRecord> completePresignedUpload(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody PresignedUploadCompleteRequest completeRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StoredObjectRecord object = objectService.completePresignedUpload(bucketName, completeRequest, user);
        auditLogService.record("OBJECT_PRESIGNED_UPLOAD_COMPLETE", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "Presigned upload completed", request);
        return ApiResponse.of(object);
    }

    @PostMapping("/multipart-upload")
    public ApiResponse<MultipartUploadCreateResponse> createMultipartUpload(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody MultipartUploadCreateRequest multipartRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        MultipartUploadCreateResponse response = objectService.createMultipartUpload(bucketName, multipartRequest, user);
        auditLogService.record("OBJECT_MULTIPART_UPLOAD_CREATE", user.loginId(), "OBJECT", bucketName + "/" + response.key(), "SUCCESS", "Multipart upload URLs issued", request);
        return ApiResponse.of(response);
    }

    @PostMapping("/multipart-upload/refresh")
    public ApiResponse<MultipartUploadCreateResponse> refreshMultipartUpload(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody MultipartUploadRefreshRequest refreshRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        MultipartUploadCreateResponse response = objectService.refreshMultipartUpload(bucketName, refreshRequest, user);
        auditLogService.record("OBJECT_MULTIPART_UPLOAD_REFRESH", user.loginId(), "OBJECT", bucketName + "/" + response.key(), "SUCCESS", "Multipart upload URLs refreshed", request);
        return ApiResponse.of(response);
    }

    @PostMapping("/multipart-upload/parts")
    public ApiResponse<MultipartUploadPartsResponse> listMultipartUploadParts(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody MultipartUploadPartsRequest partsRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        MultipartUploadPartsResponse response = objectService.listMultipartUploadParts(bucketName, partsRequest, user);
        auditLogService.record("OBJECT_MULTIPART_UPLOAD_PARTS_LIST", user.loginId(), "OBJECT", bucketName + "/" + response.key(), "SUCCESS", "Multipart upload parts listed", request);
        return ApiResponse.of(response);
    }

    @PostMapping("/multipart-upload/complete")
    public ApiResponse<StoredObjectRecord> completeMultipartUpload(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody MultipartUploadCompleteRequest completeRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StoredObjectRecord object = objectService.completeMultipartUpload(bucketName, completeRequest, user);
        auditLogService.record("OBJECT_MULTIPART_UPLOAD_COMPLETE", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "Multipart upload completed", request);
        return ApiResponse.of(object);
    }

    @PostMapping("/multipart-upload/abort")
    public ResponseEntity<Void> abortMultipartUpload(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody MultipartUploadAbortRequest abortRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        objectService.abortMultipartUpload(bucketName, abortRequest, user);
        auditLogService.record("OBJECT_MULTIPART_UPLOAD_ABORT", user.loginId(), "OBJECT", bucketName + "/" + abortRequest.key(), "SUCCESS", "Multipart upload aborted", request);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/tags")
    public ApiResponse<StoredObjectRecord> updateObjectTags(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody ObjectTagsUpdateRequest tagsRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StoredObjectRecord object = objectService.updateTags(bucketName, tagsRequest.key(), tagsRequest.tags(), user);
        auditLogService.record("OBJECT_TAG_UPDATE", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "Object tags updated", request);
        return ApiResponse.of(object);
    }

    @GetMapping("/metadata/{*objectKey}")
    public ApiResponse<ObjectMetadataDetail> getObjectMetadata(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        return ApiResponse.of(objectService.metadata(bucketName, objectKey, authContext.currentUser(request)));
    }

    @GetMapping("/versions/{*objectKey}")
    public ApiResponse<java.util.List<ObjectVersionRecord>> listObjectVersions(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        return ApiResponse.of(objectService.listVersions(bucketName, objectKey, authContext.currentUser(request)));
    }

    @PostMapping("/versions/{versionId}/restore/{*objectKey}")
    public ApiResponse<StoredObjectRecord> restoreObjectVersion(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("versionId") String versionId,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StoredObjectRecord object = objectService.restoreVersion(bucketName, objectKey, versionId, user);
        auditLogService.record("OBJECT_VERSION_RESTORE", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "Object version restored", request);
        return ApiResponse.of(object);
    }

    @GetMapping("/versions/{versionId}/download/{*objectKey}")
    public ResponseEntity<StreamingResponseBody> downloadObjectVersion(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("versionId") String versionId,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StoredObjectStream object = objectService.downloadVersion(bucketName, objectKey, versionId, user);
        auditLogService.record(
                "OBJECT_VERSION_DOWNLOAD",
                user.loginId(),
                "OBJECT",
                bucketName + "/" + object.metadata().key() + "#" + versionId,
                "SUCCESS",
                "Object version download started",
                request
        );
        StreamingResponseBody body = outputStream -> {
            try (InputStream inputStream = object.content()) {
                inputStream.transferTo(outputStream);
            }
        };
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(object.metadata().contentType()))
                .contentLength(object.metadata().sizeBytes())
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename(object.metadata().key()) + "\"")
                .body(body);
    }

    @DeleteMapping("/versions/{versionId}/delete/{*objectKey}")
    public ResponseEntity<Void> deleteObjectVersion(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("versionId") String versionId,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        objectService.deleteVersion(bucketName, objectKey, versionId, user);
        auditLogService.record(
                "OBJECT_VERSION_DELETE",
                user.loginId(),
                "OBJECT",
                objectTargetId(bucketName, objectKey) + "#" + versionId,
                "SUCCESS",
                "Object version deleted",
                request
        );
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{*objectKey}")
    public ResponseEntity<StreamingResponseBody> downloadObject(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StoredObjectStream object = objectService.downloadStream(bucketName, objectKey, user);
        auditLogService.record(
                "OBJECT_DOWNLOAD",
                user.loginId(),
                "OBJECT",
                bucketName + "/" + object.metadata().key(),
                "SUCCESS",
                "Object download started",
                request
        );
        StreamingResponseBody body = outputStream -> {
            try (InputStream inputStream = object.content()) {
                inputStream.transferTo(outputStream);
            }
        };
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(object.metadata().contentType()))
                .contentLength(object.metadata().sizeBytes())
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename(object.metadata().key()) + "\"")
                .body(body);
    }

    @DeleteMapping("/{*objectKey}")
    public ResponseEntity<Void> deleteObject(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StoredObjectRecord object = objectService.delete(bucketName, objectKey, user);
        auditLogService.record("OBJECT_DELETE", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "Object moved to trash", request);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/restore/{*objectKey}")
    public ApiResponse<StoredObjectRecord> restoreObject(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        StoredObjectRecord object = objectService.restore(bucketName, objectKey, user);
        auditLogService.record("OBJECT_RESTORE", user.loginId(), "OBJECT", bucketName + "/" + object.key(), "SUCCESS", "Object restored from trash", request);
        return ApiResponse.of(object);
    }

    @PostMapping("/purge/{*objectKey}")
    public ResponseEntity<Void> purgeObject(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("objectKey") String objectKey,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        objectService.purge(bucketName, objectKey, user);
        auditLogService.record(
                "OBJECT_PURGE",
                user.loginId(),
                "OBJECT",
                objectTargetId(bucketName, objectKey),
                "SUCCESS",
                "Object permanently deleted",
                request
        );
        return ResponseEntity.noContent().build();
    }

    private String objectTargetId(String bucketName, String objectKey) {
        String normalizedObjectKey = objectKey == null ? "" : objectKey.replaceFirst("^/+", "");
        return bucketName + "/" + normalizedObjectKey;
    }

    private String publicShareUrl(HttpServletRequest request, String token) {
        String base = request.getRequestURL().toString();
        int apiIndex = base.indexOf("/api/");
        String origin = apiIndex >= 0 ? base.substring(0, apiIndex) : base.replaceFirst("/+$", "");
        return origin + "/api/public/share-links/" + token;
    }

    private String filename(String objectKey) {
        String normalized = objectKey == null ? "download" : objectKey.replace("\"", "");
        int slashIndex = normalized.lastIndexOf('/');
        return slashIndex >= 0 ? normalized.substring(slashIndex + 1) : normalized;
    }
}
