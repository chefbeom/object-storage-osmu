package com.example.osmu.monitoring;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.monitoring.repository.InMemoryDataFlowEventRepository;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class DataFlowMonitoringServiceTest {

    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();
    private final InMemoryDataFlowEventRepository eventRepository = new InMemoryDataFlowEventRepository();
    private final DataFlowMonitoringService service = new DataFlowMonitoringService(meterRegistry, eventRepository, "in-memory");

    @Test
    void recordsTrafficOperationsBucketsAndRecentEvents() {
        service.recordUpload("media", "a.bin", 1024L, "admin", "REST");
        service.recordDownload("media", "a.bin", 512L, "admin", "S3");
        service.recordCopy("media", "a-copy.bin", 256L, "admin", "S3-COPY");
        service.recordList("media", "admin", "REST");
        service.recordDelete("media", "a.bin", "admin", "REST");
        service.recordCancel("upload", "media", "b.bin", "admin", "REST");
        service.recordFailure("download", "media", "c.bin", "admin", "broken pipe", "S3");

        DataFlowMonitoringResponse snapshot = service.snapshot();

        assertThat(snapshot.traffic().uploadedBytes()).isEqualTo(1024L);
        assertThat(snapshot.traffic().downloadedBytes()).isEqualTo(512L);
        assertThat(snapshot.traffic().copiedBytes()).isEqualTo(256L);
        assertThat(snapshot.traffic().totalBytes()).isEqualTo(1792L);
        assertThat(snapshot.traffic().ingressBytes()).isEqualTo(1024L);
        assertThat(snapshot.traffic().egressBytes()).isEqualTo(512L);
        assertThat(snapshot.traffic().internalBytes()).isEqualTo(256L);
        assertThat(snapshot.operations().uploadCount()).isEqualTo(1L);
        assertThat(snapshot.operations().downloadCount()).isEqualTo(1L);
        assertThat(snapshot.operations().copyCount()).isEqualTo(1L);
        assertThat(snapshot.operations().listCount()).isEqualTo(1L);
        assertThat(snapshot.operations().deleteCount()).isEqualTo(1L);
        assertThat(snapshot.operations().cancelCount()).isEqualTo(1L);
        assertThat(snapshot.operations().failureCount()).isEqualTo(1L);
        assertThat(snapshot.topBuckets()).hasSize(1);
        assertThat(snapshot.topBuckets().get(0).bucketName()).isEqualTo("media");
        assertThat(snapshot.topBuckets().get(0).copiedBytes()).isEqualTo(256L);
        assertThat(snapshot.topBuckets().get(0).copyCount()).isEqualTo(1L);
        assertThat(snapshot.trendPoints()).extracting(DataFlowTrendPointResponse::operation)
                .contains("upload", "download", "copy", "list", "delete");
        assertThat(snapshot.trendPoints()).anySatisfy(point -> {
            assertThat(point.source()).isEqualTo("rest");
            assertThat(point.operation()).isEqualTo("upload");
            assertThat(point.successCount()).isEqualTo(1L);
            assertThat(point.bytes()).isEqualTo(1024L);
        });
        assertThat(snapshot.recentEvents()).hasSize(7);
        assertThat(snapshot.recentEvents().get(0).eventType()).isEqualTo("FAILURE");
        assertThat(meterRegistry.find("osmu.data.flow.operations").tag("operation", "upload").tag("status", "success").counter().count()).isEqualTo(1.0);
        assertThat(meterRegistry.find("osmu.data.flow.operations").tag("operation", "upload").tag("bucket", "media").counter().count()).isEqualTo(1.0);
        assertThat(meterRegistry.find("osmu.data.flow.operations").tag("operation", "copy").tag("source", "s3-copy").counter().count()).isEqualTo(1.0);
        assertThat(meterRegistry.find("osmu.data.flow.bytes").tag("direction", "ingress").tag("bucket", "media").counter().count()).isEqualTo(1024.0);
        assertThat(meterRegistry.find("osmu.data.flow.bytes").tag("direction", "internal").tag("bucket", "media").counter().count()).isEqualTo(256.0);
    }

    @Test
    void filtersSnapshotByBucketActorSourceOperationStatusAndTime() {
        OffsetDateTime before = OffsetDateTime.now().minusSeconds(1);
        service.recordUpload("media", "a.bin", 1024L, "admin", "REST");
        service.recordDownload("archive", "b.bin", 512L, "developer", "S3");
        OffsetDateTime after = OffsetDateTime.now().plusSeconds(1);

        DataFlowMonitoringResponse snapshot = service.snapshot(
                new DataFlowEventFilter("media", "admin", "rest", "upload", "SUCCESS", before, after),
                10
        );

        assertThat(snapshot.traffic().uploadedBytes()).isEqualTo(1024L);
        assertThat(snapshot.traffic().downloadedBytes()).isZero();
        assertThat(snapshot.operations().uploadCount()).isEqualTo(1L);
        assertThat(snapshot.operations().totalCount()).isEqualTo(1L);
        assertThat(snapshot.topBuckets()).extracting(DataFlowBucketMetricResponse::bucketName).containsExactly("media");
        assertThat(snapshot.trendPoints()).hasSize(1);
        assertThat(snapshot.trendPoints().get(0).operation()).isEqualTo("upload");
        assertThat(snapshot.recentEvents()).hasSize(1);
        assertThat(snapshot.recentEvents().get(0).source()).isEqualTo("rest");
    }

    @Test
    void exportsFilteredEventsAsCsv() {
        service.recordFailure("download", "media", "raw,\"bad\".csv", "admin", "line one\nline two", "REST");
        service.recordUpload("archive", "ignored.bin", 1024L, "admin", "REST");

        String csv = service.exportCsv(new DataFlowEventFilter("media", "admin", "rest", "download", "FAILED", null, null), 10);

        assertThat(csv).startsWith("createdAt,eventType,operation,direction,bucketName,objectKey,actorId,status,sizeBytes,source,message\n");
        assertThat(csv).contains("\"FAILURE\",\"download\",\"CONTROL\",\"media\",\"raw,\"\"bad\"\".csv\",\"admin\",\"FAILED\",\"0\",\"rest\",\"line one line two\"");
        assertThat(csv).doesNotContain("ignored.bin");
    }

    @Test
    void buildsDailyRollupForLongTermAnalytics() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "admin", "SUCCESS", 1024L, "rest", now.minusHours(2)));
        eventRepository.save(event("DOWNLOAD", "download", "EGRESS", "media", "admin", "SUCCESS", 512L, "s3", now.minusHours(1)));
        eventRepository.save(event("FAILURE", "download", "CONTROL", "media", "admin", "FAILED", 0L, "rest", now.minusMinutes(30)));
        eventRepository.save(event("COPY", "copy", "INTERNAL", "media", "admin", "SUCCESS", 256L, "rest", now.minusDays(1)));
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "archive", "admin", "SUCCESS", 2048L, "rest", now.minusHours(1)));

        DataFlowDailyRollupResponse rollup = service.dailyRollup(
                new DataFlowEventFilter("media", null, null, null, null, now.minusDays(2), now.plusDays(1)),
                30,
                10
        );

        assertThat(rollup.mode()).isEqualTo("DATA_FLOW_DAILY_ROLLUP");
        assertThat(rollup.granularity()).isEqualTo("UTC_DAY");
        assertThat(rollup.dayWindow()).isEqualTo(30);
        assertThat(rollup.pointLimit()).isEqualTo(10);
        assertThat(rollup.storagePolicy()).contains("data_flow_events");
        assertThat(rollup.points()).hasSize(4);
        assertThat(rollup.points()).anySatisfy(point -> {
            assertThat(point.day()).isEqualTo(now.toLocalDate());
            assertThat(point.bucketName()).isEqualTo("media");
            assertThat(point.source()).isEqualTo("rest");
            assertThat(point.operation()).isEqualTo("upload");
            assertThat(point.successCount()).isEqualTo(1L);
            assertThat(point.uploadedBytes()).isEqualTo(1024L);
            assertThat(point.totalBytes()).isEqualTo(1024L);
        });
        assertThat(rollup.points()).anySatisfy(point -> {
            assertThat(point.operation()).isEqualTo("download");
            assertThat(point.failureCount()).isEqualTo(1L);
            assertThat(point.totalCount()).isEqualTo(1L);
        });
        assertThat(rollup.points()).noneSatisfy(point -> assertThat(point.bucketName()).isEqualTo("archive"));
    }

    @Test
    void exportsDailyRollupAsCsvWithoutObjectKeysOrMessages() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "admin", "SUCCESS", 1024L, "rest", now.minusHours(2)));
        eventRepository.save(event("FAILURE", "download", "CONTROL", "media", "admin", "FAILED", 0L, "rest", now.minusMinutes(30)));
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "archive", "admin", "SUCCESS", 2048L, "rest", now.minusHours(1)));

        String csv = service.exportDailyRollupCsv(
                new DataFlowEventFilter("media", null, null, null, null, now.minusDays(1), now.plusDays(1)),
                30,
                10
        );

        assertThat(csv).startsWith("day,bucketName,source,operation,successCount,failureCount,cancelCount,totalCount,uploadedBytes,downloadedBytes,copiedBytes,totalBytes\n");
        assertThat(csv).contains("\"media\",\"rest\",\"upload\",\"1\",\"0\",\"0\",\"1\",\"1024\",\"0\",\"0\",\"1024\"");
        assertThat(csv).contains("\"media\",\"rest\",\"download\",\"0\",\"1\",\"0\",\"1\",\"0\",\"0\",\"0\",\"0\"");
        assertThat(csv).doesNotContain("archive");
        assertThat(csv).doesNotContain("object.bin");
    }

    @Test
    void materializesDailyRollupForLongTermAnalyticsStore() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "admin", "SUCCESS", 1024L, "rest", now.minusHours(2)));
        eventRepository.save(event("COPY", "copy", "INTERNAL", "media", "admin", "SUCCESS", 256L, "rest", now.minusHours(1)));
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "archive", "admin", "SUCCESS", 2048L, "rest", now.minusHours(1)));

        DataFlowDailyRollupMaterializationResponse response = service.materializeDailyRollup(
                new DataFlowEventFilter("media", null, null, null, null, now.minusDays(1), now.plusDays(1)),
                30,
                10
        );

        assertThat(response.mode()).isEqualTo("DATA_FLOW_DAILY_ROLLUP_MATERIALIZATION");
        assertThat(response.granularity()).isEqualTo("UTC_DAY");
        assertThat(response.dayWindow()).isEqualTo(30);
        assertThat(response.pointLimit()).isEqualTo(10);
        assertThat(response.pointCount()).isEqualTo(response.storedPointCount());
        assertThat(response.storagePolicy()).contains("data_flow_daily_rollups");
        assertThat(response.note()).contains("object keys");
        assertThat(response.points()).hasSize(2);
        assertThat(response.points()).anySatisfy(point -> {
            assertThat(point.bucketName()).isEqualTo("media");
            assertThat(point.operation()).isEqualTo("copy");
            assertThat(point.copiedBytes()).isEqualTo(256L);
        });
        assertThat(response.points()).noneSatisfy(point -> assertThat(point.bucketName()).isEqualTo("archive"));
    }

    @Test
    void readsMaterializedDailyRollupWithoutMixingActorOrStatusDimensions() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "admin", "SUCCESS", 1024L, "rest", now.minusHours(2)));
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "developer", "SUCCESS", 2048L, "rest", now.minusHours(1)));
        eventRepository.save(event("FAILURE", "download", "CONTROL", "media", "admin", "FAILED", 0L, "rest", now.minusMinutes(30)));

        DataFlowEventFilter adminSuccessFilter = new DataFlowEventFilter(
                "media",
                "admin",
                "rest",
                "upload",
                "SUCCESS",
                now.minusDays(1),
                now.plusDays(1)
        );
        service.materializeDailyRollup(adminSuccessFilter, 30, 10);

        DataFlowDailyRollupResponse stored = service.materializedDailyRollup(adminSuccessFilter, 30, 10);
        DataFlowDailyRollupResponse unscoped = service.materializedDailyRollup(
                new DataFlowEventFilter("media", null, "rest", "upload", null, now.minusDays(1), now.plusDays(1)),
                30,
                10
        );

        assertThat(stored.mode()).isEqualTo("DATA_FLOW_DAILY_ROLLUP_MATERIALIZED");
        assertThat(stored.storagePolicy()).contains("data_flow_daily_rollups");
        assertThat(stored.points()).hasSize(1);
        assertThat(stored.points().get(0).uploadedBytes()).isEqualTo(1024L);
        assertThat(unscoped.points()).isEmpty();
    }

    @Test
    void exportsMaterializedDailyRollupCsvFromStoredAggregateOnlyRows() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "admin", "SUCCESS", 1024L, "rest", now.minusHours(2)));
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "developer", "SUCCESS", 2048L, "rest", now.minusHours(1)));

        DataFlowEventFilter adminSuccessFilter = new DataFlowEventFilter(
                "media",
                "admin",
                "rest",
                "upload",
                "SUCCESS",
                now.minusDays(1),
                now.plusDays(1)
        );
        service.materializeDailyRollup(adminSuccessFilter, 30, 10);

        String csv = service.exportMaterializedDailyRollupCsv(adminSuccessFilter, 30, 10);

        assertThat(csv).startsWith("day,bucketName,source,operation,successCount,failureCount,cancelCount,totalCount,uploadedBytes,downloadedBytes,copiedBytes,totalBytes\n");
        assertThat(csv).contains("\"media\",\"rest\",\"upload\",\"1\",\"0\",\"0\",\"1\",\"1024\",\"0\",\"0\",\"1024\"");
        assertThat(csv).doesNotContain("2048");
        assertThat(csv).doesNotContain("object.bin");
    }

    @Test
    void buildsMonthlyRollupForLongTermAnalytics() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC).withDayOfMonth(15);
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "admin", "SUCCESS", 1024L, "rest", now.minusDays(1)));
        eventRepository.save(event("DOWNLOAD", "download", "EGRESS", "media", "admin", "SUCCESS", 512L, "s3", now.minusMonths(1)));
        eventRepository.save(event("FAILURE", "download", "CONTROL", "media", "admin", "FAILED", 0L, "rest", now.minusMonths(1)));
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "archive", "admin", "SUCCESS", 2048L, "rest", now.minusDays(1)));

        DataFlowMonthlyRollupResponse rollup = service.monthlyRollup(
                new DataFlowEventFilter("media", null, null, null, null, now.minusMonths(2), now.plusDays(1)),
                12,
                10,
                false
        );

        assertThat(rollup.mode()).isEqualTo("DATA_FLOW_MONTHLY_ROLLUP");
        assertThat(rollup.rollupSource()).isEqualTo("DATA_FLOW_EVENTS");
        assertThat(rollup.granularity()).isEqualTo("UTC_MONTH");
        assertThat(rollup.monthWindow()).isEqualTo(12);
        assertThat(rollup.pointLimit()).isEqualTo(10);
        assertThat(rollup.storagePolicy()).contains("data_flow_events");
        assertThat(rollup.points()).hasSize(3);
        assertThat(rollup.points()).anySatisfy(point -> {
            assertThat(point.month()).isEqualTo(now.toString().substring(0, 7));
            assertThat(point.bucketName()).isEqualTo("media");
            assertThat(point.source()).isEqualTo("rest");
            assertThat(point.operation()).isEqualTo("upload");
            assertThat(point.uploadedBytes()).isEqualTo(1024L);
            assertThat(point.totalBytes()).isEqualTo(1024L);
        });
        assertThat(rollup.points()).anySatisfy(point -> {
            assertThat(point.month()).isEqualTo(now.minusMonths(1).toString().substring(0, 7));
            assertThat(point.operation()).isEqualTo("download");
            assertThat(point.failureCount()).isEqualTo(1L);
        });
        assertThat(rollup.points()).noneSatisfy(point -> assertThat(point.bucketName()).isEqualTo("archive"));
    }

    @Test
    void exportsMaterializedMonthlyRollupCsvFromStoredAggregateOnlyRows() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        DataFlowEventFilter adminSuccessFilter = new DataFlowEventFilter(
                "media",
                "admin",
                "rest",
                "upload",
                "SUCCESS",
                now.minusMonths(1),
                now.plusDays(1)
        );
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "admin", "SUCCESS", 1024L, "rest", now.minusDays(1)));
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "developer", "SUCCESS", 2048L, "rest", now.minusDays(1)));
        service.materializeDailyRollup(adminSuccessFilter, 30, 10);

        String csv = service.exportMonthlyRollupCsv(adminSuccessFilter, 12, 10, true);

        assertThat(csv).startsWith("month,bucketName,source,operation,successCount,failureCount,cancelCount,totalCount,uploadedBytes,downloadedBytes,copiedBytes,totalBytes\n");
        assertThat(csv).contains("\"media\",\"rest\",\"upload\",\"1\",\"0\",\"0\",\"1\",\"1024\",\"0\",\"0\",\"1024\"");
        assertThat(csv).doesNotContain("2048");
        assertThat(csv).doesNotContain("object.bin");
    }

    @Test
    void materializesAndReadsStoredMonthlyRollupFromDailyAggregateRows() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        DataFlowEventFilter adminSuccessFilter = new DataFlowEventFilter(
                "media",
                "admin",
                "rest",
                "upload",
                "SUCCESS",
                now.minusMonths(1),
                now.plusDays(1)
        );
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "admin", "SUCCESS", 1024L, "rest", now.minusDays(1)));
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "developer", "SUCCESS", 2048L, "rest", now.minusDays(1)));
        service.materializeDailyRollup(adminSuccessFilter, 30, 10);

        DataFlowMonthlyRollupMaterializationResponse materialized = service.materializeMonthlyRollup(adminSuccessFilter, 12, 10);
        DataFlowMonthlyRollupResponse stored = service.storedMonthlyRollup(adminSuccessFilter, 12, 10);
        DataFlowMonthlyRollupResponse unscoped = service.storedMonthlyRollup(
                new DataFlowEventFilter("media", null, "rest", "upload", null, now.minusMonths(1), now.plusDays(1)),
                12,
                10
        );
        String csv = service.exportStoredMonthlyRollupCsv(adminSuccessFilter, 12, 10);

        assertThat(materialized.mode()).isEqualTo("DATA_FLOW_MONTHLY_ROLLUP_MATERIALIZATION");
        assertThat(materialized.rollupSource()).isEqualTo("DATA_FLOW_DAILY_ROLLUP_MATERIALIZED");
        assertThat(materialized.granularity()).isEqualTo("UTC_MONTH");
        assertThat(materialized.storagePolicy()).contains("data_flow_monthly_rollups");
        assertThat(materialized.note()).contains("object keys");
        assertThat(materialized.points()).hasSize(1);
        assertThat(stored.mode()).isEqualTo("DATA_FLOW_MONTHLY_ROLLUP_STORED");
        assertThat(stored.rollupSource()).isEqualTo("DATA_FLOW_MONTHLY_ROLLUPS");
        assertThat(stored.storagePolicy()).contains("data_flow_monthly_rollups");
        assertThat(stored.points()).hasSize(1);
        assertThat(stored.points().get(0).uploadedBytes()).isEqualTo(1024L);
        assertThat(unscoped.points()).isEmpty();
        assertThat(csv).startsWith("month,bucketName,source,operation,successCount,failureCount,cancelCount,totalCount,uploadedBytes,downloadedBytes,copiedBytes,totalBytes\n");
        assertThat(csv).contains("\"media\",\"rest\",\"upload\",\"1\",\"0\",\"0\",\"1\",\"1024\",\"0\",\"0\",\"1024\"");
        assertThat(csv).doesNotContain("2048");
        assertThat(csv).doesNotContain("object.bin");
    }

    @Test
    void storageStatusReportsRepositoryCountsAndReadinessBoundary() {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        DataFlowEventFilter adminSuccessFilter = new DataFlowEventFilter(
                "media",
                "admin",
                "rest",
                "upload",
                "SUCCESS",
                now.minusMonths(1),
                now.plusDays(1)
        );
        eventRepository.save(event("UPLOAD", "upload", "INGRESS", "media", "admin", "SUCCESS", 1024L, "rest", now.minusDays(1)));
        service.materializeDailyRollup(adminSuccessFilter, 30, 10);
        service.materializeMonthlyRollup(adminSuccessFilter, 12, 10);

        DataFlowStorageStatusResponse status = service.storageStatus();

        assertThat(status.mode()).isEqualTo("DATA_FLOW_STORAGE_STATUS");
        assertThat(status.metadataMode()).isEqualTo("in-memory");
        assertThat(status.repositoryHealthy()).isTrue();
        assertThat(status.eventRowCount()).isEqualTo(1L);
        assertThat(status.dailyRollupRowCount()).isEqualTo(1L);
        assertThat(status.monthlyRollupRowCount()).isEqualTo(1L);
        assertThat(status.summaryEventScanLimit()).isEqualTo(10_000);
        assertThat(status.dailyRollupWindowLimitDays()).isEqualTo(366);
        assertThat(status.monthlyRollupWindowLimitMonths()).isEqualTo(60);
        assertThat(status.aggregateStoreReady()).isTrue();
        assertThat(status.partitionedOrTimeSeriesStoreEnabled()).isFalse();
        assertThat(status.readiness()).isEqualTo("DEMO_ONLY");
    }

    private static DataFlowEventRecord event(
            String eventType,
            String operation,
            String direction,
            String bucketName,
            String actorId,
            String status,
            long sizeBytes,
            String source,
            OffsetDateTime createdAt
    ) {
        return new DataFlowEventRecord(
                null,
                eventType,
                operation,
                direction,
                bucketName,
                "object.bin",
                actorId,
                status,
                sizeBytes,
                "",
                source,
                createdAt
        );
    }
}
