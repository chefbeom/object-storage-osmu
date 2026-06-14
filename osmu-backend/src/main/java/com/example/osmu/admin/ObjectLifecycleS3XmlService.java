package com.example.osmu.admin;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectLifecycleRule;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import org.springframework.stereotype.Service;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

@Service
public class ObjectLifecycleS3XmlService {

    private static final int DEFAULT_BATCH_SIZE = 100;

    public String exportRules(List<ObjectLifecycleRule> rules) {
        StringBuilder xml = new StringBuilder();
        xml.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        xml.append("<LifecycleConfiguration xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">\n");
        for (ObjectLifecycleRule rule : rules) {
            xml.append("  <Rule>\n");
            xml.append("    <ID>").append(escapeXml(rule.name())).append("</ID>\n");
            xml.append("    <Status>").append(rule.enabled() ? "Enabled" : "Disabled").append("</Status>\n");
            appendFilter(xml, rule);
            if (ObjectLifecycleRule.TARGET_OBJECT_VERSION.equals(rule.targetType())) {
                xml.append("    <NoncurrentVersionExpiration>\n");
                xml.append("      <NoncurrentDays>").append(rule.retentionDays()).append("</NoncurrentDays>\n");
                xml.append("    </NoncurrentVersionExpiration>\n");
            } else {
                xml.append("    <Expiration>\n");
                xml.append("      <Days>").append(rule.retentionDays()).append("</Days>\n");
                xml.append("    </Expiration>\n");
            }
            xml.append("  </Rule>\n");
        }
        xml.append("</LifecycleConfiguration>\n");
        return xml.toString();
    }

    public List<ObjectLifecycleRule> importRules(String rawXml, OffsetDateTime now) {
        return importRules(rawXml, now, "");
    }

    public List<ObjectLifecycleRule> importRules(String rawXml, OffsetDateTime now, String bucketName) {
        if (rawXml == null || rawXml.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Lifecycle XML is required.");
        }
        Document document = parse(rawXml);
        List<Element> ruleElements = childElements(document.getDocumentElement(), "Rule");
        if (ruleElements.isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Lifecycle XML must contain at least one Rule.");
        }
        List<ObjectLifecycleRule> rules = new ArrayList<>();
        int index = 1;
        for (Element ruleElement : ruleElements) {
            rules.add(toRule(ruleElement, index, now, bucketName));
            index++;
        }
        return rules;
    }

    private ObjectLifecycleRule toRule(Element ruleElement, int index, OffsetDateTime now, String bucketName) {
        String name = textOfFirstChild(ruleElement, "ID");
        if (name.isBlank()) {
            name = "imported-lifecycle-rule-" + index;
        }
        boolean enabled = !"Disabled".equalsIgnoreCase(textOfFirstChild(ruleElement, "Status"));
        ParsedFilter filter = parseFilter(ruleElement);
        RetentionTarget target = parseRetentionTarget(ruleElement);
        return new ObjectLifecycleRule(
                UUID.randomUUID().toString(),
                name,
                enabled,
                index * 10,
                bucketName,
                target.targetType(),
                filter.prefix(),
                filter.tags(),
                target.days(),
                DEFAULT_BATCH_SIZE,
                now,
                now
        );
    }

    private RetentionTarget parseRetentionTarget(Element ruleElement) {
        Element noncurrent = firstChild(ruleElement, "NoncurrentVersionExpiration");
        if (noncurrent != null) {
            return new RetentionTarget(
                    ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                    positiveInt(textOfFirstChild(noncurrent, "NoncurrentDays"), "NoncurrentDays")
            );
        }
        Element expiration = firstChild(ruleElement, "Expiration");
        if (expiration != null) {
            return new RetentionTarget(
                    ObjectLifecycleRule.TARGET_TRASH_OBJECT,
                    positiveInt(textOfFirstChild(expiration, "Days"), "Days")
            );
        }
        throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Rule must contain Expiration/Days or NoncurrentVersionExpiration/NoncurrentDays.");
    }

    private ParsedFilter parseFilter(Element ruleElement) {
        String prefix = textOfFirstChild(ruleElement, "Prefix");
        Map<String, String> tags = new LinkedHashMap<>();
        Element filter = firstChild(ruleElement, "Filter");
        if (filter == null) {
            return new ParsedFilter(prefix, tags);
        }
        String filterPrefix = textOfFirstChild(filter, "Prefix");
        if (!filterPrefix.isBlank()) {
            prefix = filterPrefix;
        }
        Element directTag = firstChild(filter, "Tag");
        if (directTag != null) {
            addTag(tags, directTag);
        }
        Element and = firstChild(filter, "And");
        if (and != null) {
            String andPrefix = textOfFirstChild(and, "Prefix");
            if (!andPrefix.isBlank()) {
                prefix = andPrefix;
            }
            for (Element tag : childElements(and, "Tag")) {
                addTag(tags, tag);
            }
        }
        return new ParsedFilter(prefix, tags);
    }

    private void appendFilter(StringBuilder xml, ObjectLifecycleRule rule) {
        xml.append("    <Filter>\n");
        if (rule.tags().isEmpty()) {
            xml.append("      <Prefix>").append(escapeXml(rule.prefix())).append("</Prefix>\n");
        } else {
            xml.append("      <And>\n");
            if (!rule.prefix().isBlank()) {
                xml.append("        <Prefix>").append(escapeXml(rule.prefix())).append("</Prefix>\n");
            }
            for (Map.Entry<String, String> tag : rule.tags().entrySet()) {
                xml.append("        <Tag>\n");
                xml.append("          <Key>").append(escapeXml(tag.getKey())).append("</Key>\n");
                xml.append("          <Value>").append(escapeXml(tag.getValue())).append("</Value>\n");
                xml.append("        </Tag>\n");
            }
            xml.append("      </And>\n");
        }
        xml.append("    </Filter>\n");
    }

    private void addTag(Map<String, String> tags, Element tag) {
        String key = textOfFirstChild(tag, "Key");
        String value = textOfFirstChild(tag, "Value");
        if (!key.isBlank() && !value.isBlank()) {
            tags.put(key, value);
        }
    }

    private Document parse(String xml) {
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setNamespaceAware(true);
            factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
            factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
            return factory.newDocumentBuilder()
                    .parse(new ByteArrayInputStream(xml.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Lifecycle XML is invalid.");
        }
    }

    private int positiveInt(String value, String fieldName) {
        try {
            int parsed = Integer.parseInt(value.trim());
            if (parsed > 0 && parsed <= 3650) {
                return parsed;
            }
        } catch (RuntimeException ignored) {
        }
        throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must be between 1 and 3650.");
    }

    private Element firstChild(Element parent, String name) {
        for (Element child : childElements(parent, name)) {
            return child;
        }
        return null;
    }

    private String textOfFirstChild(Element parent, String name) {
        Element child = firstChild(parent, name);
        return child == null ? "" : child.getTextContent().trim();
    }

    private List<Element> childElements(Element parent, String name) {
        List<Element> elements = new ArrayList<>();
        if (parent == null) {
            return elements;
        }
        NodeList nodes = parent.getChildNodes();
        for (int index = 0; index < nodes.getLength(); index++) {
            Node node = nodes.item(index);
            if (node instanceof Element element && name.equals(nodeName(element))) {
                elements.add(element);
            }
        }
        return elements;
    }

    private String nodeName(Element element) {
        return element.getLocalName() == null ? element.getNodeName() : element.getLocalName();
    }

    private String escapeXml(String value) {
        return (value == null ? "" : value)
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&apos;");
    }

    private record ParsedFilter(String prefix, Map<String, String> tags) {
    }

    private record RetentionTarget(String targetType, int days) {
    }
}
