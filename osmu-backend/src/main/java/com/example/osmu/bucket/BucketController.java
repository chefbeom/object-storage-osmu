package com.example.osmu.bucket;

import com.example.osmu.accesskey.AccessKeyService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.audit.AuditLogService;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import jakarta.validation.Valid;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/buckets")
public class BucketController {

    private final BucketService bucketService;
    private final BucketTagService bucketTagService;
    private final AccessKeyService accessKeyService;
    private final AuditLogService auditLogService;
    private final AuthContext authContext;

    public BucketController(
            BucketService bucketService,
            BucketTagService bucketTagService,
            AccessKeyService accessKeyService,
            AuditLogService auditLogService,
            AuthContext authContext
    ) {
        this.bucketService = bucketService;
        this.bucketTagService = bucketTagService;
        this.accessKeyService = accessKeyService;
        this.auditLogService = auditLogService;
        this.authContext = authContext;
    }

    @GetMapping
    public ListResponse<BucketRecord> listBuckets(HttpServletRequest request) {
        return ListResponse.of(bucketService.list(authContext.currentUser(request)));
    }

    @PostMapping
    public ApiResponse<BucketRecord> createBucket(
            @Valid @RequestBody CreateBucketRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser user = authContext.currentUser(httpRequest);
        BucketRecord bucket = bucketService.create(request, user);
        auditLogService.record("BUCKET_CREATE", user.loginId(), "BUCKET", bucket.name(), "SUCCESS", "Bucket created", httpRequest);
        return ApiResponse.of(bucket);
    }

    @GetMapping("/{bucketName}")
    public ApiResponse<BucketRecord> getBucket(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        return ApiResponse.of(bucketService.get(bucketName, authContext.currentUser(request)));
    }

    @PostMapping("/{bucketName}/sync")
    public ApiResponse<BucketRecord> syncBucketUsage(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        BucketRecord bucket = bucketService.syncUsage(bucketName, user);
        auditLogService.record("BUCKET_SYNC", user.loginId(), "BUCKET", bucket.name(), "SUCCESS", "Bucket usage synced", request);
        return ApiResponse.of(bucket);
    }

    @GetMapping("/{bucketName}/permissions")
    public ListResponse<BucketPermissionRecord> listBucketPermissions(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        return ListResponse.of(bucketService.listPermissions(bucketName, authContext.currentUser(request)));
    }

    @PostMapping("/{bucketName}/permissions")
    public ListResponse<BucketPermissionRecord> grantBucketPermissions(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody GrantBucketPermissionRequest permissionRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        ListResponse<BucketPermissionRecord> response = ListResponse.of(bucketService.grantPermissions(bucketName, permissionRequest, user));
        auditLogService.record("BUCKET_PERMISSION_GRANT", user.loginId(), "BUCKET", bucketName, "SUCCESS", "Bucket permission granted", request);
        return response;
    }

    @DeleteMapping("/{bucketName}/permissions/{permissionId}")
    public ResponseEntity<Void> revokeBucketPermission(
            @PathVariable("bucketName") String bucketName,
            @PathVariable("permissionId") long permissionId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        BucketPermissionRecord permission = bucketService.revokePermission(bucketName, permissionId, user);
        accessKeyService.reconcileActiveKeysForSubject(permission.subjectType(), permission.subjectId());
        auditLogService.record("BUCKET_PERMISSION_REVOKE", user.loginId(), "BUCKET", bucketName, "SUCCESS", "Bucket permission revoked", request);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{bucketName}/tags")
    public ApiResponse<BucketTagsResponse> getBucketTags(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(BucketTagsResponse.of(bucketName, bucketTagService.getTagsForRest(bucketName, user, request)));
    }

    @PutMapping("/{bucketName}/tags")
    public ApiResponse<BucketTagsResponse> replaceBucketTags(
            @PathVariable("bucketName") String bucketName,
            @Valid @RequestBody BucketTagsRequest tagsRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(BucketTagsResponse.of(bucketName, bucketTagService.replaceTagsForRest(bucketName, tagsRequest.tags(), user, request)));
    }

    @DeleteMapping("/{bucketName}/tags")
    public ResponseEntity<Void> deleteBucketTags(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        bucketTagService.deleteTagsForRest(bucketName, user, request);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{bucketName}")
    public ResponseEntity<Void> deleteBucket(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.delete(bucketName, user);
        auditLogService.record("BUCKET_DELETE", user.loginId(), "BUCKET", bucket.name(), "SUCCESS", "Bucket deleted", request);
        return ResponseEntity.noContent().build();
    }
}
