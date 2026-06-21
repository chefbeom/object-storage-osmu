package com.example.osmu.admin;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.storage.metrics", name = "enabled", havingValue = "true")
public class MinioPrometheusStorageMetricsProvider implements StorageBackendMetricsProvider {

    private static final List<String> TOTAL_METRIC_NAMES = List.of(
            "minio_cluster_capacity_raw_total_bytes",
            "minio_cluster_capacity_usable_total_bytes",
            "minio_cluster_capacity_total_bytes"
    );
    private static final List<String> FREE_METRIC_NAMES = List.of(
            "minio_cluster_capacity_raw_free_bytes",
            "minio_cluster_capacity_usable_free_bytes",
            "minio_cluster_capacity_free_bytes"
    );

    private final HttpClient httpClient;
    private final String metricsEndpoint;
    private final String bearerToken;
    private final Duration requestTimeout;

    public MinioPrometheusStorageMetricsProvider(
            @Value("${osmu.storage.endpoint:http://localhost:9000}") String storageEndpoint,
            @Value("${osmu.storage.metrics.endpoint:}") String metricsEndpoint,
            @Value("${osmu.storage.metrics.bearer-token:}") String bearerToken,
            @Value("${osmu.storage.metrics.timeout-seconds:3}") long timeoutSeconds
    ) {
        this.metricsEndpoint = metricsEndpoint == null || metricsEndpoint.isBlank()
                ? defaultMetricsEndpoint(storageEndpoint)
                : metricsEndpoint;
        this.bearerToken = bearerToken == null ? "" : bearerToken;
        this.requestTimeout = Duration.ofSeconds(Math.max(1L, timeoutSeconds));
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(requestTimeout)
                .build();
    }

    @Override
    public StorageBackendMetricsSnapshot snapshot() {
        try {
            HttpRequest.Builder requestBuilder = HttpRequest.newBuilder(URI.create(metricsEndpoint))
                    .GET()
                    .timeout(requestTimeout)
                    .header("Accept", "text/plain");
            if (!bearerToken.isBlank()) {
                requestBuilder.header("Authorization", "Bearer " + bearerToken);
            }
            HttpResponse<String> response = httpClient.send(requestBuilder.build(), HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return StorageBackendMetricsSnapshot.unavailable("minio_prometheus_metrics", "Metrics endpoint returned HTTP " + response.statusCode() + ".");
            }
            return fromPrometheusText(response.body());
        } catch (IllegalArgumentException | IOException exception) {
            return StorageBackendMetricsSnapshot.unavailable("minio_prometheus_metrics", "Metrics endpoint probe failed: " + exception.getMessage());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return StorageBackendMetricsSnapshot.unavailable("minio_prometheus_metrics", "Metrics endpoint probe interrupted.");
        }
    }

    static StorageBackendMetricsSnapshot fromPrometheusText(String text) {
        Map<String, Double> values = parseMetricSums(text == null ? "" : text);
        MetricValue total = firstMetricValue(values, TOTAL_METRIC_NAMES);
        MetricValue free = firstMetricValue(values, FREE_METRIC_NAMES);
        if (total.value <= 0 || free.value < 0) {
            return StorageBackendMetricsSnapshot.unavailable(
                    "minio_prometheus_metrics",
                    "Required MinIO capacity metrics not found."
            );
        }
        List<String> metricNames = new ArrayList<>();
        metricNames.add(total.name);
        metricNames.add(free.name);
        return StorageBackendMetricsSnapshot.ready(
                "minio_prometheus_metrics",
                Math.round(total.value),
                Math.round(free.value),
                metricNames
        );
    }

    private static Map<String, Double> parseMetricSums(String text) {
        Map<String, Double> values = new LinkedHashMap<>();
        for (String rawLine : text.split("\\R")) {
            String line = rawLine.trim();
            if (line.isBlank() || line.startsWith("#")) {
                continue;
            }
            int splitAt = line.lastIndexOf(' ');
            if (splitAt <= 0 || splitAt >= line.length() - 1) {
                continue;
            }
            String name = metricName(line.substring(0, splitAt));
            try {
                double value = Double.parseDouble(line.substring(splitAt + 1).trim());
                if (Double.isFinite(value)) {
                    values.merge(name, value, Double::sum);
                }
            } catch (NumberFormatException ignored) {
                // Ignore non-numeric Prometheus samples such as NaN.
            }
        }
        return values;
    }

    private static String metricName(String sampleName) {
        int labelStart = sampleName.indexOf('{');
        if (labelStart >= 0) {
            return sampleName.substring(0, labelStart);
        }
        return sampleName;
    }

    private static MetricValue firstMetricValue(Map<String, Double> values, List<String> names) {
        for (String name : names) {
            Double value = values.get(name);
            if (value != null) {
                return new MetricValue(name, value);
            }
        }
        return new MetricValue("", -1);
    }

    private static String defaultMetricsEndpoint(String storageEndpoint) {
        String base = storageEndpoint == null || storageEndpoint.isBlank()
                ? "http://localhost:9000"
                : storageEndpoint.replaceAll("/+$", "");
        return base + "/minio/v2/metrics/cluster";
    }

    private record MetricValue(String name, double value) {
    }
}
