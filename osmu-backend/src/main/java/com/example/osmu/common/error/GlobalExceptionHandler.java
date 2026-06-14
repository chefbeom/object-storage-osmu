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
        return request != null
                && request.getRequestURI() != null
                && ("/api/s3".equals(request.getRequestURI()) || request.getRequestURI().startsWith("/api/s3/"));
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
                .body(s3ErrorXml(code, message, requestId(request)));
    }

    private String s3ErrorXml(String code, String message, String requestId) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("Error");
            writeElement(xml, "Code", code);
            writeElement(xml, "Message", message == null || message.isBlank() ? code : message);
            if (requestId != null && !requestId.isBlank()) {
                writeElement(xml, "RequestId", requestId);
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
