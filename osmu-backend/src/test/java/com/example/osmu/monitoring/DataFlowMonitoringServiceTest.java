package com.example.osmu.monitoring;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.monitoring.repository.InMemoryDataFlowEventRepository;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;

class DataFlowMonitoringServiceTest {

    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();
    private final InMemoryDataFlowEventRepository eventRepository = new InMemoryDataFlowEventRepository();
    private final DataFlowMonitoringService service = new DataFlowMonitoringService(meterRegistry, eventRepository);

    @Test
    void recordsTrafficOperationsBucketsAndRecentEvents() {
        service.recordUpload("media", "a.bin", 1024L, "admin", "REST");
        service.recordDownload("media", "a.bin", 512L, "admin", "S3");
        service.recordList("media", "admin", "REST");
        service.recordDelete("media", "a.bin", "admin", "REST");
        service.recordCancel("upload", "media", "b.bin", "admin", "REST");
        service.recordFailure("download", "media", "c.bin", "admin", "broken pipe", "S3");

        DataFlowMonitoringResponse snapshot = service.snapshot();

        assertThat(snapshot.traffic().uploadedBytes()).isEqualTo(1024L);
        assertThat(snapshot.traffic().downloadedBytes()).isEqualTo(512L);
        assertThat(snapshot.traffic().totalBytes()).isEqualTo(1536L);
        assertThat(snapshot.operations().uploadCount()).isEqualTo(1L);
        assertThat(snapshot.operations().downloadCount()).isEqualTo(1L);
        assertThat(snapshot.operations().listCount()).isEqualTo(1L);
        assertThat(snapshot.operations().deleteCount()).isEqualTo(1L);
        assertThat(snapshot.operations().cancelCount()).isEqualTo(1L);
        assertThat(snapshot.operations().failureCount()).isEqualTo(1L);
        assertThat(snapshot.topBuckets()).hasSize(1);
        assertThat(snapshot.topBuckets().get(0).bucketName()).isEqualTo("media");
        assertThat(snapshot.trendPoints()).extracting(DataFlowTrendPointResponse::operation)
                .contains("upload", "download", "list", "delete");
        assertThat(snapshot.trendPoints()).anySatisfy(point -> {
            assertThat(point.source()).isEqualTo("rest");
            assertThat(point.operation()).isEqualTo("upload");
            assertThat(point.successCount()).isEqualTo(1L);
            assertThat(point.bytes()).isEqualTo(1024L);
        });
        assertThat(snapshot.recentEvents()).hasSize(6);
        assertThat(snapshot.recentEvents().get(0).eventType()).isEqualTo("FAILURE");
        assertThat(meterRegistry.find("osmu.data.flow.operations").tag("operation", "upload").tag("status", "success").counter().count()).isEqualTo(1.0);
        assertThat(meterRegistry.find("osmu.data.flow.operations").tag("operation", "upload").tag("bucket", "media").counter().count()).isEqualTo(1.0);
        assertThat(meterRegistry.find("osmu.data.flow.bytes").tag("direction", "ingress").tag("bucket", "media").counter().count()).isEqualTo(1024.0);
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
}
