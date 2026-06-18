package com.example.osmu.monitoring.repository;

import com.example.osmu.monitoring.DataFlowEventFilter;
import com.example.osmu.monitoring.DataFlowEventRecord;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
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
    public boolean isHealthy() {
        return true;
    }
}
