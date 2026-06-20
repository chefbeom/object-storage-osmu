package com.example.osmu.monitoring.repository;

import com.example.osmu.monitoring.DataFlowEventFilter;
import com.example.osmu.monitoring.DataFlowEventRecord;
import com.example.osmu.monitoring.DataFlowDailyRollupPointResponse;
import java.time.OffsetDateTime;
import java.util.List;

public interface DataFlowEventRepository {

    List<DataFlowEventRecord> find(DataFlowEventFilter filter, int limit);

    List<DataFlowDailyRollupPointResponse> dailyRollup(DataFlowEventFilter filter, int limit);

    List<DataFlowDailyRollupPointResponse> refreshDailyRollup(DataFlowEventFilter filter, int limit);

    long nextId();

    DataFlowEventRecord save(DataFlowEventRecord event);

    int deleteBefore(OffsetDateTime cutoff, int limit);

    boolean isHealthy();
}
