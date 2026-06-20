package com.example.osmu.monitoring.repository;

import com.example.osmu.monitoring.DataFlowDailyRollupPointResponse;
import com.example.osmu.monitoring.DataFlowEventFilter;
import com.example.osmu.monitoring.DataFlowEventRecord;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryDataFlowEventRepository implements DataFlowEventRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final CopyOnWriteArrayList<DataFlowEventRecord> events = new CopyOnWriteArrayList<>();

    @Override
    public List<DataFlowEventRecord> find(DataFlowEventFilter filter, int limit) {
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        return events.stream()
                .filter(safeFilter::matches)
                .sorted(Comparator
                        .comparing(DataFlowEventRecord::createdAt)
                        .thenComparing(event -> event.id() == null ? 0L : event.id())
                        .reversed())
                .limit(Math.max(0, limit))
                .toList();
    }

    @Override
    public List<DataFlowDailyRollupPointResponse> dailyRollup(DataFlowEventFilter filter, int limit) {
        DataFlowEventFilter safeFilter = filter == null ? DataFlowEventFilter.empty() : filter;
        Map<String, DailyRollupAccumulator> rollups = new LinkedHashMap<>();
        events.stream()
                .filter(safeFilter::matches)
                .forEach(event -> {
                    LocalDate day = event.createdAt() == null
                            ? LocalDate.now(ZoneOffset.UTC)
                            : event.createdAt().withOffsetSameInstant(ZoneOffset.UTC).toLocalDate();
                    String bucketName = event.bucketName() == null || event.bucketName().isBlank()
                            ? "unknown"
                            : event.bucketName();
                    String source = lowerOrUnknown(event.source());
                    String operation = lowerOrUnknown(event.operation());
                    String key = day + "|" + bucketName + "|" + source + "|" + operation;
                    rollups.computeIfAbsent(
                            key,
                            ignored -> new DailyRollupAccumulator(day, bucketName, source, operation)
                    ).record(event);
                });
        return rollups.values().stream()
                .map(DailyRollupAccumulator::snapshot)
                .sorted(Comparator
                        .comparing(DataFlowDailyRollupPointResponse::day, Comparator.reverseOrder())
                        .thenComparing(Comparator.comparingLong(DataFlowDailyRollupPointResponse::totalCount).reversed())
                        .thenComparing(DataFlowDailyRollupPointResponse::bucketName)
                        .thenComparing(DataFlowDailyRollupPointResponse::source)
                        .thenComparing(DataFlowDailyRollupPointResponse::operation))
                .limit(Math.max(0, limit))
                .toList();
    }

    @Override
    public List<DataFlowDailyRollupPointResponse> refreshDailyRollup(DataFlowEventFilter filter, int limit) {
        return dailyRollup(filter, limit);
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public DataFlowEventRecord save(DataFlowEventRecord event) {
        DataFlowEventRecord saved = event;
        if (saved.id() == null) {
            saved = saved.withId(nextId());
        }
        if (saved.createdAt() == null) {
            saved = saved.withCreatedAt(OffsetDateTime.now());
        }
        events.add(saved);
        return saved;
    }

    @Override
    public int deleteBefore(OffsetDateTime cutoff, int limit) {
        if (cutoff == null || limit <= 0) {
            return 0;
        }
        List<DataFlowEventRecord> candidates = events.stream()
                .filter(event -> event.createdAt() != null && event.createdAt().isBefore(cutoff))
                .sorted(Comparator
                        .comparing(DataFlowEventRecord::createdAt)
                        .thenComparing(event -> event.id() == null ? 0L : event.id()))
                .limit(limit)
                .toList();
        events.removeAll(candidates);
        return candidates.size();
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private static String lowerOrUnknown(String value) {
        return value == null || value.isBlank() ? "unknown" : value.toLowerCase(Locale.ROOT);
    }

    private static final class DailyRollupAccumulator {
        private final LocalDate day;
        private final String bucketName;
        private final String source;
        private final String operation;
        private long successCount;
        private long failureCount;
        private long cancelCount;
        private long totalCount;
        private long uploadedBytes;
        private long downloadedBytes;
        private long copiedBytes;

        private DailyRollupAccumulator(LocalDate day, String bucketName, String source, String operation) {
            this.day = day;
            this.bucketName = bucketName;
            this.source = source;
            this.operation = operation;
        }

        private void record(DataFlowEventRecord event) {
            totalCount += 1;
            boolean success = "SUCCESS".equalsIgnoreCase(event.status());
            if (success) {
                successCount += 1;
                if ("UPLOAD".equalsIgnoreCase(event.eventType())) {
                    uploadedBytes += Math.max(0L, event.sizeBytes());
                }
                if ("DOWNLOAD".equalsIgnoreCase(event.eventType())) {
                    downloadedBytes += Math.max(0L, event.sizeBytes());
                }
                if ("COPY".equalsIgnoreCase(event.eventType())) {
                    copiedBytes += Math.max(0L, event.sizeBytes());
                }
            }
            if ("FAILURE".equalsIgnoreCase(event.eventType()) || "FAILED".equalsIgnoreCase(event.status())) {
                failureCount += 1;
            }
            if ("CANCEL".equalsIgnoreCase(event.eventType()) || "CANCELLED".equalsIgnoreCase(event.status())) {
                cancelCount += 1;
            }
        }

        private DataFlowDailyRollupPointResponse snapshot() {
            return new DataFlowDailyRollupPointResponse(
                    day,
                    bucketName,
                    source,
                    operation,
                    successCount,
                    failureCount,
                    cancelCount,
                    totalCount,
                    uploadedBytes,
                    downloadedBytes,
                    copiedBytes,
                    uploadedBytes + downloadedBytes + copiedBytes
            );
        }
    }
}
