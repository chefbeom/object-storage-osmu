package com.example.osmu.bucket;

import com.example.osmu.admin.ObjectLifecycleS3XmlImportResponse;
import com.example.osmu.admin.ObjectLifecycleS3XmlRequest;
import com.example.osmu.admin.ObjectLifecycleS3XmlResponse;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketLifecycleService.BucketLifecycleXml;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectLifecycleRule;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/buckets/{bucketName}/lifecycle")
public class BucketLifecycleController {

    private final BucketLifecycleService bucketLifecycleService;
    private final AuthContext authContext;

    public BucketLifecycleController(
            BucketLifecycleService bucketLifecycleService,
            AuthContext authContext
    ) {
        this.bucketLifecycleService = bucketLifecycleService;
        this.authContext = authContext;
    }

    @GetMapping
    public ResponseEntity<?> getBucketLifecycle(
            @PathVariable("bucketName") String bucketName,
            @RequestHeader(name = HttpHeaders.ACCEPT, required = false) String accept,
            HttpServletRequest request
    ) {
        BucketLifecycleXml lifecycle = bucketLifecycleService.exportXml(bucketName, authContext.currentUser(request));
        if (wantsXml(accept)) {
            return ResponseEntity.ok()
                    .contentType(MediaType.APPLICATION_XML)
                    .body(lifecycle.xml());
        }
        return ResponseEntity.ok(ApiResponse.of(new ObjectLifecycleS3XmlResponse(
                lifecycle.ruleCount(),
                lifecycle.xml()
        )));
    }

    @PutMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ApiResponse<ObjectLifecycleS3XmlImportResponse> putBucketLifecycle(
            @PathVariable("bucketName") String bucketName,
            @RequestBody ObjectLifecycleS3XmlRequest lifecycleRequest,
            HttpServletRequest request
    ) {
        if (lifecycleRequest == null || lifecycleRequest.xml() == null || lifecycleRequest.xml().isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Lifecycle XML is required.");
        }
        AuthenticatedUser user = authContext.currentUser(request);
        List<ObjectLifecycleRule> savedRules = bucketLifecycleService.replaceXml(
                bucketName,
                lifecycleRequest.xml(),
                user,
                request
        );
        return ApiResponse.of(new ObjectLifecycleS3XmlImportResponse(savedRules.size(), savedRules));
    }

    @PutMapping(consumes = {MediaType.APPLICATION_XML_VALUE, MediaType.TEXT_XML_VALUE})
    public ResponseEntity<Void> putBucketLifecycleXml(
            @PathVariable("bucketName") String bucketName,
            @RequestBody String rawXml,
            HttpServletRequest request
    ) {
        if (rawXml == null || rawXml.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Lifecycle XML is required.");
        }
        AuthenticatedUser user = authContext.currentUser(request);
        bucketLifecycleService.replaceXml(bucketName, rawXml, user, request);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping
    public ResponseEntity<Void> deleteBucketLifecycle(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        bucketLifecycleService.deleteXml(bucketName, user, request);
        return ResponseEntity.noContent().build();
    }

    private boolean wantsXml(String accept) {
        if (accept == null || accept.isBlank()) {
            return false;
        }
        return MediaType.parseMediaTypes(accept)
                .stream()
                .anyMatch(mediaType -> !mediaType.isWildcardType()
                        && !mediaType.isWildcardSubtype()
                        && (MediaType.APPLICATION_XML.isCompatibleWith(mediaType)
                        || MediaType.TEXT_XML.isCompatibleWith(mediaType)));
    }
}
