package com.example.osmu.common.error;

import com.example.osmu.common.web.RequestIdFilter;
import com.example.osmu.common.web.S3TraceHeaders;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import java.io.StringWriter;
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
        if (S3TraceHeaders.isS3Request(request)) {
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
        if (S3TraceHeaders.isS3Request(request)) {
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
        if (S3TraceHeaders.isS3Request(request)) {
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

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private ResponseEntity<String> s3ErrorResponse(
            String code,
            String message,
            HttpServletRequest request,
            ApiErrorCode statusCode
    ) {
        String resource = S3TraceHeaders.resource(request);
        String requestId = requestId(request);
        String hostId = S3TraceHeaders.hostId(requestId, resource);
        String s3Message = S3ErrorCodeMapper.messageFor(code, message);
        return ResponseEntity
                .status(s3Status(code, statusCode, request))
                .contentType(MediaType.APPLICATION_XML)
                .body(s3ErrorXml(code, s3Message, resource, requestId, hostId, s3ErrorDetails(code, request)));
    }

    private HttpStatusCode s3Status(String code, ApiErrorCode fallback, HttpServletRequest request) {
        if ("AccessDenied".equals(code)) {
            if (fallback == ApiErrorCode.AUTHENTICATION_REQUIRED && !isAwsSigV4Request(request)) {
                return fallback.status();
            }
            return HttpStatusCode.valueOf(403);
        }
        if ("MissingContentLength".equals(code)) {
            return HttpStatusCode.valueOf(411);
        }
        return fallback.status();
    }

    private boolean isAwsSigV4Request(HttpServletRequest request) {
        if (request == null) {
            return false;
        }
        String authorization = request.getHeader("Authorization");
        return (authorization != null && authorization.startsWith("AWS4-HMAC-SHA256 "))
                || "AWS4-HMAC-SHA256".equals(request.getParameter("X-Amz-Algorithm"));
    }

    private String s3ErrorXml(String code, String message, String resource, String requestId, String hostId, Map<String, String> details) {
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
                if (hasText(hostId)) {
                    writeElement(xml, "HostId", hostId);
                }
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
                    "NoSuchKey", "NoSuchUpload", "NoSuchLifecycleConfiguration" -> true;
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

    private void writeElement(XMLStreamWriter xml, String name, String value) throws XMLStreamException {
        xml.writeStartElement(name);
        xml.writeCharacters(value);
        xml.writeEndElement();
    }

    private record S3ResourceParts(String bucketName, String key) {
    }
}
