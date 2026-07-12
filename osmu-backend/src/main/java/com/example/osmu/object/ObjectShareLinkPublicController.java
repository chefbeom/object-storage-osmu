package com.example.osmu.object;

import com.example.osmu.audit.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import java.io.InputStream;
import java.util.Arrays;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

@RestController
@RequestMapping("/api/public/share-links")
public class ObjectShareLinkPublicController {

    private final ObjectShareLinkService shareLinkService;
    private final AuditLogService auditLogService;
    private final Set<String> trustedProxies;

    public ObjectShareLinkPublicController(
            ObjectShareLinkService shareLinkService,
            AuditLogService auditLogService,
            @Value("${osmu.api.trusted-proxies:}") String trustedProxies
    ) {
        this.shareLinkService = shareLinkService;
        this.auditLogService = auditLogService;
        this.trustedProxies = Set.copyOf(Arrays.stream(trustedProxies.split(","))
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .toList());
    }

    @GetMapping("/{token}")
    public ResponseEntity<StreamingResponseBody> download(
            @PathVariable("token") String token,
            HttpServletRequest request
    ) {
        ObjectShareLinkDownload download = shareLinkService.openDownload(token, sharePassword(request), clientIp(request));
        StoredObjectStream object = download.object();
        auditLogService.record(
                "OBJECT_SHARE_LINK_DOWNLOAD",
                "anonymous",
                "OBJECT",
                download.link().bucketName() + "/" + object.metadata().key(),
                "SUCCESS",
                "Object share link download started",
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

    private String filename(String objectKey) {
        String normalized = objectKey == null ? "download" : objectKey.replace("\"", "");
        int slashIndex = normalized.lastIndexOf('/');
        return slashIndex >= 0 ? normalized.substring(slashIndex + 1) : normalized;
    }

    private String sharePassword(HttpServletRequest request) {
        return request.getHeader("X-OSMU-Share-Password");
    }

    private String clientIp(HttpServletRequest request) {
        String remoteAddr = request.getRemoteAddr();
        if (!trustedProxies.contains(remoteAddr)) {
            return remoteAddr;
        }
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            return forwardedFor.split(",", 2)[0].trim();
        }
        return remoteAddr;
    }

}
