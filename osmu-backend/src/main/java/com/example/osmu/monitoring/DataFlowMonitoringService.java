package com.example.osmu.monitoring;

import com.example.osmu.monitoring.repository.DataFlowEventRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class DataFlowMonitoringService {

    private static final int DEFAULT_RECENT_EVENT_LIMIT = 50;
    private static final int MAX_RECENT_EVENT_LIMIT = 500;
    private static final int SUMMARY_EVENT_SCAN_LIMIT = 10_000;
    private static final int TOP_BUCKET_LIMIT = 5;
    private static final int TREND_POINT_LIMIT = 24;

    private final MeterRegistry meterRegistry;
    private final DataFlowEventRepository eventRepository;

    public DataFlowMonitoringService(MeterRegistry meterRegistry, DataFlowEventRepository eventRepository) {
        this.meterRegistry = meterRegistry;
        this.eventRepository = eventRepository;
    }

    public void recordUpload(String bucketName, String objectKey, long sizeBytes, String actorId, String source) {
        long normalizedBytes = positiveBytes(sizeBytes);
        persistEvent("UPLOAD", "upload", "INGRESS", bucketName, objectKey, actorId, "SUCCESS", normalizedBytes, "Upload completed", source);
        incrementOperation("upload", "success", source, bucketName);
        incrementBytes("ingress", normalizedBytes, source, bucketName);
    }

    public void recordDownload(String bucketName, String objectKey, long sizeBytes, String actorId, String source) {
        long normalizedBytes = positiveBytes(sizeBytes);
        persistEvent("DOWNLOAD", "download", "EGRESS", bucketName, objectKey, actorId, "SUCCESS", normalizedBytes, "Download started", source);
        incrementOperation("download", "success", source, bucketName);
        incrementBytes("egress", normalizedBytes, source, bucketName);
    }

    public void recordCopy(String bucketName, String objectKey, long sizeBytes, String actorId, String source) {
        long normalizedBytes = positiveBytes(sizeBytes);
        persistEvent("COPY", "copy", "INTERNAL", bucketName, objectKey, actorId, "SUCCESS", normalizedBytes, "Object copied internally", source);
        incrementOperation("copy", "success", source, bucketName);
        incrementBytes("internal", normalizedBytes, source, bucketName);
    }

    public void recordList(String bucketName, String actorId, String source) {
        persistEvent("LIST", "list", "METADATA", bucketName, "", actorId, "SUCCESS", 0L, "Object list read", source);
        incrementOperation("list", "success", source, bucketName);
    }

    public void recordDelete(String bucketName, String objectKey, String actorId, String source) {
        persistEvent("DELETE", "delete", "METADATA", bucketName, objectKey, actorId, "SUCCESS", 0L, "Object delete requested", source);
        incrementOperation("delete", "success", source, bucketName);
    }

    public void recordCancel(String operation, String bucketName, String objectKey, String actorId, String source) {
        String normalizedOperation = normalizeOperation(operation);
        persistEvent("CANCEL", normalizedOperation, "CONTROL", bucketName, objectKey, actorId, "CANCELLED", 0L, "Transfer cancelled", source);
        incrementOperation(normalizedOperation, "cancelled", source, bucketName);
    }

    public void recordFailure(String operation, String bucketName, String objectKey, String actorId, String message, String source) {
        String normalizedOperation = normalizeOperation(operation);
        persistEvent("FAILURE", normalizedOperation, "CONTROL", bucketName, objectKey, actorId, "FAILED", 0L, safeMessage(message), source);
        incrementOperation(normalizedOperation, "failure", source, bucketName);
    }

    public DataFlowMonitoringResponse snapshot() {
        return snapshot(DataFlowEventFilter.empty(), DEFAULT_RECENT_EVENT_LIMIT);
    }

    public DataFlowMonitoringResponse snapshot(DataFlowEventFilter filter, int recentEventLimit) {
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        int normalizedRecentLimit = normalizeRecentLimit(recentEventLimit);
        List<DataFlowEventRecord> events = eventRepository.find(safeFilter, SUMMARY_EVENT_SCAN_LIMIT);
        SummaryAccumulator summary = new SummaryAccumulator();
        Map<String, BucketAccumulator> buckets = new LinkedHashMap<>();
        Map<String, TrendAccumulator> trends = new LinkedHashMap<>();

        for (DataFlowEventRecord event : events) {
            summary.record(event);
            buckets.computeIfAbsent(event.bucketName(), BucketAccumulator::new).record(event);
            OffsetDateTime bucketStartAt = trendBucketStart(event.createdAt());
            if (bucketStartAt != null) {
                String source = tagValue(event.source());
                String operation = normalizeOperation(event.operation());
                String key = bucketStartAt + "|" + source + "|" + operation;
                trends.computeIfAbsent(key, ignored -> new TrendAccumulator(bucketStartAt, source, operation)).record(event);
            }
        }

        List<DataFlowBucketMetricResponse> topBuckets = buckets.values().stream()
                .map(BucketAccumulator::snapshot)
                .sorted(Comparator
                        .comparingLong(DataFlowBucketMetricResponse::totalBytes)
                        .thenComparing(DataFlowBucketMetricResponse::lastEventAt, Comparator.nullsLast(Comparator.naturalOrder()))
                        .reversed())
                .limit(TOP_BUCKET_LIMIT)
                .toList();
        List<DataFlowTrendPointResponse> trendPoints = trends.values().stream()
                .map(TrendAccumulator::snapshot)
                .sorted(Comparator
                        .comparing(DataFlowTrendPointResponse::bucketStartAt, Comparator.reverseOrder())
                        .thenComparing(Comparator.comparingLong(DataFlowTrendPointResponse::totalCount).reversed())
                        .thenComparing(DataFlowTrendPointResponse::source)
                        .thenComparing(DataFlowTrendPointResponse::operation))
                .limit(TREND_POINT_LIMIT)
                .toList();
        List<DataFlowRecentEventResponse> recentEvents = events.stream()
                .limit(normalizedRecentLimit)
                .map(DataFlowEventRecord::toRecentEvent)
                .toList();

        return new DataFlowMonitoringResponse(
                new DataFlowTrafficSummaryResponse(
                        summary.uploadedBytes,
                        summary.downloadedBytes,
                        summary.copiedBytes,
                        summary.uploadedBytes + summary.downloadedBytes + summary.copiedBytes,
                        summary.uploadedBytes,
                        summary.downloadedBytes,
                        summary.copiedBytes
                ),
                new DataFlowOperationSummaryResponse(
                        summary.uploadCount,
                        summary.downloadCount,
                        summary.copyCount,
                        summary.listCount,
                        summary.deleteCount,
                        summary.cancelCount,
                        summary.failureCount,
                        events.size()
                ),
                topBuckets,
                trendPoints,
                recentEvents,
                OffsetDateTime.now()
        );
    }

    public String exportCsv(DataFlowEventFilter filter, int limit) {
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        int normalizedLimit = normalizeRecentLimit(limit);
        List<DataFlowEventRecord> events = eventRepository.find(safeFilter, normalizedLimit);
        StringBuilder csv = new StringBuilder("createdAt,eventType,operation,direction,bucketName,objectKey,actorId,status,sizeBytes,source,message\n");
        for (DataFlowEventRecord event : events) {
            appendCsvRow(
                    csv,
                    event.createdAt(),
                    event.eventType(),
                    event.operation(),
                    event.direction(),
                    event.bucketName(),
                    event.objectKey(),
                    event.actorId(),
                    event.status(),
                    event.sizeBytes(),
                    event.source(),
                    event.message()
            );
        }
        return csv.toString();
    }

    private void persistEvent(
            String eventType,
            String operation,
            String direction,
            String bucketName,
            String objectKey,
            String actorId,
            String status,
            long sizeBytes,
            String message,
            String source
    ) {
        eventRepository.save(new DataFlowEventRecord(
                null,
                uppercase(eventType),
                normalizeOperation(operation),
                uppercase(direction),
                normalizeBucket(bucketName),
                objectKey == null ? "" : objectKey,
                actorId == null ? "" : actorId,
                uppercase(status),
                positiveBytes(sizeBytes),
                safeMessage(message),
                tagValue(source),
                OffsetDateTime.now()
        ));
    }

    private void incrementOperation(String operation, String status, String source, String bucketName) {
        Counter.builder("osmu.data.flow.operations")
                .description("OSMU data flow operations")
                .tag("operation", normalizeOperation(operation))
                .tag("status", tagValue(status))
                .tag("source", tagValue(source))
                .tag("bucket", tagValue(bucketName))
                .register(meterRegistry)
                .increment();
    }

    private void incrementBytes(String direction, long bytes, String source, String bucketName) {
        if (bytes <= 0) {
            return;
        }
        Counter.builder("osmu.data.flow.bytes")
                .description("OSMU data flow bytes")
                .baseUnit("bytes")
                .tag("direction", tagValue(direction))
                .tag("source", tagValue(source))
                .tag("bucket", tagValue(bucketName))
                .register(meterRegistry)
                .increment(bytes);
    }

    private int normalizeRecentLimit(int limit) {
        if (limit <= 0) {
            return DEFAULT_RECENT_EVENT_LIMIT;
        }
        return Math.min(MAX_RECENT_EVENT_LIMIT, limit);
    }

    private long positiveBytes(long sizeBytes) {
        return Math.max(0L, sizeBytes);
    }

    private String normalizeBucket(String bucketName) {
        return bucketName == null || bucketName.isBlank() ? "unknown" : bucketName;
    }

    private String normalizeOperation(String operation) {
        return operation == null || operation.isBlank() ? "unknown" : operation.toLowerCase(Locale.ROOT);
    }

    private String tagValue(String value) {
        return value == null || value.isBlank() ? "unknown" : value.toLowerCase(Locale.ROOT);
    }

    private String uppercase(String value) {
        return value == null || value.isBlank() ? "UNKNOWN" : value.toUpperCase(Locale.ROOT);
    }

    private OffsetDateTime trendBucketStart(OffsetDateTime createdAt) {
        if (createdAt == null) {
            return null;
        }
        return createdAt.withOffsetSameInstant(ZoneOffset.UTC)
                .withMinute(0)
                .withSecond(0)
                .withNano(0);
    }

    private String safeMessage(String message) {
        if (message == null || message.isBlank()) {
            return "";
        }
        return message.length() <= 240 ? message : message.substring(0, 240);
    }

    private void appendCsvRow(StringBuilder csv, Object... values) {
        for (int index = 0; index < values.length; index += 1) {
            if (index > 0) {
                csv.append(',');
            }
            csv.append(csvCell(values[index]));
        }
        csv.append('\n');
    }

    private String csvCell(Object value) {
        String text = value == null ? "" : String.valueOf(value);
        return "\"" + text.replace("\"", "\"\"").replace("\r", " ").replace("\n", " ") + "\"";
    }

    private static final class SummaryAccumulator {
        private long uploadedBytes;
        private long downloadedBytes;
        private long copiedBytes;
        private long uploadCount;
        private long downloadCount;
        private long copyCount;
        private long listCount;
        private long deleteCount;
        private long cancelCount;
        private long failureCount;

        private void record(DataFlowEventRecord event) {
            boolean success = "SUCCESS".equalsIgnoreCase(event.status());
            if ("UPLOAD".equalsIgnoreCase(event.eventType()) && success) {
                uploadedBytes += event.sizeBytes();
                uploadCount += 1;
            }
            if ("DOWNLOAD".equalsIgnoreCase(event.eventType()) && success) {
                downloadedBytes += event.sizeBytes();
                downloadCount += 1;
            }
            if ("COPY".equalsIgnoreCase(event.eventType()) && success) {
                copiedBytes += event.sizeBytes();
                copyCount += 1;
            }
            if ("LIST".equalsIgnoreCase(event.eventType()) && success) {
                listCount += 1;
            }
            if ("DELETE".equalsIgnoreCase(event.eventType()) && success) {
                deleteCount += 1;
            }
            if ("CANCEL".equalsIgnoreCase(event.eventType())) {
                cancelCount += 1;
            }
            if ("FAILURE".equalsIgnoreCase(event.eventType()) || "FAILED".equalsIgnoreCase(event.status())) {
                failureCount += 1;
            }
        }
    }

    private static final class BucketAccumulator {
        private final String bucketName;
        private long uploadedBytes;
        private long downloadedBytes;
        private long copiedBytes;
        private long uploadCount;
        private long downloadCount;
        private long copyCount;
        private long listCount;
        private long deleteCount;
        private long cancelCount;
        private long failureCount;
        private OffsetDateTime lastEventAt;

        private BucketAccumulator(String bucketName) {
            this.bucketName = bucketName;
        }

        private void record(DataFlowEventRecord event) {
            boolean success = "SUCCESS".equalsIgnoreCase(event.status());
            if ("UPLOAD".equalsIgnoreCase(event.eventType()) && success) {
                uploadedBytes += event.sizeBytes();
                uploadCount += 1;
            }
            if ("DOWNLOAD".equalsIgnoreCase(event.eventType()) && success) {
                downloadedBytes += event.sizeBytes();
                downloadCount += 1;
            }
            if ("COPY".equalsIgnoreCase(event.eventType()) && success) {
                copiedBytes += event.sizeBytes();
                copyCount += 1;
            }
            if ("LIST".equalsIgnoreCase(event.eventType()) && success) {
                listCount += 1;
            }
            if ("DELETE".equalsIgnoreCase(event.eventType()) && success) {
                deleteCount += 1;
            }
            if ("CANCEL".equalsIgnoreCase(event.eventType())) {
                cancelCount += 1;
            }
            if ("FAILURE".equalsIgnoreCase(event.eventType()) || "FAILED".equalsIgnoreCase(event.status())) {
                failureCount += 1;
            }
            if (lastEventAt == null || event.createdAt().isAfter(lastEventAt)) {
                lastEventAt = event.createdAt();
            }
        }

        private DataFlowBucketMetricResponse snapshot() {
            return new DataFlowBucketMetricResponse(
                    bucketName,
                    uploadedBytes,
                    downloadedBytes,
                    copiedBytes,
                    uploadedBytes + downloadedBytes + copiedBytes,
                    uploadCount,
                    downloadCount,
                    copyCount,
                    listCount,
                    deleteCount,
                    cancelCount,
                    failureCount,
                    lastEventAt
            );
        }
    }

    private static final class TrendAccumulator {
        private final OffsetDateTime bucketStartAt;
        private final String source;
        private final String operation;
        private long successCount;
        private long failureCount;
        private long cancelCount;
        private long totalCount;
        private long bytes;

        private TrendAccumulator(OffsetDateTime bucketStartAt, String source, String operation) {
            this.bucketStartAt = bucketStartAt;
            this.source = source;
            this.operation = operation;
        }

        private void record(DataFlowEventRecord event) {
            totalCount += 1;
            if ("SUCCESS".equalsIgnoreCase(event.status())) {
                successCount += 1;
                bytes += Math.max(0L, event.sizeBytes());
            }
            if ("CANCEL".equalsIgnoreCase(event.eventType()) || "CANCELLED".equalsIgnoreCase(event.status())) {
                cancelCount += 1;
            }
            if ("FAILURE".equalsIgnoreCase(event.eventType()) || "FAILED".equalsIgnoreCase(event.status())) {
                failureCount += 1;
            }
        }

        private DataFlowTrendPointResponse snapshot() {
            return new DataFlowTrendPointResponse(
                    bucketStartAt,
                    source,
                    operation,
                    successCount,
                    failureCount,
                    cancelCount,
                    totalCount,
                    bytes
            );
        }
    }
}
