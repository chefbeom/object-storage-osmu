package com.example.osmu.admin;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class MinioPrometheusStorageMetricsProviderTest {

    @Test
    void parsesMinioCapacityMetrics() {
        String metrics = """
                # HELP minio_cluster_capacity_raw_total_bytes Total raw capacity.
                minio_cluster_capacity_raw_total_bytes{server="minio-0"} 10737418240
                minio_cluster_capacity_raw_free_bytes{server="minio-0"} 3221225472
                """;

        StorageBackendMetricsSnapshot snapshot = MinioPrometheusStorageMetricsProvider.fromPrometheusText(metrics);

        assertThat(snapshot.ready()).isTrue();
        assertThat(snapshot.source()).isEqualTo("minio_prometheus_metrics");
        assertThat(snapshot.totalBytes()).isEqualTo(10_737_418_240L);
        assertThat(snapshot.freeBytes()).isEqualTo(3_221_225_472L);
        assertThat(snapshot.metricNames()).containsExactly(
                "minio_cluster_capacity_raw_total_bytes",
                "minio_cluster_capacity_raw_free_bytes"
        );
    }

    @Test
    void reportsUnavailableWhenCapacityMetricsAreMissing() {
        StorageBackendMetricsSnapshot snapshot = MinioPrometheusStorageMetricsProvider.fromPrometheusText("process_start_time_seconds 1");

        assertThat(snapshot.ready()).isFalse();
        assertThat(snapshot.status()).isEqualTo("UNAVAILABLE");
        assertThat(snapshot.detail()).contains("Required MinIO capacity metrics not found");
    }
}
