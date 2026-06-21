package com.example.osmu.monitoring;

import com.example.osmu.monitoring.repository.DataFlowEventRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class DataFlowMonitoringService {

    private static final int DEFAULT_RECENT_EVENT_LIMIT = 50;
    private static final int MAX_RECENT_EVENT_LIMIT = 500;
    private static final int SUMMARY_EVENT_SCAN_LIMIT = 10_000;
    private static final int TOP_BUCKET_LIMIT = 5;
    private static final int TREND_POINT_LIMIT = 24;
    private static final int DEFAULT_DAILY_ROLLUP_DAYS = 30;
    private static final int MAX_DAILY_ROLLUP_DAYS = 366;
    private static final int DEFAULT_DAILY_ROLLUP_LIMIT = 200;
    private static final int MAX_DAILY_ROLLUP_LIMIT = 1000;
    private static final int DEFAULT_MONTHLY_ROLLUP_MONTHS = 12;
    private static final int MAX_MONTHLY_ROLLUP_MONTHS = 60;
    private static final int DEFAULT_MONTHLY_ROLLUP_LIMIT = 200;
    private static final int MAX_MONTHLY_ROLLUP_LIMIT = 1000;

    private final MeterRegistry meterRegistry;
    private final DataFlowEventRepository eventRepository;
    private final String metadataMode;

    public DataFlowMonitoringService(
            MeterRegistry meterRegistry,
            DataFlowEventRepository eventRepository,
            @Value("${osmu.metadata.mode:in-memory}") String metadataMode
    ) {
        this.meterRegistry = meterRegistry;
        this.eventRepository = eventRepository;
        this.metadataMode = metadataMode == null || metadataMode.isBlank() ? "in-memory" : metadataMode;
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

    public DataFlowStorageStatusResponse storageStatus() {
        OffsetDateTime generatedAt = OffsetDateTime.now();
        boolean repositoryHealthy = eventRepository.isHealthy();
        long eventRowCount = safeCount(eventRepository::countEvents);
        long dailyRollupRowCount = safeCount(eventRepository::countMaterializedRollups);
        long monthlyRollupRowCount = safeCount(eventRepository::countMonthlyRollups);
        boolean aggregateStoreReady = repositoryHealthy
                && eventRowCount >= 0
                && dailyRollupRowCount >= 0
                && monthlyRollupRowCount >= 0;
        boolean durableMetadata = "mariadb".equalsIgnoreCase(metadataMode);
        String readiness;
        if (!repositoryHealthy) {
            readiness = "UNHEALTHY";
        } else if (!durableMetadata) {
            readiness = "DEMO_ONLY";
        } else if (aggregateStoreReady) {
            readiness = "AGGREGATE_STORE_READY";
        } else {
            readiness = "DETAIL_SCAN_ONLY";
        }
        return new DataFlowStorageStatusResponse(
                "DATA_FLOW_STORAGE_STATUS",
                metadataMode,
                repositoryHealthy,
                eventRowCount,
                dailyRollupRowCount,
                monthlyRollupRowCount,
                SUMMARY_EVENT_SCAN_LIMIT,
                MAX_DAILY_ROLLUP_DAYS,
                MAX_MONTHLY_ROLLUP_MONTHS,
                aggregateStoreReady,
                false,
                readiness,
                generatedAt,
                "OSMU data-flow storage status for detailed events, materialized daily rollups, and stored monthly rollups. Partitioned or external time-series storage is not enabled in this build."
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

    public DataFlowDailyRollupResponse dailyRollup(DataFlowEventFilter filter, Integer days, Integer limit) {
        OffsetDateTime generatedAt = OffsetDateTime.now();
        int normalizedDays = normalizeDailyRollupDays(days);
        int normalizedLimit = normalizeDailyRollupLimit(limit);
        DataFlowEventFilter boundedFilter = boundedDailyRollupFilter(filter, normalizedDays, generatedAt);
        List<DataFlowDailyRollupPointResponse> points = eventRepository.dailyRollup(boundedFilter, normalizedLimit);
        return new DataFlowDailyRollupResponse(
                "DATA_FLOW_DAILY_ROLLUP",
                "UTC_DAY",
                normalizedDays,
                normalizedLimit,
                points.size(),
                points,
                generatedAt,
                "ADMIN-only data-flow analytics rollup. Query filters are identical to the detailed data-flow monitoring endpoint.",
                "Aggregates persisted data_flow_events in MariaDB mode and runtime events in in-memory mode. A future partitioned or time-series repository can replace this backing store without changing the API contract.",
                "This is an OSMU operations and chargeback planning rollup, not AWS billing parity."
        );
    }

    public DataFlowDailyRollupMaterializationResponse materializeDailyRollup(DataFlowEventFilter filter, Integer days, Integer limit) {
        OffsetDateTime generatedAt = OffsetDateTime.now();
        int normalizedDays = normalizeDailyRollupDays(days);
        int normalizedLimit = normalizeDailyRollupLimit(limit);
        DataFlowEventFilter boundedFilter = boundedDailyRollupFilter(filter, normalizedDays, generatedAt);
        List<DataFlowDailyRollupPointResponse> points = eventRepository.refreshDailyRollup(boundedFilter, normalizedLimit);
        return new DataFlowDailyRollupMaterializationResponse(
                "DATA_FLOW_DAILY_ROLLUP_MATERIALIZATION",
                "UTC_DAY",
                normalizedDays,
                normalizedLimit,
                points.size(),
                points.size(),
                points,
                generatedAt,
                "ADMIN-only data-flow rollup materialization. Query filters are identical to the daily rollup endpoint.",
                "Refreshes data_flow_daily_rollups in MariaDB mode and returns computed rollup points in in-memory mode. This is the handoff point for a future partitioned or time-series repository.",
                "Materialization stores aggregate rows only; object keys, raw event messages, and AWS billing parity fields are not stored."
        );
    }

    public DataFlowDailyRollupResponse materializedDailyRollup(DataFlowEventFilter filter, Integer days, Integer limit) {
        OffsetDateTime generatedAt = OffsetDateTime.now();
        int normalizedDays = normalizeDailyRollupDays(days);
        int normalizedLimit = normalizeDailyRollupLimit(limit);
        DataFlowEventFilter boundedFilter = boundedDailyRollupFilter(filter, normalizedDays, generatedAt);
        List<DataFlowDailyRollupPointResponse> points = eventRepository.materializedDailyRollup(boundedFilter, normalizedLimit);
        return new DataFlowDailyRollupResponse(
                "DATA_FLOW_DAILY_ROLLUP_MATERIALIZED",
                "UTC_DAY",
                normalizedDays,
                normalizedLimit,
                points.size(),
                points,
                generatedAt,
                "ADMIN-only materialized data-flow analytics rollup. Query filters are identical to the daily rollup endpoint.",
                "Reads aggregate-only rows from data_flow_daily_rollups in MariaDB mode and from the refreshed in-memory store in local mode.",
                "This reads OSMU materialized operations analytics rows; it does not expose object keys, raw event messages, or AWS billing parity fields."
        );
    }

    public String exportDailyRollupCsv(DataFlowEventFilter filter, Integer days, Integer limit) {
        return dailyRollupCsv(dailyRollup(filter, days, limit));
    }

    public String exportMaterializedDailyRollupCsv(DataFlowEventFilter filter, Integer days, Integer limit) {
        return dailyRollupCsv(materializedDailyRollup(filter, days, limit));
    }

    public DataFlowMonthlyRollupResponse monthlyRollup(
            DataFlowEventFilter filter,
            Integer months,
            Integer limit,
            boolean materialized
    ) {
        OffsetDateTime generatedAt = OffsetDateTime.now();
        int normalizedMonths = normalizeMonthlyRollupMonths(months);
        int normalizedLimit = normalizeMonthlyRollupLimit(limit);
        DataFlowEventFilter boundedFilter = boundedMonthlyRollupFilter(filter, normalizedMonths, generatedAt);
        List<DataFlowMonthlyRollupPointResponse> points = materialized
                ? eventRepository.materializedMonthlyRollup(boundedFilter, normalizedLimit)
                : eventRepository.monthlyRollup(boundedFilter, normalizedLimit);
        return new DataFlowMonthlyRollupResponse(
                materialized ? "DATA_FLOW_MONTHLY_ROLLUP_MATERIALIZED" : "DATA_FLOW_MONTHLY_ROLLUP",
                materialized ? "DATA_FLOW_DAILY_ROLLUP_MATERIALIZED" : "DATA_FLOW_EVENTS",
                "UTC_MONTH",
                normalizedMonths,
                normalizedLimit,
                points.size(),
                points,
                generatedAt,
                "ADMIN-only long-term data-flow analytics rollup. Query filters are identical to the detailed data-flow monitoring endpoint.",
                materialized
                        ? "Aggregates stored data_flow_daily_rollups rows into UTC months for long-term operations analytics."
                        : "Aggregates persisted data_flow_events in MariaDB mode and runtime events in in-memory mode into UTC months.",
                "This is an OSMU operations analytics rollup, not AWS billing parity; object keys and raw event messages are not returned."
        );
    }

    public String exportMonthlyRollupCsv(DataFlowEventFilter filter, Integer months, Integer limit, boolean materialized) {
        return monthlyRollupCsv(monthlyRollup(filter, months, limit, materialized));
    }

    public DataFlowMonthlyRollupMaterializationResponse materializeMonthlyRollup(
            DataFlowEventFilter filter,
            Integer months,
            Integer limit
    ) {
        OffsetDateTime generatedAt = OffsetDateTime.now();
        int normalizedMonths = normalizeMonthlyRollupMonths(months);
        int normalizedLimit = normalizeMonthlyRollupLimit(limit);
        DataFlowEventFilter boundedFilter = boundedMonthlyRollupFilter(filter, normalizedMonths, generatedAt);
        List<DataFlowMonthlyRollupPointResponse> points = eventRepository.refreshMonthlyRollup(boundedFilter, normalizedLimit);
        return new DataFlowMonthlyRollupMaterializationResponse(
                "DATA_FLOW_MONTHLY_ROLLUP_MATERIALIZATION",
                "DATA_FLOW_DAILY_ROLLUP_MATERIALIZED",
                "UTC_MONTH",
                normalizedMonths,
                normalizedLimit,
                points.size(),
                points.size(),
                points,
                generatedAt,
                "ADMIN-only monthly data-flow rollup materialization. Query filters are identical to the monthly rollup endpoint.",
                "Compacts aggregate-only data_flow_daily_rollups rows into data_flow_monthly_rollups for long-window operations analytics.",
                "Monthly materialization stores aggregate rows only; object keys, raw event messages, and AWS billing parity fields are not stored."
        );
    }

    public DataFlowMonthlyRollupResponse storedMonthlyRollup(DataFlowEventFilter filter, Integer months, Integer limit) {
        OffsetDateTime generatedAt = OffsetDateTime.now();
        int normalizedMonths = normalizeMonthlyRollupMonths(months);
        int normalizedLimit = normalizeMonthlyRollupLimit(limit);
        DataFlowEventFilter boundedFilter = boundedMonthlyRollupFilter(filter, normalizedMonths, generatedAt);
        List<DataFlowMonthlyRollupPointResponse> points = eventRepository.storedMonthlyRollup(boundedFilter, normalizedLimit);
        return new DataFlowMonthlyRollupResponse(
                "DATA_FLOW_MONTHLY_ROLLUP_STORED",
                "DATA_FLOW_MONTHLY_ROLLUPS",
                "UTC_MONTH",
                normalizedMonths,
                normalizedLimit,
                points.size(),
                points,
                generatedAt,
                "ADMIN-only stored monthly data-flow analytics rollup. Query filters are identical to the monthly rollup endpoint.",
                "Reads aggregate-only rows from data_flow_monthly_rollups in MariaDB mode and from the refreshed in-memory monthly store in local mode.",
                "This reads OSMU stored monthly operations analytics rows; it does not expose object keys, raw event messages, or AWS billing parity fields."
        );
    }

    public String exportStoredMonthlyRollupCsv(DataFlowEventFilter filter, Integer months, Integer limit) {
        return monthlyRollupCsv(storedMonthlyRollup(filter, months, limit));
    }

    private String monthlyRollupCsv(DataFlowMonthlyRollupResponse rollup) {
        StringBuilder csv = new StringBuilder("month,bucketName,source,operation,successCount,failureCount,cancelCount,totalCount,uploadedBytes,downloadedBytes,copiedBytes,totalBytes\n");
        for (DataFlowMonthlyRollupPointResponse point : rollup.points()) {
            appendCsvRow(
                    csv,
                    point.month(),
                    point.bucketName(),
                    point.source(),
                    point.operation(),
                    point.successCount(),
                    point.failureCount(),
                    point.cancelCount(),
                    point.totalCount(),
                    point.uploadedBytes(),
                    point.downloadedBytes(),
                    point.copiedBytes(),
                    point.totalBytes()
            );
        }
        return csv.toString();
    }

    private String dailyRollupCsv(DataFlowDailyRollupResponse rollup) {
        StringBuilder csv = new StringBuilder("day,bucketName,source,operation,successCount,failureCount,cancelCount,totalCount,uploadedBytes,downloadedBytes,copiedBytes,totalBytes\n");
        for (DataFlowDailyRollupPointResponse point : rollup.points()) {
            appendCsvRow(
                    csv,
                    point.day(),
                    point.bucketName(),
                    point.source(),
                    point.operation(),
                    point.successCount(),
                    point.failureCount(),
                    point.cancelCount(),
                    point.totalCount(),
                    point.uploadedBytes(),
                    point.downloadedBytes(),
                    point.copiedBytes(),
                    point.totalBytes()
            );
        }
        return csv.toString();
    }

    private DataFlowEventFilter boundedDailyRollupFilter(DataFlowEventFilter filter, int normalizedDays, OffsetDateTime generatedAt) {
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        if (safeFilter.from() != null) {
            return safeFilter;
        }
        return new DataFlowEventFilter(
                safeFilter.bucketName(),
                safeFilter.actorId(),
                safeFilter.source(),
                safeFilter.operation(),
                safeFilter.status(),
                generatedAt.minusDays(normalizedDays - 1L).toLocalDate().atStartOfDay().atOffset(ZoneOffset.UTC),
                safeFilter.to()
        );
    }

    private DataFlowEventFilter boundedMonthlyRollupFilter(DataFlowEventFilter filter, int normalizedMonths, OffsetDateTime generatedAt) {
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        if (safeFilter.from() != null) {
            return safeFilter;
        }
        LocalDate startDay = YearMonth
                .from(generatedAt.withOffsetSameInstant(ZoneOffset.UTC))
                .minusMonths(normalizedMonths - 1L)
                .atDay(1);
        return new DataFlowEventFilter(
                safeFilter.bucketName(),
                safeFilter.actorId(),
                safeFilter.source(),
                safeFilter.operation(),
                safeFilter.status(),
                startDay.atStartOfDay().atOffset(ZoneOffset.UTC),
                safeFilter.to()
        );
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

    private int normalizeDailyRollupDays(Integer days) {
        if (days == null || days <= 0) {
            return DEFAULT_DAILY_ROLLUP_DAYS;
        }
        return Math.min(MAX_DAILY_ROLLUP_DAYS, days);
    }

    private int normalizeDailyRollupLimit(Integer limit) {
        if (limit == null || limit <= 0) {
            return DEFAULT_DAILY_ROLLUP_LIMIT;
        }
        return Math.min(MAX_DAILY_ROLLUP_LIMIT, limit);
    }

    private int normalizeMonthlyRollupMonths(Integer months) {
        if (months == null || months <= 0) {
            return DEFAULT_MONTHLY_ROLLUP_MONTHS;
        }
        return Math.min(MAX_MONTHLY_ROLLUP_MONTHS, months);
    }

    private int normalizeMonthlyRollupLimit(Integer limit) {
        if (limit == null || limit <= 0) {
            return DEFAULT_MONTHLY_ROLLUP_LIMIT;
        }
        return Math.min(MAX_MONTHLY_ROLLUP_LIMIT, limit);
    }

    private long positiveBytes(long sizeBytes) {
        return Math.max(0L, sizeBytes);
    }

    private long safeCount(CountSupplier supplier) {
        try {
            return supplier.count();
        } catch (RuntimeException ignored) {
            return -1L;
        }
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

    @FunctionalInterface
    private interface CountSupplier {
        long count();
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
