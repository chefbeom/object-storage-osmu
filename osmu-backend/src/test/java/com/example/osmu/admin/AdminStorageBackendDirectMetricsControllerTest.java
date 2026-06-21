package com.example.osmu.admin;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.example.osmu.storage.memory.InMemoryObjectStorageAdapter;
import java.util.List;
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
        "osmu.storage.mode=minio"
})
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class AdminStorageBackendDirectMetricsControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void storageBackendStatusUsesDirectMetricsWhenReady() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/storage/backend-status")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.usedBytes").value(768))
                .andExpect(jsonPath("$.data.quotaBytes").value(1024))
                .andExpect(jsonPath("$.data.remainingBytes").value(256))
                .andExpect(jsonPath("$.data.directMetricTotalBytes").value(1024))
                .andExpect(jsonPath("$.data.directMetricFreeBytes").value(256))
                .andExpect(jsonPath("$.data.capacitySource").value("minio_prometheus_metrics"))
                .andExpect(jsonPath("$.data.directStorageMetricsEnabled").value(true))
                .andExpect(jsonPath("$.data.minioAdminMetricsEnabled").value(true))
                .andExpect(jsonPath("$.data.directStorageMetricsStatus").value("READY"))
                .andExpect(jsonPath("$.data.directStorageMetricNames[0]").value("minio_cluster_capacity_raw_total_bytes"))
                .andExpect(jsonPath("$.data.readiness").value("DIRECT_METRICS_READY"));
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
            return () -> StorageBackendMetricsSnapshot.ready(
                    "minio_prometheus_metrics",
                    1024,
                    256,
                    List.of("minio_cluster_capacity_raw_total_bytes", "minio_cluster_capacity_raw_free_bytes")
            );
        }
    }
}
