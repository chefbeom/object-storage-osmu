package com.example.osmu.audit;

import com.example.osmu.audit.repository.AuditLogRepository;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.common.web.RequestIdFilter;
import jakarta.servlet.http.HttpServletRequest;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class AuditLogService {

    private static final int DEFAULT_LIST_LIMIT = 200;

    private final AuditLogRepository auditLogRepository;

    public AuditLogService(AuditLogRepository auditLogRepository) {
        this.auditLogRepository = auditLogRepository;
    }

    public AuditLogEntry record(
            String eventType,
            String actorId,
            String targetType,
            String targetId,
            String result,
            String message
    ) {
        return record(eventType, actorId, targetType, targetId, result, message, null, null, null);
    }

    public AuditLogEntry record(
            String eventType,
            String actorId,
            String targetType,
            String targetId,
            String result,
            String message,
            HttpServletRequest request
    ) {
        return record(
                eventType,
                actorId,
                targetType,
                targetId,
                result,
                message,
                clientIp(request),
                header(request, "User-Agent"),
                requestId(request)
        );
    }

    private AuditLogEntry record(
            String eventType,
            String actorId,
            String targetType,
            String targetId,
            String result,
            String message,
            String ipAddress,
            String userAgent,
            String requestId
    ) {
        AuditLogEntry entry = new AuditLogEntry(
                auditLogRepository.nextId(),
                eventType,
                actorId,
                targetType,
                targetId,
                result,
                message,
                ipAddress,
                userAgent,
                requestId,
                OffsetDateTime.now()
        );
        return auditLogRepository.save(entry);
    }

    public List<AuditLogEntry> list() {
        return auditLogRepository.findRecent(DEFAULT_LIST_LIMIT);
    }

    public ListResponse<AuditLogEntry> list(
            String eventType,
            String actorId,
            String requestId,
            String targetType,
            String targetId,
            String result,
            String cursor,
            String from,
            String to,
            Integer limit
    ) {
        OffsetDateTime fromTime = parseTime(from, "from");
        OffsetDateTime toTime = parseTime(to, "to");
        int normalizedLimit = normalizeLimit(limit);
        if (fromTime != null && toTime != null && fromTime.isAfter(toTime)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "from must be before or equal to to.");
        }
        AuditLogQuery query = new AuditLogQuery(
                clean(eventType),
                clean(actorId),
                clean(requestId),
                clean(targetType),
                clean(targetId),
                clean(result),
                parseCursor(cursor),
                fromTime,
                toTime,
                normalizedLimit + 1
        );
        List<AuditLogEntry> entries = auditLogRepository.find(query);
        if (entries.size() <= normalizedLimit) {
            return ListResponse.of(entries);
        }
        List<AuditLogEntry> pageItems = entries.subList(0, normalizedLimit);
        String nextCursor = String.valueOf(pageItems.get(pageItems.size() - 1).id());
        return ListResponse.of(pageItems, nextCursor);
    }

    public String exportCsv(
            String eventType,
            String actorId,
            String requestId,
            String targetType,
            String targetId,
            String result,
            String cursor,
            String from,
            String to,
            Integer limit
    ) {
        ListResponse<AuditLogEntry> page = list(eventType, actorId, requestId, targetType, targetId, result, cursor, from, to, limit);
        List<String> lines = new ArrayList<>();
        lines.add("id,eventType,actorId,targetType,targetId,result,message,ipAddress,userAgent,requestId,createdAt");
        for (AuditLogEntry entry : page.items()) {
            lines.add(String.join(",",
                    csv(entry.id()),
                    csv(entry.eventType()),
                    csv(entry.actorId()),
                    csv(entry.targetType()),
                    csv(entry.targetId()),
                    csv(entry.result()),
                    csv(entry.message()),
                    csv(entry.ipAddress()),
                    csv(entry.userAgent()),
                    csv(entry.requestId()),
                    csv(entry.createdAt())
            ));
        }
        return String.join("\r\n", lines) + "\r\n";
    }

    private OffsetDateTime parseTime(String value, String fieldName) {
        String cleaned = clean(value);
        if (cleaned == null) {
            return null;
        }
        try {
            return OffsetDateTime.parse(cleaned);
        } catch (DateTimeParseException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, fieldName + " must be ISO-8601 offset date time.");
        }
    }

    private Long parseCursor(String value) {
        String cleaned = clean(value);
        if (cleaned == null) {
            return null;
        }
        try {
            long cursor = Long.parseLong(cleaned);
            if (cursor < 1) {
                throw new NumberFormatException("cursor must be positive");
            }
            return cursor;
        } catch (NumberFormatException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "cursor must be a positive audit log id.");
        }
    }

    private int normalizeLimit(Integer limit) {
        if (limit == null) {
            return DEFAULT_LIST_LIMIT;
        }
        if (limit < 1 || limit > 500) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "limit must be between 1 and 500.");
        }
        return limit;
    }

    private String clientIp(HttpServletRequest request) {
        String forwardedFor = header(request, "X-Forwarded-For");
        if (forwardedFor != null) {
            int commaIndex = forwardedFor.indexOf(',');
            return commaIndex >= 0 ? forwardedFor.substring(0, commaIndex).trim() : forwardedFor;
        }
        return request == null ? null : clean(request.getRemoteAddr());
    }

    private String requestId(HttpServletRequest request) {
        if (request == null) {
            return null;
        }
        Object requestId = request.getAttribute(RequestIdFilter.REQUEST_ID_ATTRIBUTE);
        if (requestId instanceof String value) {
            return clean(value);
        }
        String headerRequestId = header(request, RequestIdFilter.REQUEST_ID_HEADER);
        return headerRequestId == null ? header(request, RequestIdFilter.CORRELATION_ID_HEADER) : headerRequestId;
    }

    private String header(HttpServletRequest request, String name) {
        return request == null ? null : clean(request.getHeader(name));
    }

    private String clean(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    private String csv(Object value) {
        if (value == null) {
            return "";
        }
        String text = String.valueOf(value);
        if (text.contains("\"") || text.contains(",") || text.contains("\r") || text.contains("\n")) {
            return "\"" + text.replace("\"", "\"\"") + "\"";
        }
        return text;
    }
}
