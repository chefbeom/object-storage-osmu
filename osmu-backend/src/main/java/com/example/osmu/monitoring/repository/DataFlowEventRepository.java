package com.example.osmu.monitoring.repository;

import com.example.osmu.monitoring.DataFlowEventFilter;
import com.example.osmu.monitoring.DataFlowEventRecord;
import com.example.osmu.monitoring.DataFlowDailyRollupPointResponse;
import com.example.osmu.monitoring.DataFlowMonthlyRollupPointResponse;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

public interface DataFlowEventRepository {

    List<DataFlowEventRecord> find(DataFlowEventFilter filter, int limit);

    List<DataFlowDailyRollupPointResponse> dailyRollup(DataFlowEventFilter filter, int limit);

    List<DataFlowDailyRollupPointResponse> refreshDailyRollup(DataFlowEventFilter filter, int limit);

    List<DataFlowDailyRollupPointResponse> materializedDailyRollup(DataFlowEventFilter filter, int limit);

    List<DataFlowMonthlyRollupPointResponse> monthlyRollup(DataFlowEventFilter filter, int limit);

    List<DataFlowMonthlyRollupPointResponse> materializedMonthlyRollup(DataFlowEventFilter filter, int limit);

    List<DataFlowMonthlyRollupPointResponse> refreshMonthlyRollup(DataFlowEventFilter filter, int limit);

    List<DataFlowMonthlyRollupPointResponse> storedMonthlyRollup(DataFlowEventFilter filter, int limit);

    long nextId();

    DataFlowEventRecord save(DataFlowEventRecord event);

    long countEvents();

    long countMaterializedRollups();

    long countMonthlyRollups();

    int deleteBefore(OffsetDateTime cutoff, int limit);

    int deleteMaterializedRollupsBefore(LocalDate cutoffDay, int limit);

    int deleteMonthlyRollupsBefore(LocalDate cutoffMonth, int limit);

    boolean isHealthy();
}
