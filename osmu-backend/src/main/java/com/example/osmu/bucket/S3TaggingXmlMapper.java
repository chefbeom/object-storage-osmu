package com.example.osmu.bucket;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.io.IOException;
import java.io.StringReader;
import java.io.StringWriter;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.stream.XMLOutputFactory;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamWriter;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

public class S3TaggingXmlMapper {

    public Map<String, String> fromXml(String rawXml) {
        if (rawXml == null || rawXml.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Tagging XML is required.");
        }
        try {
            Element root = xmlDocument(rawXml).getDocumentElement();
            if (!"Tagging".equals(localName(root))) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid Tagging XML.");
            }
            NodeList tagNodes = root.getElementsByTagNameNS("*", "Tag");
            Map<String, String> tags = new LinkedHashMap<>();
            for (int i = 0; i < tagNodes.getLength(); i++) {
                Element tag = (Element) tagNodes.item(i);
                String key = requiredTagText(tag, "Key");
                String value = requiredTagText(tag, "Value");
                if (tags.put(key, value) != null) {
                    throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Duplicate tag key is not allowed.");
                }
            }
            return tags;
        } catch (ParserConfigurationException | IOException | SAXException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Invalid Tagging XML.");
        }
    }

    public String toXml(Map<String, String> tags) {
        try {
            StringWriter output = new StringWriter();
            XMLStreamWriter xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("Tagging");
            xml.writeDefaultNamespace("http://s3.amazonaws.com/doc/2006-03-01/");
            xml.writeStartElement("TagSet");
            for (Map.Entry<String, String> tag : tags.entrySet()) {
                xml.writeStartElement("Tag");
                writeElement(xml, "Key", tag.getKey());
                writeElement(xml, "Value", tag.getValue());
                xml.writeEndElement();
            }
            xml.writeEndElement();
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.flush();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Failed to render S3 tagging XML.");
        }
    }

    private org.w3c.dom.Document xmlDocument(String rawXml)
            throws ParserConfigurationException, IOException, SAXException {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setXIncludeAware(false);
        factory.setExpandEntityReferences(false);
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
        factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
        return factory.newDocumentBuilder().parse(new InputSource(new StringReader(rawXml)));
    }

    private String requiredTagText(Element parent, String localName) {
        NodeList nodes = parent.getElementsByTagNameNS("*", localName);
        if (nodes.getLength() == 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Tagging XML requires Key and Value.");
        }
        return nodes.item(0).getTextContent();
    }

    private String localName(Element element) {
        return element.getLocalName() == null ? element.getNodeName() : element.getLocalName();
    }

    private void writeElement(XMLStreamWriter xml, String name, String value) throws XMLStreamException {
        xml.writeStartElement(name);
        xml.writeCharacters(value == null ? "" : value);
        xml.writeEndElement();
    }
}
