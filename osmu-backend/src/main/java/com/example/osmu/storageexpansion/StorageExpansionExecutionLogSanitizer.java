package com.example.osmu.storageexpansion;

import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class StorageExpansionExecutionLogSanitizer {

    private static final String MASK = "[masked]";
    private static final int MAX_COMMAND_LENGTH = 1024;
    private static final int MAX_NOTES_LENGTH = 1024;
    private static final Pattern YAML_SECRET_LINE = Pattern.compile(
            "^(\\s*(?:password|passwd|secret|token|credential|access[-_ ]?key|secret[-_ ]?key)\\s*:\\s*).+$",
            Pattern.CASE_INSENSITIVE | Pattern.MULTILINE
    );
    private static final Pattern KEY_VALUE_SECRET = Pattern.compile(
            "(\\b[A-Z0-9_.-]*(?:password|passwd|secret|token|credential|access[-_]?key|secret[-_]?key)[A-Z0-9_.-]*\\b\\s*=\\s*['\"]?)([^\\s,;'\"&]+)(['\"]?)",
            Pattern.CASE_INSENSITIVE
    );
    private static final Pattern AUTHORIZATION_HEADER = Pattern.compile(
            "(\\bAuthorization\\s*:?\\s*(?:Bearer|Basic)\\s+)([^\\s,;]+)",
            Pattern.CASE_INSENSITIVE
    );
    private static final Pattern SENSITIVE_QUERY_PARAM = Pattern.compile(
            "([?&](?:X-Amz-Signature|X-Amz-Credential|X-Amz-Security-Token|token|access_token|password|secret)=)([^&\\s]+)",
            Pattern.CASE_INSENSITIVE
    );
    private static final Pattern URL_PASSWORD = Pattern.compile(
            "(://[^:/@\\s]+:)([^@\\s]+)(@)",
            Pattern.CASE_INSENSITIVE
    );

    private final boolean maskingEnabled;
    private final int maxOutputChars;

    public StorageExpansionExecutionLogSanitizer(
            @Value("${osmu.storage-expansion.execution-log.masking-enabled:true}") boolean maskingEnabled,
            @Value("${osmu.storage-expansion.execution-log.max-output-chars:16384}") int maxOutputChars
    ) {
        this.maskingEnabled = maskingEnabled;
        this.maxOutputChars = Math.max(1024, Math.min(65536, maxOutputChars));
    }

    public String command(String command) {
        return sanitizeAndRetain(command, MAX_COMMAND_LENGTH, "[command truncated]");
    }

    public String output(String output) {
        return sanitizeAndRetain(output, maxOutputChars, "[output truncated]");
    }

    public String notes(String notes) {
        return sanitizeAndRetain(notes, MAX_NOTES_LENGTH, "[notes truncated]");
    }

    private String sanitizeAndRetain(String value, int maxLength, String marker) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String sanitized = maskingEnabled ? mask(value) : value;
        if (sanitized.length() <= maxLength) {
            return sanitized;
        }
        int keepLength = Math.max(0, maxLength - marker.length() - 1);
        return sanitized.substring(0, keepLength).stripTrailing() + "\n" + marker;
    }

    private String mask(String value) {
        String masked = YAML_SECRET_LINE.matcher(value).replaceAll("$1" + MASK);
        masked = KEY_VALUE_SECRET.matcher(masked).replaceAll("$1" + MASK + "$3");
        masked = AUTHORIZATION_HEADER.matcher(masked).replaceAll("$1" + MASK);
        masked = SENSITIVE_QUERY_PARAM.matcher(masked).replaceAll("$1" + MASK);
        return URL_PASSWORD.matcher(masked).replaceAll("$1" + MASK + "$3");
    }
}
