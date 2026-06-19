package com.example.osmu.bucket;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketLifecycleService.BucketLifecycleXml;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import jakarta.servlet.http.HttpServletRequest;
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
}
