package com.example.osmu.bucket;

import com.example.osmu.auth.AuthenticatedUser;
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
@RequestMapping("/api/s3/{bucketName}")
public class S3BucketTaggingController {

    private final BucketTagService bucketTagService;
    private final S3RequestAuthService s3RequestAuthService;
    private final S3TaggingXmlMapper taggingXmlMapper = new S3TaggingXmlMapper();

    public S3BucketTaggingController(
            BucketTagService bucketTagService,
            S3RequestAuthService s3RequestAuthService
    ) {
        this.bucketTagService = bucketTagService;
        this.s3RequestAuthService = s3RequestAuthService;
    }

    @GetMapping(params = "tagging", produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> getBucketTagging(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = currentUser(request, bucketName);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(taggingXmlMapper.toXml(bucketTagService.getTags(bucketName, user, request)));
    }

    @PutMapping(params = "tagging", consumes = {MediaType.APPLICATION_XML_VALUE, MediaType.TEXT_XML_VALUE})
    public ResponseEntity<Void> putBucketTagging(
            @PathVariable("bucketName") String bucketName,
            @RequestBody String rawXml,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = currentUser(request, bucketName);
        bucketTagService.replaceTags(bucketName, taggingXmlMapper.fromXml(rawXml), user, request);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping(params = "tagging")
    public ResponseEntity<Void> deleteBucketTagging(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = currentUser(request, bucketName);
        bucketTagService.deleteTags(bucketName, user, request);
        return ResponseEntity.noContent().build();
    }

    private AuthenticatedUser currentUser(HttpServletRequest request, String bucketName) {
        return s3RequestAuthService.currentUser(request, bucketName, "ADMIN");
    }
}
