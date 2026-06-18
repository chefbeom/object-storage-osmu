package com.example.osmu.common.error;

import com.example.osmu.common.web.RequestIdFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import javax.xml.stream.XMLOutputFactory;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamWriter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<?> handleApiException(ApiException exception, HttpServletRequest request) {
        if (isS3Path(request)) {
            return s3ErrorResponse(S3ErrorCodeMapper.codeFor(exception.code(), exception.getMessage()), exception.getMessage(), request, exception.code());
        }
        return ResponseEntity
                .status(exception.code().status())
                .contentType(MediaType.APPLICATION_JSON)
                .body(ErrorResponse.of(exception.code(), exception.getMessage(), requestId(request)));
    }

    @ExceptionHandler({
            MethodArgumentNotValidException.class,
            ConstraintViolationException.class,
            IllegalArgumentException.class
    })
    public ResponseEntity<?> handleValidation(Exception exception, HttpServletRequest request) {
        if (isS3Path(request)) {
            return s3ErrorResponse("InvalidRequest", exception.getMessage(), request, ApiErrorCode.VALIDATION_ERROR);
        }
        return ResponseEntity
                .badRequest()
                .contentType(MediaType.APPLICATION_JSON)
                .body(ErrorResponse.of(ApiErrorCode.VALIDATION_ERROR, exception.getMessage(), requestId(request)));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<?> handleUnexpected(Exception exception, HttpServletRequest request) {
        log.error("Unhandled request exception. path={}", request == null ? null : request.getRequestURI(), exception);
        if (isS3Path(request)) {
            return s3ErrorResponse("InternalError", "Unexpected server error.", request, ApiErrorCode.INTERNAL_ERROR);
        }
        return ResponseEntity
                .internalServerError()
                .contentType(MediaType.APPLICATION_JSON)
                .body(ErrorResponse.of(ApiErrorCode.INTERNAL_ERROR, "Unexpected server error.", requestId(request)));
    }

    private String requestId(HttpServletRequest request) {
        if (request == null) {
            return null;
        }
        Object requestId = request.getAttribute(RequestIdFilter.REQUEST_ID_ATTRIBUTE);
        return requestId instanceof String value ? value : null;
    }

    private boolean isS3Path(HttpServletRequest request) {
        if (request == null || request.getRequestURI() == null) {
            return false;
        }
        String uri = request.getRequestURI();
        if ("/api/s3".equals(uri) || uri.startsWith("/api/s3/")) {
            return true;
        }
        return isRootS3Request(request, uri);
    }

    private boolean isRootS3Request(HttpServletRequest request, String uri) {
        if (uri.startsWith("/api/") || uri.startsWith("/actuator")) {
            return false;
        }
        String authorization = request.getHeader("Authorization");
        return authorization != null && authorization.startsWith("AWS4-HMAC-SHA256 ")
                || "AWS4-HMAC-SHA256".equals(request.getParameter("X-Amz-Algorithm"))
                || hasText(request.getHeader("X-OSMU-Access-Key"))
                || hasText(request.getHeader("X-OSMU-Secret-Key"));
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private ResponseEntity<String> s3ErrorResponse(
            String code,
            String message,
            HttpServletRequest request,
            ApiErrorCode statusCode
    ) {
        return ResponseEntity
                .status(s3Status(code, statusCode))
                .contentType(MediaType.APPLICATION_XML)
                .body(s3ErrorXml(code, message, requestResource(request), requestId(request), s3ErrorDetails(code, request)));
    }

    private HttpStatusCode s3Status(String code, ApiErrorCode fallback) {
        if ("AccessDenied".equals(code)) {
            return HttpStatusCode.valueOf(403);
        }
        return fallback.status();
    }

    private String requestResource(HttpServletRequest request) {
        if (request == null || request.getRequestURI() == null) {
            return "";
        }
        String query = request.getQueryString();
        return query == null || query.isBlank()
                ? request.getRequestURI()
                : request.getRequestURI() + "?" + query;
    }

    private String s3ErrorXml(String code, String message, String resource, String requestId, Map<String, String> details) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("Error");
            writeElement(xml, "Code", code);
            writeElement(xml, "Message", message == null || message.isBlank() ? code : message);
            for (Map.Entry<String, String> detail : details.entrySet()) {
                writeElement(xml, detail.getKey(), detail.getValue());
            }
            if (resource != null && !resource.isBlank()) {
                writeElement(xml, "Resource", resource);
            }
            if (requestId != null && !requestId.isBlank()) {
                writeElement(xml, "RequestId", requestId);
                writeElement(xml, "HostId", s3HostId(requestId, resource));
            }
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            return "<Error><Code>InternalError</Code><Message>Failed to render error response.</Message></Error>";
        }
    }

    private Map<String, String> s3ErrorDetails(String code, HttpServletRequest request) {
        S3ResourceParts resource = s3ResourceParts(request);
        Map<String, String> details = new LinkedHashMap<>();
        if (resource.bucketName() != null && switch (code) {
            case "NoSuchBucket", "InvalidBucketName", "BucketNotEmpty", "BucketAlreadyOwnedByYou", "BucketAlreadyExists",
                    "NoSuchKey", "NoSuchUpload" -> true;
            default -> false;
        }) {
            details.put("BucketName", resource.bucketName());
        }
        if (resource.key() != null && ("NoSuchKey".equals(code) || "NoSuchUpload".equals(code))) {
            details.put("Key", resource.key());
        }
        if ("NoSuchUpload".equals(code) && request != null && hasText(request.getParameter("uploadId"))) {
            details.put("UploadId", request.getParameter("uploadId"));
        }
        return details;
    }

    private S3ResourceParts s3ResourceParts(HttpServletRequest request) {
        if (request == null || request.getRequestURI() == null) {
            return new S3ResourceParts(null, null);
        }
        String path = request.getRequestURI();
        if ("/api/s3".equals(path)) {
            return new S3ResourceParts(null, null);
        }
        String resourcePath = path.startsWith("/api/s3/")
                ? path.substring("/api/s3/".length())
                : path.startsWith("/") ? path.substring(1) : path;
        if (resourcePath.isBlank()) {
            return new S3ResourceParts(null, null);
        }
        int separator = resourcePath.indexOf('/');
        if (separator < 0) {
            return new S3ResourceParts(resourcePath, null);
        }
        String bucketName = resourcePath.substring(0, separator);
        String key = resourcePath.substring(separator + 1);
        return new S3ResourceParts(bucketName.isBlank() ? null : bucketName, key.isBlank() ? null : key);
    }

    private String s3HostId(String requestId, String resource) {
        try {
            String seed = requestId + ":" + (resource == null ? "" : resource);
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(seed.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(digest);
        } catch (NoSuchAlgorithmException exception) {
            return requestId;
        }
    }

    private void writeElement(XMLStreamWriter xml, String name, String value) throws XMLStreamException {
        xml.writeStartElement(name);
        xml.writeCharacters(value);
        xml.writeEndElement();
    }

    private record S3ResourceParts(String bucketName, String key) {
    }
}
