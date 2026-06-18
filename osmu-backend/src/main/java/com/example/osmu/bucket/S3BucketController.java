package com.example.osmu.bucket;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
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
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

@RestController
@RequestMapping({"/api/s3/{bucketName}", "/{bucketName}"})
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

    @PutMapping(value = {"", "/"}, params = {"!lifecycle", "!tagging"})
    public ResponseEntity<Void> createBucket(
            @PathVariable("bucketName") String bucketName,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        validateCreateBucketLocation(request);
        BucketRecord bucket = bucketService.create(new CreateBucketRequest(bucketName, null, null, null), user);
        auditLogService.record("S3_BUCKET_CREATE", user.loginId(), "BUCKET", bucket.name(), "SUCCESS", "S3-style bucket created", request);
        return ResponseEntity.ok()
                .header(HttpHeaders.LOCATION, "/" + bucket.name())
                .header("x-amz-bucket-region", region)
                .build();
    }

    @RequestMapping(value = {"", "/"}, method = RequestMethod.HEAD)
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

    @GetMapping(value = {"", "/"}, params = "location", produces = MediaType.APPLICATION_XML_VALUE)
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

    @DeleteMapping(value = {"", "/"}, params = {"!lifecycle", "!tagging"})
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

    private void validateCreateBucketLocation(HttpServletRequest request) {
        String body;
        try {
            body = new String(request.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
        } catch (IOException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "CreateBucketConfiguration XML could not be read.");
        }
        if (body.isBlank()) {
            return;
        }
        String requestedRegion = createBucketLocationConstraint(body);
        if (requestedRegion.isBlank()) {
            return;
        }
        if (!requestedRegion.equals(region)) {
            throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    "CreateBucket LocationConstraint must match storage region " + region + "."
            );
        }
    }

    private String createBucketLocationConstraint(String rawXml) {
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setNamespaceAware(true);
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
            factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
            factory.setXIncludeAware(false);
            factory.setExpandEntityReferences(false);
            Element root = factory.newDocumentBuilder()
                    .parse(new ByteArrayInputStream(rawXml.getBytes(StandardCharsets.UTF_8)))
                    .getDocumentElement();
            NodeList constraints = root.getElementsByTagNameNS("*", "LocationConstraint");
            if (constraints.getLength() == 0) {
                return "";
            }
            return constraints.item(0).getTextContent() == null ? "" : constraints.item(0).getTextContent().trim();
        } catch (ParserConfigurationException | SAXException | IOException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid CreateBucketConfiguration XML.");
        }
    }
}
