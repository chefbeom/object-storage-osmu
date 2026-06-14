package com.example.osmu.bucket;

import com.example.osmu.audit.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import java.io.StringWriter;
import java.time.ZoneOffset;
import javax.xml.stream.XMLOutputFactory;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamWriter;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/s3")
public class S3RootController {

    private static final String AWS_XML_NAMESPACE = "http://s3.amazonaws.com/doc/2006-03-01/";

    private final S3RequestAuthService s3RequestAuthService;
    private final AuditLogService auditLogService;

    public S3RootController(S3RequestAuthService s3RequestAuthService, AuditLogService auditLogService) {
        this.s3RequestAuthService = s3RequestAuthService;
        this.auditLogService = auditLogService;
    }

    @GetMapping(produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> listBuckets(HttpServletRequest request) {
        S3BucketListAccess access = s3RequestAuthService.bucketListAccess(request);
        auditLogService.record("S3_BUCKET_LIST", access.user().loginId(), "BUCKET", "*", "SUCCESS", "S3-style bucket list read", request);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(listBucketsXml(access));
    }

    @RequestMapping(method = RequestMethod.HEAD)
    public ResponseEntity<Void> headService(HttpServletRequest request) {
        S3BucketListAccess access = s3RequestAuthService.bucketListAccess(request);
        auditLogService.record("S3_SERVICE_HEAD", access.user().loginId(), "BUCKET", "*", "SUCCESS", "S3-style service metadata read", request);
        return ResponseEntity.ok().build();
    }

    private String listBucketsXml(S3BucketListAccess access) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("ListAllMyBucketsResult");
            xml.writeDefaultNamespace(AWS_XML_NAMESPACE);
            xml.writeStartElement("Owner");
            writeElement(xml, "ID", String.valueOf(access.user().id()));
            writeElement(xml, "DisplayName", access.user().loginId());
            xml.writeEndElement();
            xml.writeStartElement("Buckets");
            for (BucketRecord bucket : access.buckets()) {
                xml.writeStartElement("Bucket");
                writeElement(xml, "Name", bucket.name());
                writeElement(xml, "CreationDate", bucket.createdAt().withOffsetSameInstant(ZoneOffset.UTC).toString());
                xml.writeEndElement();
            }
            xml.writeEndElement();
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new IllegalStateException("Failed to render S3 bucket list XML.", exception);
        }
    }

    private void writeElement(XMLStreamWriter xml, String name, String value) throws XMLStreamException {
        xml.writeStartElement(name);
        xml.writeCharacters(value == null ? "" : value);
        xml.writeEndElement();
    }
}
