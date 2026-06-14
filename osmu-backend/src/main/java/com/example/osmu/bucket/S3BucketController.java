package com.example.osmu.bucket;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/s3/{bucketName}")
public class S3BucketController {

    private static final String AWS_XML_NAMESPACE = "http://s3.amazonaws.com/doc/2006-03-01/";

    private final BucketService bucketService;
    private final S3RequestAuthService s3RequestAuthService;
    private final AuditLogService auditLogService;
    private final AuthContext authContext;
    private final String region;

    public S3BucketController(
            BucketService bucketService,
            S3RequestAuthService s3RequestAuthService,
            AuditLogService auditLogService,
            AuthContext authContext,
            @Value("${osmu.storage.region:us-east-1}") String region
    ) {
        this.bucketService = bucketService;
        this.s3RequestAuthService = s3RequestAuthService;
        this.auditLogService = auditLogService;
        this.authContext = authContext;
        this.region = region;
    }

    @PutMapping(params = {"!lifecycle", "!tagging"})
    public ResponseEntity<Void> createBucket(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        BucketRecord bucket = bucketService.create(new CreateBucketRequest(bucketName, null, null, null), user);
        auditLogService.record("S3_BUCKET_CREATE", user.loginId(), "BUCKET", bucket.name(), "SUCCESS", "S3-style bucket created", request);
        return ResponseEntity.ok()
                .header(HttpHeaders.LOCATION, "/" + bucket.name())
                .header("x-amz-bucket-region", region)
                .build();
    }

    @RequestMapping(method = RequestMethod.HEAD)
    public ResponseEntity<Void> headBucket(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUserAny(request, bucketName, "READ", "WRITE", "DELETE", "ADMIN");
        BucketRecord bucket = bucketService.get(bucketName, user);
        auditLogService.record("S3_BUCKET_HEAD", user.loginId(), "BUCKET", bucket.name(), "SUCCESS", "S3-style bucket metadata read", request);
        return ResponseEntity.ok()
                .header("x-amz-bucket-region", region)
                .build();
    }

    @GetMapping(params = "location", produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> getBucketLocation(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUserAny(request, bucketName, "READ", "WRITE", "DELETE", "ADMIN");
        BucketRecord bucket = bucketService.get(bucketName, user);
        auditLogService.record("S3_BUCKET_LOCATION_GET", user.loginId(), "BUCKET", bucket.name(), "SUCCESS", "S3-style bucket location read", request);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .header("x-amz-bucket-region", region)
                .body(locationXml());
    }

    @DeleteMapping(params = {"!lifecycle", "!tagging"})
    public ResponseEntity<Void> deleteBucket(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = s3RequestAuthService.currentUserAny(request, bucketName, "ADMIN");
        BucketRecord bucket = bucketService.get(bucketName, user);
        bucketService.delete(bucketName, user);
        auditLogService.record("S3_BUCKET_DELETE", user.loginId(), "BUCKET", bucket.name(), "SUCCESS", "S3-style bucket deleted", request);
        return ResponseEntity.noContent()
                .header("x-amz-bucket-region", region)
                .build();
    }

    private String locationXml() {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                + "<LocationConstraint xmlns=\"%s\">%s</LocationConstraint>".formatted(AWS_XML_NAMESPACE, region);
    }
}
