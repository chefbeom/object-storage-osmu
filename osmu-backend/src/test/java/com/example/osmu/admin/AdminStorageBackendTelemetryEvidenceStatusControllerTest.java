package com.example.osmu.admin;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.example.osmu.storage.memory.InMemoryObjectStorageAdapter;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "osmu.storage.mode=minio",
        "osmu.operations.readiness.storage-backend-telemetry-report-path=.osmu-run/storage-backend-status-test/latest-storage-backend-telemetry.json"
})
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class AdminStorageBackendTelemetryEvidenceStatusControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void storageBackendStatusUsesTelemetryEvidenceWhenDirectMetricsAreUnavailable() throws Exception {
        Files.createDirectories(Path.of(".osmu-run/storage-backend-status-test"));
        Files.writeString(
                Path.of(".osmu-run/storage-backend-status-test/latest-storage-backend-telemetry.json"),
                """
                        {
                          "formatVersion": "osmu.storage-backend-telemetry.v1",
                          "generatedAt": "2026-06-21T08:03:05Z",
                          "result": "passed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operatorName": "ops-admin",
                          "source": {
                            "mode": "admin-info-json-path",
                            "minioAlias": "osmu-minio",
                            "evidenceRef": "mc-admin-info-run-20260621",
                            "adminInfoJsonSha256": "abc123storage",
                            "rawAdminInfoStored": false
                          },
                          "summary": {
                            "poolCount": 1,
                            "serverCount": 2,
                            "onlineServerCount": 2,
                            "offlineServerCount": 0,
                            "driveCount": 4,
                            "totalBytes": 4096,
                            "usedBytes": 1536,
                            "freeBytes": 2560,
                            "capacityKnown": true,
                            "failureCount": 0,
                            "plannedCount": 0
                          },
                          "decisionRule": "Storage backend telemetry evidence passes.",
                          "scopePolicy": "This evidence captures MinIO pool/node operations telemetry and excludes raw admin output."
                        }
                        """
        );
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/storage/backend-status")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.usedBytes").value(1536))
                .andExpect(jsonPath("$.data.quotaBytes").value(4096))
                .andExpect(jsonPath("$.data.remainingBytes").value(2560))
                .andExpect(jsonPath("$.data.directMetricTotalBytes").value(0))
                .andExpect(jsonPath("$.data.directMetricFreeBytes").value(0))
                .andExpect(jsonPath("$.data.capacitySource").value("storage_backend_telemetry_evidence"))
                .andExpect(jsonPath("$.data.directStorageMetricsEnabled").value(false))
                .andExpect(jsonPath("$.data.minioAdminMetricsEnabled").value(false))
                .andExpect(jsonPath("$.data.directStorageMetricsStatus").value("UNAVAILABLE"))
                .andExpect(jsonPath("$.data.readiness").value("TELEMETRY_EVIDENCE_READY"))
                .andExpect(jsonPath("$.data.pendingGates").isEmpty())
                .andExpect(jsonPath("$.data.note").value("OSMU storage backend status uses the latest passed MinIO admin info telemetry evidence for capacity with metadata counts for buckets and objects."));
    }

    private String loginAndReturnAccessToken(String loginId, String password) throws Exception {
        String response = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "password": "%s"
                                }
                                """.formatted(loginId, password)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.accessToken");
    }

    @TestConfiguration
    static class TestConfig {

        @Bean
        @Primary
        ObjectStorageAdapter objectStorageAdapter() {
            return new InMemoryObjectStorageAdapter();
        }

        @Bean
        @Primary
        StorageBackendMetricsProvider storageBackendMetricsProvider() {
            return () -> StorageBackendMetricsSnapshot.unavailable(
                    "minio_prometheus_metrics",
                    "Direct metrics endpoint is not reachable in this test."
            );
        }
    }
}
