package com.example.osmu.object;

import com.example.osmu.audit.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import java.io.InputStream;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

@RestController
@RequestMapping("/api/public/share-links")
public class ObjectShareLinkPublicController {

    private final ObjectShareLinkService shareLinkService;
    private final AuditLogService auditLogService;

    public ObjectShareLinkPublicController(ObjectShareLinkService shareLinkService, AuditLogService auditLogService) {
        this.shareLinkService = shareLinkService;
        this.auditLogService = auditLogService;
    }

    @GetMapping("/{token}")
    public ResponseEntity<StreamingResponseBody> download(
            @PathVariable("token") String token,
            @RequestParam(name = "password", required = false) String password,
            HttpServletRequest request
    ) {
        ObjectShareLinkDownload download = shareLinkService.openDownload(token, sharePassword(password, request), clientIp(request));
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

    private String sharePassword(String password, HttpServletRequest request) {
        if (password != null && !password.isBlank()) {
            return password;
        }
        return request.getHeader("X-OSMU-Share-Password");
    }

    private String clientIp(HttpServletRequest request) {
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            return forwardedFor.split(",", 2)[0].trim();
        }
        return request.getRemoteAddr();
    }
}
