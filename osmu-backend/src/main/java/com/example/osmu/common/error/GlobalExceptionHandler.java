package com.example.osmu.common.error;

import com.example.osmu.common.web.RequestIdFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import java.io.StringWriter;
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
                .status(statusCode.status())
                .contentType(MediaType.APPLICATION_XML)
                .body(s3ErrorXml(code, message, requestResource(request), requestId(request)));
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

    private String s3ErrorXml(String code, String message, String resource, String requestId) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("Error");
            writeElement(xml, "Code", code);
            writeElement(xml, "Message", message == null || message.isBlank() ? code : message);
            if (resource != null && !resource.isBlank()) {
                writeElement(xml, "Resource", resource);
            }
            if (requestId != null && !requestId.isBlank()) {
                writeElement(xml, "RequestId", requestId);
                writeElement(xml, "HostId", requestId);
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

    private void writeElement(XMLStreamWriter xml, String name, String value) throws XMLStreamException {
        xml.writeStartElement(name);
        xml.writeCharacters(value);
        xml.writeEndElement();
    }
}
