package com.example.osmu.admin;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class AdminDashboardSummaryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanReadDashboardSummary() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/dashboard/summary")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.usage.totalQuotaBytes").isNumber())
                .andExpect(jsonPath("$.data.usage.usedBytes").isNumber())
                .andExpect(jsonPath("$.data.system.backend").value("UP"))
                .andExpect(jsonPath("$.data.system.database").value("UP"))
                .andExpect(jsonPath("$.data.system.storage").value("UP"))
                .andExpect(jsonPath("$.data.system.accessKeyProvisioner").value("UP"))
                .andExpect(jsonPath("$.data.system.metadataEngine").value("in-memory"))
                .andExpect(jsonPath("$.data.system.storageEngine").value("in-memory"))
                .andExpect(jsonPath("$.data.backup.status").value("DRILL_PENDING"))
                .andExpect(jsonPath("$.data.backup.metadataStore").value("in-memory"))
                .andExpect(jsonPath("$.data.backup.objectStore").value("in-memory"))
                .andExpect(jsonPath("$.data.retention.enabled").isBoolean())
                .andExpect(jsonPath("$.data.shareAnalytics.totalLinks").isNumber())
                .andExpect(jsonPath("$.data.shareAnalytics.recentLinks").isArray())
                .andExpect(jsonPath("$.data.quota.policyCount").isNumber())
                .andExpect(jsonPath("$.data.quota.topPolicies").isArray())
                .andExpect(jsonPath("$.data.readiness.status").value("REVIEW"))
                .andExpect(jsonPath("$.data.readiness.runtimeProfile").value("Local demo runtime"))
                .andExpect(jsonPath("$.data.readiness.blockerCount").value(0))
                .andExpect(jsonPath("$.data.readiness.warningCount").isNumber())
                .andExpect(jsonPath("$.data.readiness.blockers").isArray())
                .andExpect(jsonPath("$.data.readiness.warnings").isArray())
                .andExpect(jsonPath("$.data.readiness.severitySummaries").isArray())
                .andExpect(jsonPath("$.data.readiness.severitySummaries[0].severity").value("WARNING"))
                .andExpect(jsonPath("$.data.readiness.categorySummaries").isArray())
                .andExpect(jsonPath("$.data.readiness.categorySummaries[0].category").value("RUNTIME"))
                .andExpect(jsonPath("$.data.readiness.categorySummaries[0].warningCount").isNumber())
                .andExpect(jsonPath("$.data.readiness.items").isArray())
                .andExpect(jsonPath("$.data.readiness.items[0].severity").value("WARNING"))
                .andExpect(jsonPath("$.data.readiness.items[0].category").value("RUNTIME"))
                .andExpect(jsonPath("$.data.readiness.items[0].code").value("METADATA_ENGINE"))
                .andExpect(jsonPath("$.data.readiness.items[0].targetPage").value("dashboard"))
                .andExpect(jsonPath("$.data.readiness.items[0].targetPanel").value("dashboard-widget-runtime"))
                .andExpect(jsonPath("$.data.readiness.generatedAt").exists())
                .andExpect(jsonPath("$.data.dataFlow.traffic.uploadedBytes").isNumber())
                .andExpect(jsonPath("$.data.dataFlow.traffic.downloadedBytes").isNumber())
                .andExpect(jsonPath("$.data.dataFlow.traffic.copiedBytes").isNumber())
                .andExpect(jsonPath("$.data.dataFlow.traffic.internalBytes").isNumber())
                .andExpect(jsonPath("$.data.dataFlow.operations.uploadCount").isNumber())
                .andExpect(jsonPath("$.data.dataFlow.operations.copyCount").isNumber())
                .andExpect(jsonPath("$.data.dataFlow.operations.failureCount").isNumber())
                .andExpect(jsonPath("$.data.dataFlow.topBuckets").isArray())
                .andExpect(jsonPath("$.data.dataFlow.trendPoints").isArray())
                .andExpect(jsonPath("$.data.dataFlow.recentEvents").isArray())
                .andExpect(jsonPath("$.data.recentAuditLogs.items").isArray())
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanReadStorageBackendStatus() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/storage/backend-status")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("in-memory"))
                .andExpect(jsonPath("$.data.metadataMode").value("in-memory"))
                .andExpect(jsonPath("$.data.storageHealthy").value(true))
                .andExpect(jsonPath("$.data.accessKeyProvisionerHealthy").value(true))
                .andExpect(jsonPath("$.data.bucketCount").isNumber())
                .andExpect(jsonPath("$.data.objectCount").isNumber())
                .andExpect(jsonPath("$.data.usedBytes").isNumber())
                .andExpect(jsonPath("$.data.quotaBytes").isNumber())
                .andExpect(jsonPath("$.data.remainingBytes").isNumber())
                .andExpect(jsonPath("$.data.directMetricTotalBytes").value(0))
                .andExpect(jsonPath("$.data.directMetricFreeBytes").value(0))
                .andExpect(jsonPath("$.data.capacitySource").value("bucket_metadata_usage"))
                .andExpect(jsonPath("$.data.directStorageMetricsEnabled").value(false))
                .andExpect(jsonPath("$.data.minioAdminMetricsEnabled").value(false))
                .andExpect(jsonPath("$.data.directStorageMetricsStatus").value("DISABLED"))
                .andExpect(jsonPath("$.data.directStorageMetricsSource").value("disabled"))
                .andExpect(jsonPath("$.data.directStorageMetricsDetail").value("Direct MinIO capacity metrics are disabled."))
                .andExpect(jsonPath("$.data.directStorageMetricNames").isArray())
                .andExpect(jsonPath("$.data.readiness").value("DEMO_ONLY"))
                .andExpect(jsonPath("$.data.pendingGates").isArray())
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanReadDataFlowMonitoring() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-06-18T00:00:00Z")
                        .param("to", "2026-06-19T00:00:00Z")
                        .param("limit", "25")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.traffic.uploadedBytes").isNumber())
                .andExpect(jsonPath("$.data.traffic.downloadedBytes").isNumber())
                .andExpect(jsonPath("$.data.traffic.copiedBytes").isNumber())
                .andExpect(jsonPath("$.data.operations.totalCount").isNumber())
                .andExpect(jsonPath("$.data.operations.copyCount").isNumber())
                .andExpect(jsonPath("$.data.topBuckets").isArray())
                .andExpect(jsonPath("$.data.trendPoints").isArray())
                .andExpect(jsonPath("$.data.recentEvents").isArray())
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanReadDataFlowStorageStatus() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/storage-status")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DATA_FLOW_STORAGE_STATUS"))
                .andExpect(jsonPath("$.data.metadataMode").value("in-memory"))
                .andExpect(jsonPath("$.data.repositoryHealthy").value(true))
                .andExpect(jsonPath("$.data.eventRowCount").isNumber())
                .andExpect(jsonPath("$.data.dailyRollupRowCount").isNumber())
                .andExpect(jsonPath("$.data.monthlyRollupRowCount").isNumber())
                .andExpect(jsonPath("$.data.summaryEventScanLimit").value(10000))
                .andExpect(jsonPath("$.data.dailyRollupWindowLimitDays").value(366))
                .andExpect(jsonPath("$.data.monthlyRollupWindowLimitMonths").value(60))
                .andExpect(jsonPath("$.data.aggregateStoreReady").value(true))
                .andExpect(jsonPath("$.data.partitionedOrTimeSeriesStoreEnabled").value(false))
                .andExpect(jsonPath("$.data.readiness").value("DEMO_ONLY"))
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanExportDataFlowMonitoringCsv() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/export.csv")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-06-18T00:00:00Z")
                        .param("to", "2026-06-19T00:00:00Z")
                        .param("limit", "25")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-data-flow.csv\""))
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(content().string(org.hamcrest.Matchers.startsWith("createdAt,eventType,operation,direction,bucketName,objectKey,actorId,status,sizeBytes,source,message\n")));
    }

    @Test
    void adminCanReadDataFlowDailyRollup() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/daily-rollup")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-06-18T00:00:00Z")
                        .param("to", "2026-06-19T00:00:00Z")
                        .param("days", "14")
                        .param("limit", "25")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DATA_FLOW_DAILY_ROLLUP"))
                .andExpect(jsonPath("$.data.granularity").value("UTC_DAY"))
                .andExpect(jsonPath("$.data.dayWindow").value(14))
                .andExpect(jsonPath("$.data.pointLimit").value(25))
                .andExpect(jsonPath("$.data.pointCount").isNumber())
                .andExpect(jsonPath("$.data.points").isArray())
                .andExpect(jsonPath("$.data.storagePolicy", org.hamcrest.Matchers.containsString("data_flow_events")))
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanMaterializeDataFlowDailyRollup() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/monitoring/data-flow/daily-rollup/materialize")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-06-18T00:00:00Z")
                        .param("to", "2026-06-19T00:00:00Z")
                        .param("days", "14")
                        .param("limit", "25")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DATA_FLOW_DAILY_ROLLUP_MATERIALIZATION"))
                .andExpect(jsonPath("$.data.granularity").value("UTC_DAY"))
                .andExpect(jsonPath("$.data.dayWindow").value(14))
                .andExpect(jsonPath("$.data.pointLimit").value(25))
                .andExpect(jsonPath("$.data.pointCount").isNumber())
                .andExpect(jsonPath("$.data.storedPointCount").isNumber())
                .andExpect(jsonPath("$.data.storagePolicy", org.hamcrest.Matchers.containsString("data_flow_daily_rollups")))
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanReadMaterializedDataFlowDailyRollup() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/daily-rollup/materialized")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-06-18T00:00:00Z")
                        .param("to", "2026-06-19T00:00:00Z")
                        .param("days", "14")
                        .param("limit", "25")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DATA_FLOW_DAILY_ROLLUP_MATERIALIZED"))
                .andExpect(jsonPath("$.data.granularity").value("UTC_DAY"))
                .andExpect(jsonPath("$.data.dayWindow").value(14))
                .andExpect(jsonPath("$.data.pointLimit").value(25))
                .andExpect(jsonPath("$.data.pointCount").isNumber())
                .andExpect(jsonPath("$.data.storagePolicy", org.hamcrest.Matchers.containsString("data_flow_daily_rollups")))
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanExportDataFlowDailyRollupCsv() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/daily-rollup/export.csv")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-06-18T00:00:00Z")
                        .param("to", "2026-06-19T00:00:00Z")
                        .param("days", "14")
                        .param("limit", "25")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-data-flow-daily-rollup.csv\""))
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(content().string(org.hamcrest.Matchers.startsWith("day,bucketName,source,operation,successCount,failureCount,cancelCount,totalCount,uploadedBytes,downloadedBytes,copiedBytes,totalBytes\n")));
    }

    @Test
    void adminCanExportMaterializedDataFlowDailyRollupCsv() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/daily-rollup/materialized/export.csv")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-06-18T00:00:00Z")
                        .param("to", "2026-06-19T00:00:00Z")
                        .param("days", "14")
                        .param("limit", "25")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-data-flow-daily-rollup-materialized.csv\""))
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(content().string(org.hamcrest.Matchers.startsWith("day,bucketName,source,operation,successCount,failureCount,cancelCount,totalCount,uploadedBytes,downloadedBytes,copiedBytes,totalBytes\n")));
    }

    @Test
    void adminCanReadDataFlowMonthlyRollup() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/monthly-rollup")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-01-01T00:00:00Z")
                        .param("to", "2026-06-30T00:00:00Z")
                        .param("months", "6")
                        .param("limit", "25")
                        .param("materialized", "true")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DATA_FLOW_MONTHLY_ROLLUP_MATERIALIZED"))
                .andExpect(jsonPath("$.data.rollupSource").value("DATA_FLOW_DAILY_ROLLUP_MATERIALIZED"))
                .andExpect(jsonPath("$.data.granularity").value("UTC_MONTH"))
                .andExpect(jsonPath("$.data.monthWindow").value(6))
                .andExpect(jsonPath("$.data.pointLimit").value(25))
                .andExpect(jsonPath("$.data.pointCount").isNumber())
                .andExpect(jsonPath("$.data.points").isArray())
                .andExpect(jsonPath("$.data.note", org.hamcrest.Matchers.containsString("not AWS billing parity")))
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanMaterializeDataFlowMonthlyRollup() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/monitoring/data-flow/monthly-rollup/materialize")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-01-01T00:00:00Z")
                        .param("to", "2026-06-30T00:00:00Z")
                        .param("months", "6")
                        .param("limit", "25")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DATA_FLOW_MONTHLY_ROLLUP_MATERIALIZATION"))
                .andExpect(jsonPath("$.data.rollupSource").value("DATA_FLOW_DAILY_ROLLUP_MATERIALIZED"))
                .andExpect(jsonPath("$.data.granularity").value("UTC_MONTH"))
                .andExpect(jsonPath("$.data.monthWindow").value(6))
                .andExpect(jsonPath("$.data.pointLimit").value(25))
                .andExpect(jsonPath("$.data.pointCount").isNumber())
                .andExpect(jsonPath("$.data.storedPointCount").isNumber())
                .andExpect(jsonPath("$.data.storagePolicy", org.hamcrest.Matchers.containsString("data_flow_monthly_rollups")))
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanReadMaterializedDataFlowMonthlyRollup() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/monthly-rollup/materialized")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-01-01T00:00:00Z")
                        .param("to", "2026-06-30T00:00:00Z")
                        .param("months", "6")
                        .param("limit", "25")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mode").value("DATA_FLOW_MONTHLY_ROLLUP_STORED"))
                .andExpect(jsonPath("$.data.rollupSource").value("DATA_FLOW_MONTHLY_ROLLUPS"))
                .andExpect(jsonPath("$.data.granularity").value("UTC_MONTH"))
                .andExpect(jsonPath("$.data.monthWindow").value(6))
                .andExpect(jsonPath("$.data.pointLimit").value(25))
                .andExpect(jsonPath("$.data.pointCount").isNumber())
                .andExpect(jsonPath("$.data.storagePolicy", org.hamcrest.Matchers.containsString("data_flow_monthly_rollups")))
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void adminCanExportDataFlowMonthlyRollupCsv() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/monthly-rollup/export.csv")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-01-01T00:00:00Z")
                        .param("to", "2026-06-30T00:00:00Z")
                        .param("months", "6")
                        .param("limit", "25")
                        .param("materialized", "true")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-data-flow-monthly-rollup.csv\""))
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(content().string(org.hamcrest.Matchers.startsWith("month,bucketName,source,operation,successCount,failureCount,cancelCount,totalCount,uploadedBytes,downloadedBytes,copiedBytes,totalBytes\n")));
    }

    @Test
    void adminCanExportMaterializedDataFlowMonthlyRollupCsv() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/monitoring/data-flow/monthly-rollup/materialized/export.csv")
                        .param("bucketName", "media")
                        .param("actorId", "admin")
                        .param("source", "rest")
                        .param("operation", "upload")
                        .param("status", "SUCCESS")
                        .param("from", "2026-01-01T00:00:00Z")
                        .param("to", "2026-06-30T00:00:00Z")
                        .param("months", "6")
                        .param("limit", "25")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"osmu-data-flow-monthly-rollup-materialized.csv\""))
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(content().string(org.hamcrest.Matchers.startsWith("month,bucketName,source,operation,successCount,failureCount,cancelCount,totalCount,uploadedBytes,downloadedBytes,copiedBytes,totalBytes\n")));
    }

    @Test
    void dashboardSummaryReflectsRecordedRestoreDrillEvidence() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/backup/restore-drill-evidence")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "environment": "kubernetes-drill",
                                  "operator": "admin",
                                  "result": "SUCCESS",
                                  "startedAt": "2026-06-15T10:00:00+09:00",
                                  "completedAt": "2026-06-15T10:30:00+09:00",
                                  "backupTimestamp": "2026-06-15T00:00:00+09:00",
                                  "metadataRowCount": 42,
                                  "objectCount": 7,
                                  "objectBytes": 8192,
                                  "evidenceUri": "osmu-run/latest-kubernetes-dr-finalize.json",
                                  "gaps": []
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.statusImpact").value("READY_GATE_SATISFIED"));

        mockMvc.perform(get("/api/admin/dashboard/summary")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.backup.restoreDrillExecuted").value(true))
                .andExpect(jsonPath("$.data.backup.lastRestoreDrillAt").exists())
                .andExpect(jsonPath("$.data.backup.latestRestoreDrillEvidence.environment").value("kubernetes-drill"))
                .andExpect(jsonPath("$.data.backup.latestRestoreDrillEvidence.result").value("SUCCESS"))
                .andExpect(jsonPath("$.data.backup.pendingGates").value(not(hasItem("Successful restore drill evidence has not been recorded."))))
                .andExpect(jsonPath("$.data.readiness.warnings").value(not(hasItem("Successful restore drill evidence has not been recorded."))));
    }

    @Test
    void adminCanRefreshDashboardReadinessOnly() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/dashboard/readiness")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("REVIEW"))
                .andExpect(jsonPath("$.data.runtimeProfile").value("Local demo runtime"))
                .andExpect(jsonPath("$.data.severitySummaries[0].severity").value("WARNING"))
                .andExpect(jsonPath("$.data.categorySummaries[0].category").value("RUNTIME"))
                .andExpect(jsonPath("$.data.items").isArray())
                .andExpect(jsonPath("$.data.items[0].category").value("RUNTIME"))
                .andExpect(jsonPath("$.data.items[0].targetPanel").value("dashboard-widget-runtime"))
                .andExpect(jsonPath("$.data.generatedAt").exists());
    }

    @Test
    void dashboardReadinessIncludesOperationsEvidenceReportWarnings() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        Files.createDirectories(Path.of(".osmu-run"));
        Files.writeString(
                Path.of(".osmu-run/latest-operations-readiness.json"),
                """
                        {
                          "result": "pending",
                          "summary": "passed=36 pending=6",
                          "checks": [
                            {
                              "name": "Kubernetes DR finalizer evidence",
                              "category": "HA_DR",
                              "passed": false,
                              "detail": "missing latest-kubernetes-dr-finalize.json",
                              "evidencePath": ".osmu-run/latest-kubernetes-dr-finalize.json",
                              "remediation": {
                                "command": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/finalize-kubernetes-dr-drill.ps1 -ConfirmRestore",
                                "workflow": ".github/workflows/kubernetes-dr-finalizer-ci.yml",
                                "workflowCommand": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true",
                                "note": "Use confirmed restore evidence."
                              }
                            }
                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-storage-backend-telemetry.json"),
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
                            "totalBytes": 4398046511104,
                            "usedBytes": 927712935936,
                            "freeBytes": 3470333575168,
                            "capacityKnown": true,
                            "failureCount": 0,
                            "plannedCount": 0
                          },
                          "decisionRule": "Storage backend telemetry evidence passes when target environment, cluster, operator, external evidence reference, MinIO admin-info JSON parsing, pool/server/drive summaries, online server state, and capacity totals are all present.",
                          "scopePolicy": "This evidence captures MinIO pool/node operations telemetry for OSMU storage readiness. It is not AWS S3 parity work, and it does not store raw admin info, credentials, bearer tokens, private keys, kubeconfig, MinIO root credentials, or object data."
                        }
                """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-monitoring-threshold-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.monitoring-threshold-evidence.v1",
                          "generatedAt": "2026-06-21T09:05:00Z",
                          "result": "passed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operatorName": "ops-admin",
                          "evidenceRef": "monitoring-threshold-run-20260621",
                          "reviewWindow": {
                            "startedAt": "2026-06-21T08:40:00Z",
                            "completedAt": "2026-06-21T09:00:00Z"
                          },
                          "thresholdTargetsPath": ".\\\\infra\\\\monitoring\\\\alert-threshold-targets.yaml",
                          "thresholdTargetSummary": {
                            "requiredAlertCount": 11,
                            "mappedAlertCount": 11,
                            "missingAlerts": [],
                            "routeCount": 3,
                            "routes": ["osmu-backend", "osmu-data-flow", "osmu-backup"],
                            "grafanaPanelCount": 11,
                            "tuningEvidenceCount": 11,
                            "alertTargetCoverageComplete": true,
                            "routeCoverageComplete": true,
                            "grafanaPanelCoverageComplete": true,
                            "tuningEvidenceCoverageComplete": true,
                            "thresholdMappingComplete": true
                          },
                          "evidenceRefs": {
                            "changeApproval": "CHG-2026-MONITORING",
                            "prometheusRules": "prom-rules-run-20260621",
                            "grafanaDashboard": "grafana-import-run-20260621",
                            "alertmanagerRoute": "alertmanager-route-review-20260621",
                            "targetBaseline": "tenant-baseline-review-20260621",
                            "incidentRouting": "incident-routing-review-20260621"
                          },
                          "confirmations": {
                            "prometheusRulesLoaded": true,
                            "grafanaDashboardImported": true,
                            "alertmanagerRoutesReviewed": true,
                            "targetBaselinesReviewed": true,
                            "incidentRoutingReviewed": true,
                            "noSecretValues": true
                          },
                          "summary": {
                            "failureCount": 0,
                            "checkCount": 24
                          },
                          "checks": [
                            {
                              "id": "prometheus-rules-loaded-confirmed",
                              "name": "Prometheus rules loaded confirmation",
                              "status": "PASS",
                              "passed": true,
                              "detail": "Rules were loaded into target Prometheus or PrometheusRule."
                            }
                          ],
                          "decisionRule": "Production/B2B monitoring readiness requires result=passed after the target Prometheus rules, Grafana dashboard, Alertmanager routes, incident routing, and tenant baseline threshold values are reviewed.",
                          "secretPolicy": "Evidence stores only environment labels, operator/change references, timestamps, booleans, target threshold metadata, and external evidence references; it does not contain passwords."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-storage-expansion-finalize.json"),
                """
                        {
                          "generatedAt": "2026-06-20T00:10:00Z",
                          "startedAt": "2026-06-20T00:00:00Z",
                          "completedAt": "2026-06-20T00:10:00Z",
                          "result": "failed",
                          "namespace": "pilot-osmu",
                          "tenantName": "osmu-minio",
                          "serviceAccount": "osmu-storage-expansion-runner",
                          "impersonateRunner": true,
                          "backend": {
                            "apiBase": "https://api.example/osmu",
                            "requestId": 17,
                            "runDryRunRunner": true,
                            "dryRunType": "KUBECTL_DIFF",
                            "runApply": false,
                            "applyType": "KUBECTL_APPLY",
                            "confirmApply": false
                          },
                          "storageBackendTelemetry": {
                            "runEvidence": false,
                            "executeRequested": false,
                            "targetCluster": "customer-cluster-a"
                          },
                          "evidence": {
                            "rbacAuth": ".osmu-run/latest-storage-expansion-rbac-auth.json",
                            "serverDryRun": ".osmu-run/latest-storage-expansion-server-dry-run.json",
                            "storageBackendTelemetry": "",
                            "report": ".osmu-run/latest-storage-expansion-finalize.json"
                          },
                          "failedCount": 1,
                          "gaps": [
                            "Backend apply runner was not executed."
                          ],
                          "steps": [
                            {
                              "name": "Storage expansion server-side dry-run",
                              "result": "failed",
                              "exitCode": 1,
                              "notes": "Tenant patch denied"
                            }
                          ],
                          "secretPolicy": "Secret values, bearer tokens, and raw MinIO admin info are not written to storage expansion finalizer evidence."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-kubernetes-ha-dr-readiness.json"),
                """
                        {
                          "formatVersion": "osmu.kubernetes-ha-dr-readiness.v1",
                          "generatedAt": "2026-06-20T00:12:00Z",
                          "namespace": "pilot-osmu",
                          "kubectlPath": "kubectl",
                          "restoreManifestPath": "C:/project/object-storage-osmu/infra/k8s/examples/restore-from-backup.example.yaml",
                          "result": "failed",
                          "failureCount": 1,
                          "checks": [
                            {
                              "name": "deployment-osmu-backend-ready",
                              "category": "ha",
                              "passed": true,
                              "summary": "desired=2 ready=2 available=2 minimum=2 topologySpread=True",
                              "exitCode": 0
                            },
                            {
                              "name": "pdb-osmu-minio-effective",
                              "category": "ha",
                              "passed": false,
                              "summary": "minAvailable=1 currentHealthy=0 disruptionsAllowed=0 expectedDisruptionsAllowedAtLeast=0",
                              "exitCode": 0
                            }
                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-kubernetes-dr-finalize.json"),
                """
                        {
                          "formatVersion": "osmu.kubernetes-dr-finalize.v1",
                          "generatedAt": "2026-06-20T00:20:00Z",
                          "startedAt": "2026-06-20T00:15:00Z",
                          "completedAt": "2026-06-20T00:20:00Z",
                          "result": "partial",
                          "status": "kubernetes-dr-finalize-partial",
                          "sourceNamespace": "pilot-osmu",
                          "restoreNamespace": "pilot-osmu-restore",
                          "runId": "20260620002000",
                          "backupTimestamp": "20260620T001500Z",
                          "powerShellCommand": "pwsh",
                          "serverDryRunOnly": true,
                          "confirmRestore": false,
                          "runBackupDrill": true,
                          "runRestoreSmoke": false,
                          "writeEvidenceRequest": false,
                          "submitEvidence": false,
                          "runS3ClientSmoke": false,
                          "commands": [
                            {
                              "name": "Kubernetes DR drill wrapper",
                              "script": ".\\\\scripts\\\\run-kubernetes-dr-drill.ps1",
                              "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\run-kubernetes-dr-drill.ps1 -ServerDryRunOnly"
                            }
                          ],
                          "steps": [
                            {
                              "name": "Kubernetes restore smoke",
                              "result": "skipped",
                              "exitCode": 0,
                              "notes": "Skipped because -SkipRestoreSmoke or -ServerDryRunOnly was set."
                            }
                          ],
                          "gaps": [
                            "Server-side dry-run only; no restore was executed.",
                            "Restore was not confirmed."
                          ],
                          "secretPolicy": "Admin password and DR secret values are not written to this finalize report; displayed commands mask -AdminPassword."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-iam-rbac-finalize.json"),
                """
                        {
                          "formatVersion": "osmu.iam-rbac-finalize.v1",
                          "generatedAt": "2026-06-20T00:45:00Z",
                          "startedAt": "2026-06-20T00:40:00Z",
                          "completedAt": "2026-06-20T00:45:00Z",
                          "result": "failed",
                          "status": "iam-rbac-finalize-failed",
                          "namespace": "pilot-osmu",
                          "serviceAccount": "osmu-storage-expansion-runner",
                          "powerShellCommand": "pwsh",
                          "gradleCommand": "./gradlew",
                          "runBackendPolicyTests": true,
                          "runKubernetesLiveAuth": true,
                          "commands": [
                            {
                              "name": "IAM/RBAC matrix verifier",
                              "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/verify-iam-rbac-matrix.ps1",
                              "workingDirectory": "C:/project/object-storage-osmu"
                            },
                            {
                              "name": "Storage expansion live RBAC auth",
                              "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/verify-storage-expansion-rbac-auth.ps1 -Namespace pilot-osmu",
                              "workingDirectory": "C:/project/object-storage-osmu"
                            }
                          ],
                          "steps": [
                            {
                              "name": "IAM/RBAC matrix verifier",
                              "result": "passed",
                              "exitCode": 0,
                              "notes": ""
                            },
                            {
                              "name": "Storage expansion live RBAC auth",
                              "result": "failed",
                              "exitCode": 1,
                              "notes": "kubectl auth can-i denied patch tenant"
                            }
                          ],
                          "failedCount": 1,
                          "gaps": [
                            "Storage expansion live RBAC auth failed with exit code 1."
                          ],
                          "decisionRule": "IAM/RBAC finalization passes when the application IAM/RBAC matrix and Kubernetes RBAC matrix verifiers pass. Backend focused tests and live kubectl auth can-i evidence are optional stronger evidence selected by flags.",
                          "secretPolicy": "IAM/RBAC finalizer does not read or write passwords, API keys, kubeconfig contents, bearer tokens, or object storage credentials."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-image-signing-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.image-signing-evidence.v1",
                          "generatedAt": "2026-06-20T01:00:00Z",
                          "result": "passed",
                          "failureCount": 0,
                          "version": "v0.1.0-rc.1",
                          "commitSha": "abc123def456abc123def456abc123def456abcd",
                          "sourceRunUrl": "https://github.example/osmu/actions/runs/104",
                          "issuer": "https://token.actions.githubusercontent.com",
                          "signingMode": "keyless-github-actions-oidc",
                          "backend": {
                            "versionRef": "registry.example/osmu-backend:v0.1.0-rc.1",
                            "shaRef": "registry.example/osmu-backend:abc123def456abc123def456abc123def456abcd",
                            "digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
                            "versionSignatureVerified": true,
                            "shaSignatureVerified": true
                          },
                          "frontend": {
                            "versionRef": "registry.example/osmu-frontend:v0.1.0-rc.1",
                            "shaRef": "registry.example/osmu-frontend:abc123def456abc123def456abc123def456abcd",
                            "digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
                            "versionSignatureVerified": true,
                            "shaSignatureVerified": true
                          },
                          "secretPolicy": "Evidence contains public image references, optional digests, workflow URL, and signature verification flags only; it does not contain registry credentials or tokens."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-container-security-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.container-security-evidence.v1",
                          "generatedAt": "2026-06-20T01:05:00Z",
                          "result": "failed",
                          "failureCount": 1,
                          "backendImage": "registry.example/osmu-backend:abc123def456abc123def456abc123def456abcd",
                          "frontendImage": "registry.example/osmu-frontend:abc123def456abc123def456abc123def456abcd",
                          "commitSha": "abc123def456abc123def456abc123def456abcd",
                          "sourceRunUrl": "https://github.example/osmu/actions/runs/105",
                          "artifactName": "osmu-container-security-abc123def456abc123def456abc123def456abcd",
                          "scans": {
                            "severity": "CRITICAL,HIGH",
                            "ignoreUnfixed": true,
                            "backendScanPassed": true,
                            "frontendScanPassed": false
                          },
                          "sbom": {
                            "format": "SPDX JSON",
                            "backend": {
                              "valid": true,
                              "packageCount": 42,
                              "byteSize": 4096,
                              "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                            },
                            "frontend": {
                              "valid": true,
                              "packageCount": 38,
                              "byteSize": 3072,
                              "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
                            }
                          },
                          "secretPolicy": "Evidence contains image names, SBOM metadata, workflow URL, and scan pass flags only; it does not contain registry credentials or tokens."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-security-evidence-finalize.json"),
                """
                        {
                          "formatVersion": "osmu.security-evidence-finalize.v1",
                          "generatedAt": "2026-06-20T01:10:00Z",
                          "result": "failed",
                          "failureCount": 1,
                          "allowSyntheticEvidence": false,
                          "inputs": {
                            "imageSigningEvidence": ".osmu-run/latest-image-signing-evidence.json",
                            "containerSecurityEvidence": ".osmu-run/latest-container-security-evidence.json"
                          },
                          "promoted": {
                            "imageSigningEvidence": ".osmu-run/latest-image-signing-evidence.json",
                            "containerSecurityEvidence": ".osmu-run/latest-container-security-evidence.json",
                            "actions": "promotion skipped because finalizer result is failed"
                          },
                          "source": {
                            "imageSigningRunUrl": "https://github.example/osmu/actions/runs/104",
                            "containerSecurityRunUrl": "https://github.example/osmu/actions/runs/105",
                            "containerSecurityArtifactName": "osmu-container-security-abc123def456abc123def456abc123def456abcd"
                          },
                          "images": {
                            "backendVersionRef": "registry.example/osmu-backend:v0.1.0-rc.1",
                            "frontendVersionRef": "registry.example/osmu-frontend:v0.1.0-rc.1",
                            "backendDigest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
                            "frontendDigest": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
                            "backendImage": "registry.example/osmu-backend:abc123def456abc123def456abc123def456abcd",
                            "frontendImage": "registry.example/osmu-frontend:abc123def456abc123def456abc123def456abcd"
                          },
                          "checks": [
                            {
                              "name": "container security frontend scan",
                              "passed": false,
                              "detail": "frontend scan failed",
                              "evidencePath": ".osmu-run/latest-container-security-evidence.json"
                            }
                          ],
                          "decisionRule": "Security evidence finalization passes only when image signing evidence and container scan/SBOM evidence are present, parsed, passed, non-synthetic by default, and promotable to the standard latest evidence paths.",
                          "secretPolicy": "Finalizer copies and summarizes existing evidence JSON only; it does not read or write registry credentials, signing keys, tokens, kubeconfig, or application secrets."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-secret-rotation-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.secret-rotation-evidence.v1",
                          "generatedAt": "2026-06-20T00:30:00Z",
                          "result": "failed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operatorName": "ops-admin",
                          "rotationWindow": {
                            "startedAt": "2026-06-20T00:00:00Z",
                            "completedAt": "2026-06-20T00:30:00Z"
                          },
                          "evidenceRefs": {
                            "changeApproval": "CHG-2026-SECRET-ROTATION",
                            "secretManagerAudit": "vault-audit-run-20260620",
                            "workloadRestart": "rollout-status-run-20260620",
                            "smoke": "",
                            "artifactLeakReview": "artifact-leak-review-20260620",
                            "accessKeyEncryptionDecision": "access-key-encryption-key-reissue-deferred-20260620"
                          },
                          "confirmations": {
                            "noSecretValues": true,
                            "workloadRestart": true,
                            "smokePassed": false,
                            "artifactLeakReview": true,
                            "requireAllCoreSecrets": true
                          },
                          "rotations": [
                            {
                              "id": "admin-password",
                              "name": "Admin password",
                              "core": true,
                              "rotated": true,
                              "note": "Rotate before shared demo, pilot handoff, suspected exposure, or owner change."
                            },
                            {
                              "id": "tls-certificate",
                              "name": "TLS certificate",
                              "core": true,
                              "rotated": false,
                              "note": "Rotate or renew the osmu-tls Secret and verify HTTPS routing."
                            }
                          ],
                          "summary": {
                            "rotatedCount": 4,
                            "coreRotatedCount": 4,
                            "coreRequiredCount": 5,
                            "failureCount": 2,
                            "plannedCount": 0
                          },
                          "checks": [
                            {
                              "id": "smoke-passed-confirmed",
                              "name": "Post-rotation smoke passed confirmation",
                              "status": "FAIL",
                              "passed": false,
                              "detail": "Required smoke checks passed after rotation."
                            },
                            {
                              "id": "core-secret-rotation-coverage",
                              "name": "Core secret/certificate rotation coverage",
                              "status": "FAIL",
                              "passed": false,
                              "detail": "rotatedCore=4/5"
                            }
                          ],
                          "decisionRule": "Production/B2B readiness requires result=passed from the target environment after core secret/certificate rotation, workload restart, post-rotation smoke, and artifact leak review are confirmed.",
                          "secretPolicy": "Evidence stores only environment labels, operator/change references, timestamps, booleans, and external evidence references; it does not contain password values, API keys, private keys, bearer tokens, kubeconfig, database credentials, MinIO credentials, OIDC/LDAP secrets, SMTP credentials, or webhook signing secrets."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-readiness-finalize.json"),
                """
                        {
                          "formatVersion": "osmu.operations-readiness-finalize.v1",
                          "result": "pending",
                          "status": "operations-readiness-finalize-pending",
                          "readinessResult": "pending",
                          "readinessSummary": "passed=36 pending=6",
                          "namespace": "osmu",
                          "sourceNamespace": "osmu",
                          "restoreNamespace": "osmu-restore-drill",
                          "backupTimestamp": "20260616T010203Z",
                          "powerShellCommand": "pwsh",
                          "selectedSteps": {
                            "storageExpansionFinalizer": true,
                            "haDrReadiness": true,
                            "kubernetesDrFinalizer": false,
                            "iamRbacFinalizer": true,
                            "securityEvidenceFinalizer": true
                          },
                          "paths": {
                            "operationsReadinessJson": ".osmu-run/latest-operations-readiness.json",
                            "operationsReadinessMarkdown": ".osmu-run/latest-operations-readiness.md",
                            "dataFlowStoragePlan": ".osmu-run/latest-data-flow-storage-plan.json",
                            "dataFlowStorageTransitionRunbookEvidence": ".osmu-run/latest-data-flow-storage-transition-runbook-evidence.json",
                            "report": ".osmu-run/latest-operations-readiness-finalize.json",
                            "summary": ".osmu-run/latest-operations-readiness-finalize.md"
                          },
                          "commands": [
                            {
                              "name": "Operations readiness report",
                              "script": ".\\\\scripts\\\\write-operations-readiness.ps1",
                              "arguments": ["-JsonOutputPath", ".osmu-run/latest-operations-readiness.json", "-DataFlowStoragePlanPath", ".osmu-run/latest-data-flow-storage-plan.json", "-DataFlowStorageTransitionRunbookEvidencePath", ".osmu-run/latest-data-flow-storage-transition-runbook-evidence.json"],
                              "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-readiness.ps1 -JsonOutputPath .osmu-run/latest-operations-readiness.json -DataFlowStoragePlanPath .osmu-run/latest-data-flow-storage-plan.json -DataFlowStorageTransitionRunbookEvidencePath .osmu-run/latest-data-flow-storage-transition-runbook-evidence.json"
                            }
                          ],
                          "steps": [
                            {
                              "name": "Operations readiness report",
                              "script": ".\\\\scripts\\\\write-operations-readiness.ps1",
                              "arguments": ["-JsonOutputPath", ".osmu-run/latest-operations-readiness.json", "-DataFlowStoragePlanPath", ".osmu-run/latest-data-flow-storage-plan.json", "-DataFlowStorageTransitionRunbookEvidencePath", ".osmu-run/latest-data-flow-storage-transition-runbook-evidence.json"],
                              "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-readiness.ps1 -JsonOutputPath .osmu-run/latest-operations-readiness.json -DataFlowStoragePlanPath .osmu-run/latest-data-flow-storage-plan.json -DataFlowStorageTransitionRunbookEvidencePath .osmu-run/latest-data-flow-storage-transition-runbook-evidence.json",
                              "result": "passed",
                              "exitCode": 0,
                              "output": "Operations readiness result pending.",
                              "notes": ""
                            }
                          ],
                          "failedCount": 0,
                          "gaps": ["Operations readiness result is pending: passed=36 pending=6."],
                          "secretPolicy": "Operations readiness finalizer masks admin passwords in recorded commands and does not write kubeconfig, registry tokens, DR secrets, or bearer tokens."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-readiness-artifact-import.json"),
                """
                        {
                          "result": "failed",
                          "status": "artifact-import-failed",
                          "selectedGroupCount": 2,
                          "importedCount": 1,
                          "failedCount": 2,
                          "outputDirectory": ".osmu-run",
                          "secretPolicy": "Artifact import copies only JSON/Markdown evidence files and does not read kubeconfig, registry tokens, DR secrets, or bearer tokens.",
                          "entries": [
                            {
                              "group": "ha-dr-readiness",
                              "fileName": "latest-kubernetes-ha-dr-readiness.json",
                              "status": "failed",
                              "passed": false,
                              "detail": "result=failed expected=passed",
                              "sourcePath": ".osmu-run/operations-readiness-artifacts/ha-dr/latest-kubernetes-ha-dr-readiness.json",
                              "destinationPath": ""
                            },
                            {
                              "group": "iam-rbac",
                              "fileName": "latest-iam-rbac-finalize.json",
                              "status": "imported",
                              "passed": true,
                              "detail": "promoted to standard operations readiness path",
                              "sourcePath": ".osmu-run/operations-readiness-artifacts/iam/latest-iam-rbac-finalize.json",
                              "destinationPath": ".osmu-run/latest-iam-rbac-finalize.json"
                            }
                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-evidence-plan.json"),
                """
                        {
                          "result": "action-required",
                          "sourceSummary": "passed=36 pending=6",
                          "sourceReport": ".osmu-run/latest-operations-readiness.json",
                          "pendingCount": 6,
                          "actionCount": 6,
                          "unplannedCount": 0,
                          "actions": [
                            {
                              "order": 1,
                              "name": "Kubernetes DR finalizer evidence",
                              "category": "ha-dr",
                              "actionType": "kubernetes-live",
                              "evidencePath": ".osmu-run/latest-kubernetes-dr-finalize.json",
                              "requiredEvidence": "finalizer result=ready from target cluster restore drill",
                              "localCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/finalize-kubernetes-dr-drill.ps1 -ConfirmRestore",
                              "workflow": ".github/workflows/kubernetes-dr-finalizer-ci.yml",
                              "workflowCommand": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true",
                              "recommendedCommand": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true",
                              "operatorInputs": ["<YYYYMMDDTHHMMSSZ>"],
                              "hasPlaceholders": true,
                              "requiresOperatorApproval": true,
                              "requiresKubeconfigSecret": true,
                              "note": "Use confirmed restore evidence."
                            }
                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-handoff-package.json"),
                """
                        {
                          "formatVersion": "osmu.operations-handoff-package.v1",
                          "generatedAt": "2026-06-20T02:30:00Z",
                          "result": "failed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operatorName": "ops-admin",
                          "summary": {
                            "passedCount": 25,
                            "failureCount": 2,
                            "plannedCount": 1,
                            "checkCount": 28
                          },
                          "evidenceRefs": {
                            "operationsReadiness": "latest-operations-readiness-ready",
                            "operationsConvergence": "latest-operations-readiness-convergence-ready",
                            "commercialIntegration": "latest-commercial-integration-evidence-passed",
                            "commercialApproval": "latest-commercial-approval-evidence-passed",
                            "enterpriseAuth": "latest-enterprise-auth-smoke-scope-out",
                            "knownGaps": "known-gaps-acceptance-20260620"
                          },
                          "operationsSnapshots": {
                            "readiness": {
                              "provided": true,
                              "parsed": true,
                              "result": "ready",
                              "ready": true,
                              "summary": "passed=42 pending=0",
                              "passedCount": 42,
                              "pendingCount": 0,
                              "checkCount": 42
                            },
                            "convergence": {
                              "provided": true,
                              "parsed": true,
                              "result": "ready",
                              "ready": true,
                              "readinessResult": "ready",
                              "readinessSummary": "passed=42 pending=0",
                              "finalizerResult": "ready",
                              "finalizerReadinessResult": "ready",
                              "finalizerFailedCount": 0,
                              "finalizerFailedCountValid": true,
                              "finalizerFailedCountRaw": "0",
                              "finalizerGapCountValid": true,
                              "finalizerGapCountRaw": "0",
                              "kubernetesReportSyncReady": true,
                              "kubernetesReportSyncReadyValid": true,
                              "kubernetesReportSyncReadyRaw": "True",
                              "kubernetesReportSyncResult": "applied",
                              "kubernetesReportSyncFailedCount": 0,
                              "kubernetesReportSyncFailedCountValid": true,
                              "kubernetesReportSyncFailedCountRaw": "0",
                              "kubernetesReportSyncSourceReportResult": "ready",
                              "stageCount": 6,
                              "readyStageCount": 6,
                              "finalizerGapCount": 0,
                              "currentBottleneckCode": "",
                              "currentBottleneckTitle": "",
                              "recommendedCommandCount": 1
                            }
                          },
                          "targetEvidenceSnapshots": {
                            "dataFlowStoragePlan": {
                              "provided": true,
                              "path": ".osmu-run/latest-data-flow-storage-plan.json",
                              "parsed": true,
                              "formatVersion": "osmu.data-flow-storage-plan.v1",
                              "expectedFormatVersion": "osmu.data-flow-storage-plan.v1",
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "environmentName": "pilot-prod",
                              "targetCluster": "customer-cluster-a",
                              "candidateStore": "MARIADB_PARTITION",
                              "expectedPeakEventsPerDay": 250000,
                              "expectedQueryWindowDays": 180,
                              "targetP95QueryLatencyMs": 500,
                              "eventRetentionDays": 90,
                              "dailyRollupRetentionDays": 730,
                              "monthlyRollupRetentionMonths": 36,
                              "checkCount": 10,
                              "passedCount": 10,
                              "pendingCount": 0,
                              "queryPlanEvidence": {
                                "provided": true,
                                "formatVersion": "osmu.mariadb-query-plan-evidence.v1",
                                "expectedFormatVersion": "osmu.mariadb-query-plan-evidence.v1",
                                "validFormatVersion": true,
                                "result": "passed",
                                "mode": "fixture",
                                "checkCount": 3,
                                "passedCount": 3,
                                "failedCount": 0,
                                "failedChecks": [],
                                "detail": "formatVersion=osmu.mariadb-query-plan-evidence.v1; result=passed; mode=fixture; passed=3; failed=0; checks=3"
                              },
                              "topPendingChecks": []
                            },
                            "dataFlowStorageTransitionRunbook": {
                              "provided": true,
                              "path": ".osmu-run/latest-data-flow-storage-transition-runbook-evidence.json",
                              "parsed": true,
                              "formatVersion": "osmu.data-flow-storage-transition-runbook-evidence.v1",
                              "expectedFormatVersion": "osmu.data-flow-storage-transition-runbook-evidence.v1",
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "environmentName": "pilot-prod",
                              "targetCluster": "customer-cluster-a",
                              "operatorName": "ops-admin",
                              "evidenceRef": "latest-data-flow-storage-transition-runbook-passed",
                              "storagePlanResult": "passed",
                              "candidateStore": "MARIADB_PARTITION",
                              "targetP95QueryLatencyMs": 500,
                              "failureCount": 0,
                              "checkCount": 24,
                              "confirmations": {
                                "backfillRehearsed": true,
                                "rollbackRehearsed": true,
                                "reconciliationPassed": true,
                                "noSecretValues": true
                              },
                              "topFailedChecks": []
                            },
                            "secretRotation": {
                              "provided": true,
                              "path": ".osmu-run/latest-secret-rotation-evidence.json",
                              "parsed": true,
                              "formatVersion": "osmu.secret-rotation-evidence.v1",
                              "expectedFormatVersion": "osmu.secret-rotation-evidence.v1",
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "environmentName": "pilot-prod",
                              "targetCluster": "customer-cluster-a",
                              "operatorName": "ops-admin",
                              "rotationWindow": {
                                "startedAt": "2026-06-20T00:00:00Z",
                                "completedAt": "2026-06-20T00:30:00Z"
                              },
                              "evidenceRefs": {
                                "changeApproval": "CHG-2026-SECRET-ROTATION",
                                "secretManagerAudit": "vault-audit-run-20260620",
                                "workloadRestart": "rollout-status-run-20260620",
                                "smoke": "post-rotation-smoke-20260620",
                                "artifactLeakReview": "artifact-leak-review-20260620",
                                "accessKeyEncryptionDecision": "access-key-encryption-key-reissue-deferred-20260620"
                              },
                              "confirmations": {
                                "noSecretValues": true,
                                "workloadRestart": true,
                                "smokePassed": true,
                                "artifactLeakReview": true,
                                "requireAllCoreSecrets": true
                              },
                              "rotatedCount": 5,
                              "coreRotatedCount": 5,
                              "coreRequiredCount": 5,
                              "failureCount": 0,
                              "plannedCount": 0,
                              "checkCount": 16,
                              "rotations": [],
                              "topChecks": []
                            },
                            "commercialIntegration": {
                              "provided": true,
                              "path": ".osmu-run/latest-commercial-integration-evidence.json",
                              "parsed": true,
                              "formatVersion": "osmu.commercial-integration-evidence.v1",
                              "expectedFormatVersion": "osmu.commercial-integration-evidence.v1",
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "environmentName": "pilot-prod",
                              "targetCluster": "customer-cluster-a",
                              "operatorName": "commerce-ops",
                              "integrationCount": 8,
                              "verifiedCount": 8,
                              "requiredCount": 8,
                              "requiredVerifiedCount": 8,
                              "paymentProviderAdapterReadinessReviewed": true,
                              "paymentProviderAdapterReadinessStatus": "WEBHOOK_PROFILE_READY",
                              "paymentProviderAdapterWebhookReadyProfileCount": 5,
                              "paymentProviderAdapterNativeReadyProfileCount": 0,
                              "failureCount": 0,
                              "plannedCount": 0,
                              "checkCount": 8,
                              "topChecks": []
                            },
                            "commercialApproval": {
                              "provided": true,
                              "path": ".osmu-run/latest-commercial-approval-evidence.json",
                              "parsed": true,
                              "formatVersion": "osmu.commercial-approval-evidence.v1",
                              "expectedFormatVersion": "osmu.commercial-approval-evidence.v1",
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "productVersion": "osmu-mvp-0.1",
                              "approvedBy": "commercial-board",
                              "approvedAt": "2026-06-20T03:15:00Z",
                              "passedCount": 12,
                              "failureCount": 0,
                              "checkCount": 12,
                              "pricingPolicyProposalCommercialApproved": true,
                              "pricingPolicyProposalCommercialApprovedCount": 1,
                              "pricingPolicyProposalApprovedPriceListCount": 1,
                              "topChecks": []
                            },
                            "enterpriseAuthSmoke": {
                              "provided": true,
                              "path": ".osmu-run/latest-enterprise-auth-smoke.json",
                              "parsed": true,
                              "formatVersion": "osmu.enterprise-auth-smoke.v1",
                              "expectedFormatVersion": "osmu.enterprise-auth-smoke.v1",
                              "validFormatVersion": true,
                              "result": "scope-out",
                              "passed": false,
                              "scopeOutAccepted": true,
                              "accepted": true,
                              "executionMode": "scope-out",
                              "apiBase": "http://localhost:8080/api",
                              "requireOidc": true,
                              "requireLdap": true,
                              "requireAuditEvents": false,
                              "inputs": {
                                "adminPasswordProvided": false,
                                "oidcCallbackCodeProvided": false,
                                "oidcCallbackStateProvided": false,
                                "oidcClaimPreviewJsonPathProvided": false,
                                "oidcJitProvisionJsonPathProvided": false,
                                "confirmJitProvision": false,
                                "ldapLoginIdProvided": false,
                                "ldapPasswordProvided": false,
                                "expectedEmailProvided": false
                              },
                              "scopeOut": {
                                "confirmed": true,
                                "reference": "enterprise-auth-contract-scope-out-20260620",
                                "reason": "Pilot contract excludes SSO until customer IdP onboarding.",
                                "accepted": true
                              },
                              "passCount": 0,
                              "failCount": 0,
                              "blockedCount": 0,
                              "plannedCount": 0,
                              "skippedCount": 6,
                              "checkCount": 1,
                              "topChecks": [],
                              "decisionRule": "Paid/production pilot requires result=passed from the target IdP/directory, or result=scope-out with an explicit non-secret commercial approval reference and reason.",
                              "secretPolicy": "Admin password, LDAP password, access/refresh tokens, OIDC authorization code/state, client secrets, and raw OIDC claim JSON are never written to this evidence."
                            },
                            "monitoringThreshold": {
                              "provided": true,
                              "path": ".osmu-run/latest-monitoring-threshold-evidence.json",
                              "parsed": true,
                              "formatVersion": "osmu.monitoring-threshold-evidence.v1",
                              "expectedFormatVersion": "osmu.monitoring-threshold-evidence.v1",
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "environmentName": "pilot-prod",
                              "targetCluster": "customer-cluster-a",
                              "operatorName": "ops-admin",
                              "evidenceRef": "monitoring-threshold-run-20260621",
                              "requiredAlertCount": 11,
                              "mappedAlertCount": 11,
                              "missingAlertCount": 0,
                              "routeCount": 3,
                              "routes": ["osmu-backend", "osmu-data-flow", "osmu-backup"],
                              "grafanaPanelCount": 11,
                              "tuningEvidenceCount": 11,
                              "alertTargetCoverageComplete": true,
                              "routeCoverageComplete": true,
                              "grafanaPanelCoverageComplete": true,
                              "tuningEvidenceCoverageComplete": true,
                              "thresholdMappingComplete": true,
                              "confirmations": {
                                "prometheusRulesLoaded": true,
                                "grafanaDashboardImported": true,
                                "alertmanagerRoutesReviewed": true,
                                "targetBaselinesReviewed": true,
                                "incidentRoutingReviewed": true,
                                "noSecretValues": true
                              },
                              "complete": true,
                              "failureCount": 0,
                              "checkCount": 24,
                              "topFailedChecks": []
                            }
                          },
                          "confirmations": {
                            "noSecretValues": true,
                            "runbookReviewed": false,
                            "troubleshootingReviewed": true,
                            "rollbackReviewed": true,
                            "supportEscalationReviewed": false,
                            "knownGapsAccepted": true,
                            "secretRotationSnapshotReviewed": true,
                            "commercialIntegrationSnapshotReviewed": true,
                            "commercialApprovalSnapshotReviewed": true,
                            "enterpriseAuthSmokeSnapshotReviewed": true,
                            "monitoringThresholdReviewed": true,
                            "requireProductionEvidence": true
                          },
                          "checks": [
                            {
                              "id": "runbook-reviewed",
                              "name": "Operator runbook reviewed",
                              "status": "FAIL",
                              "passed": false,
                              "detail": "runbookReviewRef=",
                              "evidenceRef": ""
                            },
                            {
                              "id": "commercial-integration-evidence",
                              "name": "Commercial integration target evidence",
                              "status": "PASS",
                              "passed": true,
                              "detail": "required=true; evidenceRef=latest-commercial-integration-evidence-passed",
                              "evidenceRef": "latest-commercial-integration-evidence-passed"
                            }
                          ],
                          "decisionRule": "Production/B2B operations handoff package readiness requires result=passed.",
                          "scopePolicy": "This package is a handoff wrapper and does not execute kubectl, gh, provider APIs, notification adapters, or payment adapters.",
                          "secretPolicy": "Evidence stores references only and must not contain passwords, bearer tokens, kubeconfig values, private keys, provider credentials, raw provider responses, or customer payment data."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-commercial-integration-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.commercial-integration-evidence.v1",
                          "generatedAt": "2026-06-20T03:00:00Z",
                          "result": "failed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operatorName": "commerce-ops",
                          "summary": {
                            "integrationCount": 8,
                            "verifiedCount": 7,
                            "requiredCount": 8,
                            "requiredVerifiedCount": 7,
                            "paymentProviderAdapterReadinessReviewed": true,
                            "paymentProviderAdapterReadinessStatus": "WEBHOOK_PROFILE_READY",
                            "paymentProviderAdapterWebhookReadyProfileCount": 5,
                            "paymentProviderAdapterNativeReadyProfileCount": 0,
                            "failureCount": 1,
                            "plannedCount": 0
                          },
                          "checks": [
                            {
                              "id": "integration-payment-erp",
                              "name": "ERP payment webhook profile verified",
                              "status": "FAIL",
                              "passed": false,
                              "detail": "required=true verified=false evidenceRef="
                            },
                            {
                              "id": "payment-provider-adapter-readiness-reviewed",
                              "name": "Payment provider adapter readiness reviewed",
                              "status": "PASS",
                              "passed": true,
                              "detail": "reviewed=true"
                            }
                          ],
                          "decisionRule": "Production/B2B commercial integration readiness requires result=passed.",
                          "scopePolicy": "This evidence covers configured webhook/Slack/EMAIL SMTP relay and payment webhook profile handoff verification without claiming native processor API support.",
                          "secretPolicy": "Evidence stores references only and does not contain webhook URLs with credentials, SMTP passwords, payment provider credentials, signing secrets, bearer tokens, private keys, raw provider responses, or customer payment data."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-commercial-approval-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.commercial-approval-evidence.v1",
                          "generatedAt": "2026-06-20T03:30:00Z",
                          "result": "failed",
                          "productVersion": "osmu-mvp-0.1",
                          "approvedBy": "commercial-board",
                          "approvedAt": "2026-06-20T03:15:00Z",
                          "evidenceRefs": {
                            "approval": "commercial-approval-board-20260620",
                            "pricing": "pricing-approval-20260620",
                            "legal": "",
                            "pilotContract": "pilot-contract-boundary-20260620",
                            "pricingPolicyProposal": "pricing-policy-proposal-price-list-approved-20260620"
                          },
                          "confirmations": {
                            "pricingApproved": true,
                            "termsApproved": true,
                            "supportSlaApproved": true,
                            "licenseApproved": true,
                            "legalApproved": false,
                            "pricingPolicyProposalCommercialApproval": true,
                            "noSecretValues": true
                          },
                          "summary": {
                            "passedCount": 11,
                            "failureCount": 1,
                            "checkCount": 12,
                            "pricingPolicyProposalCommercialApproved": true,
                            "pricingPolicyProposalCommercialApprovedCount": 1,
                            "pricingPolicyProposalApprovedPriceListCount": 1
                          },
                          "checks": [
                            {
                              "id": "legal-approval-confirmed",
                              "name": "Legal approval confirmed",
                              "status": "FAIL",
                              "passed": false,
                              "detail": "legalApprovalRef=",
                              "evidenceRef": ""
                            },
                            {
                              "id": "pricing-policy-proposal-commercial-approved",
                              "name": "Billing pricing policy proposal commercial approval recorded",
                              "status": "PASS",
                              "passed": true,
                              "detail": "commercialApprovedCount=1",
                              "evidenceRef": "pricing-policy-proposal-price-list-approved-20260620"
                            }
                          ],
                          "decisionRule": "Production/B2B sale commercial approval requires result=passed.",
                          "scopePolicy": "This evidence records commercial/legal approval references and sanitized billing pricing policy proposal approval status only.",
                          "secretPolicy": "Evidence stores only sanitized approval references and must not contain passwords, tokens, private keys, license keys, signing secrets, customer payment data, raw price tables, or raw contract text."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-enterprise-auth-smoke.json"),
                """
                        {
                          "formatVersion": "osmu.enterprise-auth-smoke.v1",
                          "generatedAt": "2026-06-20T04:00:00Z",
                          "result": "planned",
                          "executionMode": "plan-only",
                          "apiBase": "http://localhost:8080/api",
                          "requireOidc": true,
                          "requireLdap": true,
                          "requireAuditEvents": false,
                          "scopeOut": {
                            "confirmed": false,
                            "reference": "",
                            "reason": "",
                            "accepted": false
                          },
                          "inputs": {
                            "adminLoginId": "admin",
                            "adminPasswordProvided": false,
                            "oidcCallbackCodeProvided": false,
                            "oidcCallbackStateProvided": false,
                            "ldapLoginIdProvided": false,
                            "ldapPasswordProvided": false
                          },
                          "summary": {
                            "passCount": 0,
                            "failCount": 0,
                            "blockedCount": 0,
                            "plannedCount": 8,
                            "skippedCount": 0
                          },
                          "checks": [
                            {
                              "id": "enterprise-auth-plan",
                              "name": "Enterprise auth plan API",
                              "category": "enterprise-auth",
                              "endpoint": "GET /api/admin/security/enterprise-auth-plan",
                              "status": "PLANNED",
                              "detail": "Confirms current login mode, OIDC readiness, LDAP readiness, mapping, and cutover gates.",
                              "requiredInputs": ["AdminPassword"]
                            },
                            {
                              "id": "ldap-login",
                              "name": "LDAP bind/search login for existing local user",
                              "category": "ldap",
                              "endpoint": "POST /api/auth/ldap/login",
                              "status": "PLANNED",
                              "detail": "LDAP password is never written to evidence.",
                              "requiredInputs": ["LdapLoginId", "LdapPassword"]
                            }
                          ],
                          "decisionRule": "Paid/production pilot requires result=passed from the target IdP/directory, or result=scope-out with an explicit non-secret commercial approval reference and reason.",
                          "secretPolicy": "Admin password, LDAP password, access/refresh tokens, OIDC authorization code/state, client secrets, raw OIDC claim JSON, and credential-like scope-out references are never written to this evidence."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-minio-bucket-cors-verification.json"),
                """
                        {
                          "formatVersion": "osmu.minio-bucket-cors-verification.v1",
                          "generatedAt": "2026-06-20T05:00:00Z",
                          "result": "failed",
                          "source": {
                            "mode": "cors-xml-path",
                            "bucketName": "uploads",
                            "minioAlias": "osmu-minio",
                            "sourceRef": ".osmu-run/minio-bucket-cors.xml",
                            "executeRequested": false,
                            "mcTimeoutSeconds": 30,
                            "rawCorsXmlStored": false
                          },
                          "summary": {
                            "ruleCount": 1,
                            "exposedHeaderCount": 2,
                            "failureCount": 1,
                            "plannedCount": 0
                          },
                          "cors": {
                            "ruleCount": 1,
                            "allowedOrigins": ["http://localhost:5173"],
                            "allowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
                            "allowedHeaders": ["*"],
                            "exposeHeaders": ["x-amz-request-id", "x-amz-id-2"],
                            "maxAgeSeconds": [3000]
                          },
                          "checks": [
                            {
                              "id": "expose-headers",
                              "name": "Required response headers are exposed",
                              "passed": false,
                              "detail": "Missing expose headers: ETag, x-amz-version-id."
                            }
                          ],
                          "decisionRule": "MinIO bucket CORS verification passes when browser upload headers are exposed.",
                          "scopePolicy": "This evidence verifies MinIO bucket CORS needed by OSMU browser multipart upload and traceability. It is not AWS S3 parity work, and it does not store raw CORS XML, credentials, bearer tokens, private keys, MinIO root credentials, or object data.",
                          "operatorCommands": {
                            "collectWithMc": "mc cors info <alias>/<bucket> > .\\\\.osmu-run\\\\minio-bucket-cors.xml",
                            "verifyFromFile": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\verify-minio-bucket-cors.ps1 -CorsXmlPath .\\\\.osmu-run\\\\minio-bucket-cors.xml -FailIfNotPassed",
                            "collectAndVerify": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\verify-minio-bucket-cors.ps1 -BucketName <bucket> -MinioAlias <alias> -Execute -FailIfNotPassed"
                          }
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-data-flow-storage-plan.json"),
                """
                        {
                          "formatVersion": "osmu.data-flow-storage-plan.v1",
                          "result": "plan-ready-execute-required",
                          "recordedAt": "2026-06-21T09:15:00Z",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operator": "ops-admin",
                          "evidenceRef": "data-flow-sizing-run-20260621",
                          "candidateStore": "MARIADB_PARTITION",
                          "expectedPeakEventsPerDay": 250000,
                          "expectedQueryWindowDays": 180,
                          "targetP95QueryLatencyMs": 500,
                          "eventRetentionDays": 90,
                          "dailyRollupRetentionDays": 730,
                          "monthlyRollupRetentionMonths": 36,
                          "scopePolicy": "OSMU operations analytics only. This plan is not AWS billing parity and aggregate stores must not include object keys or raw event messages.",
                          "checkCount": 4,
                          "passedCount": 2,
                          "pendingCount": 2,
                          "checks": [
                            {
                              "id": "aggregate_no_object_keys",
                              "title": "Aggregate stores exclude object keys and raw event messages",
                              "status": "passed",
                              "detail": "Monthly/materialized aggregate scope stays bucket/source/operation/status/time only.",
                              "nextAction": ""
                            },
                            {
                              "id": "target_query_latency_budget",
                              "title": "Target query latency budget captured",
                              "status": "passed",
                              "detail": "TargetP95QueryLatencyMs=500",
                              "nextAction": ""
                            },
                            {
                              "id": "explain_or_store_evidence",
                              "title": "Query plan or target-store evidence exists",
                              "status": "pending",
                              "detail": "MariaDB partition path needs EXPLAIN evidence.",
                              "nextAction": "Attach EXPLAIN evidence before enabling partitioned/time-series storage."
                            },
                            {
                              "id": "mariadb_query_plan_evidence",
                              "title": "MariaDB query plan evidence passed",
                              "status": "pending",
                              "detail": "No MariaDB query plan evidence JSON supplied.",
                              "nextAction": "Run scripts/write-mariadb-query-plan-evidence.ps1 with -Execute or -ExplainInputDir until result=passed, then rerun this storage plan."
                            }
                          ],
                          "queryPlanEvidence": {
                            "provided": false,
                            "path": "",
                            "parsed": false,
                            "formatVersion": "",
                            "expectedFormatVersion": "osmu.mariadb-query-plan-evidence.v1",
                            "validFormatVersion": false,
                            "result": "",
                            "mode": "",
                            "checkCount": 0,
                            "passedCount": 0,
                            "failedCount": 0,
                            "failedChecks": [],
                            "detail": "No MariaDB query plan evidence JSON supplied."
                          }
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-data-flow-storage-transition-runbook-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.data-flow-storage-transition-runbook-evidence.v1",
                          "generatedAt": "2026-06-21T09:30:00Z",
                          "result": "failed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operatorName": "ops-admin",
                          "evidenceRef": "data-flow-runbook-rehearsal-20260621",
                          "dataFlowStoragePlanSnapshot": {
                            "provided": true,
                            "path": ".osmu-run/latest-data-flow-storage-plan.json",
                            "parsed": true,
                            "formatVersion": "osmu.data-flow-storage-plan.v1",
                            "result": "plan-ready-execute-required",
                            "candidateStore": "MARIADB_PARTITION",
                            "targetP95QueryLatencyMs": 500,
                            "expectedPeakEventsPerDay": 250000,
                            "expectedQueryWindowDays": 180,
                            "pendingCount": 2,
                            "checkCount": 4,
                            "queryPlanEvidenceResult": "",
                            "detail": "formatVersion=osmu.data-flow-storage-plan.v1; result=plan-ready-execute-required; candidateStore=MARIADB_PARTITION; pending=2; targetP95QueryLatencyMs=500"
                          },
                          "confirmations": {
                            "backfillRehearsed": true,
                            "dualWriteOrPartitionToggleReviewed": false,
                            "rollbackRehearsed": true,
                            "reconciliationPassed": false,
                            "dashboardCutoverReviewed": true,
                            "retentionDryRunReviewed": true,
                            "noObjectKeysInAggregates": true,
                            "noSecretValues": true
                          },
                          "summary": {
                            "failureCount": 2,
                            "checkCount": 10
                          },
                          "checks": [
                            {
                              "id": "storage-plan-passed",
                              "name": "Data-flow storage plan passed",
                              "status": "FAIL",
                              "passed": false,
                              "detail": "storagePlanResult=plan-ready-execute-required"
                            },
                            {
                              "id": "reconciliation-passed",
                              "name": "Reconciliation passed",
                              "status": "FAIL",
                              "passed": false,
                              "detail": "Reconciliation evidence is missing."
                            }
                          ],
                          "scopePolicy": "OSMU operations analytics storage transition only. This is not AWS billing parity, and aggregate stores must not include object keys, raw messages, raw SQL, raw EXPLAIN JSON, or credentials."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-evidence-plan-invocation.json"),
                """
                        {
                          "result": "blocked",
                          "sourceSummary": "passed=36 pending=6",
                          "sourcePlan": ".osmu-run/latest-operations-evidence-plan.json",
                          "commandMode": "Workflow",
                          "executionMode": "plan-only",
                          "selectedActionCount": 6,
                          "plannedCount": 1,
                          "blockedCount": 5,
                          "executedCount": 0,
                          "failedCount": 0,
                          "actions": [
                            {
                              "order": 1,
                              "name": "Kubernetes DR finalizer evidence",
                              "category": "ha-dr",
                              "actionType": "kubernetes-live",
                              "evidencePath": ".osmu-run/latest-kubernetes-dr-finalize.json",
                              "commandMode": "Workflow",
                              "command": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true",
                              "status": "blocked",
                              "blockReasons": ["kubeconfig secret not confirmed"],
                              "unresolvedPlaceholders": ["<YYYYMMDDTHHMMSSZ>"],
                              "invalidPlaceholders": ["<restore-api-base>"],
                              "requiresOperatorApproval": true,
                              "requiresKubeconfigSecret": true
                            }
                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-invocation-unblock-plan.json"),
                """
                        {
                          "formatVersion": "osmu.operations-invocation-unblock-plan.v1",
                          "result": "action-required",
                          "sourceInvocationReport": ".osmu-run/latest-operations-evidence-plan-invocation.json",
                          "sourceResult": "blocked",
                          "sourceSummary": "passed=36 pending=6",
                          "selectedActionCount": 6,
                          "plannedCount": 1,
                          "blockedCount": 5,
                          "failedCount": 0,
                          "needsKubeconfigSecretConfirmation": true,
                          "needsOperatorApprovalConfirmation": true,
                          "requiredPlaceholderCount": 6,
                          "ambiguousRepeatedPlaceholderCount": 2,
                          "blockedActionOrders": [1, 2, 3, 4, 5],
                          "plannedActionOrders": [6],
                          "confirmedPlanCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2,3,4,5,6 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>",
                          "blockedOnlyPlanCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2,3,4,5 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>",
                          "plannedOnlyCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                          "decisionRule": "Resolve placeholders and confirmations before execution.",
                          "actions": [
                            {
                              "order": 1,
                              "name": "Kubernetes DR finalizer evidence",
                              "category": "ha-dr",
                              "actionType": "kubernetes-live",
                              "evidencePath": ".osmu-run/latest-kubernetes-dr-finalize.json",
                              "status": "blocked",
                              "commandMode": "Workflow",
                              "command": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true",
                              "blockReasons": ["kubeconfig secret not confirmed"],
                              "unresolvedPlaceholders": ["<YYYYMMDDTHHMMSSZ>"],
                              "invalidPlaceholders": ["<restore-api-base>"],
                              "requiresOperatorApproval": true,
                              "requiresKubeconfigSecret": true,
                              "needsOperatorApprovalConfirmation": true,
                              "needsKubeconfigSecretConfirmation": true,
                              "requiredInputs": [
                                {
                                  "placeholder": "<YYYYMMDDTHHMMSSZ>",
                                  "parameter": "BackupTimestamp",
                                  "valueTemplate": "<YYYYMMDDTHHMMSSZ>",
                                  "occurrenceCount": 1,
                                  "ambiguousRepeatedPlaceholder": false,
                                  "note": "Provide a concrete value before planning or executing this action."
                                }
                              ],
                              "ambiguousRepeatedPlaceholders": false,
                              "planCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>"
                            }
                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-dispatch-preflight.json"),
                """
                        {
                          "formatVersion": "osmu.operations-dispatch-preflight.v1",
                          "result": "action-required",
                          "sourceUnblockPlan": ".osmu-run/latest-operations-invocation-unblock-plan.json",
                          "sourceResult": "action-required",
                          "selectedActionCount": 6,
                          "selectedActionOrders": [1, 2, 3, 4, 5, 6],
                          "readyActionCount": 1,
                          "readyActionOrders": [6],
                          "blockedActionCount": 5,
                          "blockedActionOrders": [1, 2, 3, 4, 5],
                          "needsKubeconfigSecretConfirmation": true,
                          "needsOperatorApprovalConfirmation": true,
                          "requiredInputCount": 6,
                          "missingInputCount": 6,
                          "ambiguousInputCount": 2,
                          "unsafeInputCount": 1,
                          "invalidInputCount": 1,
                          "failedCheckCount": 3,
                          "warningCheckCount": 2,
                          "requiredGitHubSecrets": ["OSMU_KUBECONFIG_BASE64", "OSMU_ADMIN_PASSWORD", "GITHUB_TOKEN"],
                          "workflowFiles": [
                            {
                              "actionOrder": 1,
                              "workflow": "storage-expansion-finalizer-ci.yml",
                              "path": ".github/workflows/storage-expansion-finalizer-ci.yml",
                              "exists": true,
                              "requiredSecrets": ["OSMU_KUBECONFIG_BASE64", "OSMU_ADMIN_PASSWORD"]
                            }
                          ],
                          "checks": [
                            {
                              "code": "KUBECONFIG_SECRET_CONFIRMED",
                              "status": "fail",
                              "message": "Selected actions require OSMU_KUBECONFIG_BASE64 readiness confirmation."
                            }
                          ],
                          "readyPlanCommand": "",
                          "executeCommand": "",
                          "readySubsetPlanCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                          "readySubsetExecuteCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -Execute",
                          "requiredInputs": [
                            {
                              "actionOrder": 3,
                              "placeholder": "<YYYYMMDDTHHMMSSZ>",
                              "parameter": "BackupTimestamp",
                              "valueTemplate": "<YYYYMMDDTHHMMSSZ>",
                              "workflowInputs": ["backup_timestamp"],
                              "supplied": false,
                              "safeValue": true,
                              "validValue": true,
                              "valuePreview": "",
                              "ambiguousRepeatedPlaceholder": false,
                              "note": "Provide a concrete value before planning or executing this action."
                            }
                          ],
                          "inputTemplates": [
                            {
                              "actionOrder": 3,
                              "name": "Kubernetes DR finalizer evidence",
                              "category": "ha-dr",
                              "actionType": "kubernetes-live",
                              "commandMode": "Workflow",
                              "workflow": "kubernetes-dr-finalizer-ci.yml",
                              "needsOperatorApprovalConfirmation": true,
                              "needsKubeconfigSecretConfirmation": true,
                              "requiredSecrets": ["OSMU_KUBECONFIG_BASE64", "OSMU_ADMIN_PASSWORD"],
                              "workflowInputNames": ["backup_timestamp"],
                              "readyToDispatch": false,
                              "missingInputCount": 1,
                              "unsafeInputCount": 0,
                              "invalidInputCount": 0,
                              "ambiguousInputCount": 0,
                              "missingInputParameters": ["BackupTimestamp"],
                              "unsafeInputParameters": [],
                              "invalidInputParameters": [],
                              "inputs": [
                                {
                                  "actionOrder": 3,
                                  "placeholder": "<YYYYMMDDTHHMMSSZ>",
                                  "parameter": "BackupTimestamp",
                                  "valueTemplate": "<YYYYMMDDTHHMMSSZ>",
                                  "workflowInputs": ["backup_timestamp"],
                                  "supplied": false,
                                  "safeValue": true,
                                  "validValue": true,
                                  "valuePreview": "",
                                  "ambiguousRepeatedPlaceholder": false,
                                  "note": "Provide a concrete value before planning or executing this action."
                                }
                              ],
                              "operatorChecklist": ["Confirm operator approval", "Confirm OSMU_KUBECONFIG_BASE64 secret readiness", "Ensure GitHub secret OSMU_ADMIN_PASSWORD is configured", "Fill 1 required input value(s)"]
                            }
                          ],
                          "decisionRule": "Run the ready plan command first without -Execute."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-workflow-run-ids.json"),
                """
                        {
                          "result": "query-required",
                          "sourceInvocationReport": ".osmu-run/latest-operations-evidence-plan-invocation.json",
                          "invocationResult": "blocked",
                          "branch": "main",
                          "queryMode": "plan-only",
                          "limit": 20,
                          "workflowCount": 7,
                          "readyWorkflowCount": 0,
                          "missingWorkflowCount": 7,
                          "staleWorkflowCount": 0,
                          "imageSigningVersion": "v0.1.0-rc.1",
                          "commitSha": "abc123",
                          "artifactCollectionPlanCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha abc123",
                          "securityEvidenceFinalizerCommand": "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<image-signing-run-id>",
                          "decisionRule": "Use gh run list before artifact import.",
                          "workflows": [
                            {
                              "workflow": "storage-expansion-finalizer-ci.yml",
                              "group": "storage-expansion",
                              "queryCommand": "gh run list --workflow storage-expansion-finalizer-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle",
                              "queryMode": "plan-only",
                              "candidateCount": 0,
                              "recommendedRunId": "",
                              "readyForArtifactDownload": false,
                              "requiredForReadiness": true,
                              "runIdParameter": "StorageExpansionRunId",
                              "artifactName": "storage-expansion-finalizer-<run-id>",
                              "note": "Required by operations readiness artifact import."
                            }
                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-artifact-collection-plan.json"),
                """
                        {
                          "result": "action-required",
                          "sourceInvocationReport": ".osmu-run/latest-operations-evidence-plan-invocation.json",
                          "invocationResult": "blocked",
                          "invocationSummary": "selected=6 planned=1 blocked=5 executed=0 failed=0",
                          "artifactCount": 7,
                          "requiredArtifactCount": 5,
                          "readyArtifactCount": 0,
                          "missingRequiredArtifactCount": 5,
                          "securityEvidenceFinalizerCommand": "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=<image-signing-run-id>",
                          "operationsArtifactFinalizerCommand": "gh workflow run operations-readiness-artifact-finalizer-ci.yml -f storage_expansion_run_id=<storage-expansion-run-id> -f kubernetes_operations_report_sync_run_id=<kubernetes-operations-report-sync-run-id>",
                          "dataFlowStoragePlanInputNote": "Optional direct data-flow plan input: add -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> to operations-readiness-artifact-finalizer-ci.yml when target data-flow storage transition evidence should be imported without waiting for a Kubernetes operations report sync artifact. MariaDB partition or dual-write plans must include the sanitized query-plan evidence summary.",
                          "dataFlowStorageTransitionRunbookInputNote": "Optional direct data-flow transition runbook input: add -f data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json> to operations-readiness-artifact-finalizer-ci.yml when target transition rehearsal evidence should be imported without waiting for a manual workflow artifact. The snapshot must be sanitized and result=passed.",
                          "minioBucketCorsInputNote": "Optional MinIO bucket CORS input: add -f minio_bucket_cors_run_id=<minio-bucket-cors-run-id> -f minio_bucket_cors_artifact_name=minio-bucket-cors-verification-<minio-bucket-cors-run-id> to operations-readiness-artifact-finalizer-ci.yml to promote browser multipart upload CORS verification for dashboard visibility. This is not a readiness gate or AWS S3 parity work.",
                          "localImportCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\import-operations-readiness-artifacts.ps1 -StorageExpansionArtifactPath .\\\\.osmu-run\\\\operations-readiness-artifacts\\\\storage-expansion -KubernetesOperationsReportSyncArtifactPath .\\\\.osmu-run\\\\operations-readiness-artifacts\\\\kubernetes-operations-report-sync",
                          "decisionRule": "Fill missing run ids before importing artifacts.",
                          "artifacts": [
                            {
                              "group": "storage-expansion",
                              "workflow": "storage-expansion-finalizer-ci.yml",
                              "runId": "<storage-expansion-run-id>",
                              "runIdInput": "storage_expansion_run_id",
                              "artifactName": "storage-expansion-finalizer-<storage-expansion-run-id>",
                              "artifactNameInput": "storage_expansion_artifact_name",
                              "downloadPath": ".osmu-run/operations-readiness-artifacts/storage-expansion",
                              "downloadCommand": "gh run download <storage-expansion-run-id> -n storage-expansion-finalizer-<storage-expansion-run-id> -D .osmu-run/operations-readiness-artifacts/storage-expansion",
                              "requiredForReadiness": true,
                              "ready": false,
                              "note": "Imports latest-storage-expansion-finalize.json."
                            },
                            {
                              "group": "kubernetes-operations-report-sync",
                              "workflow": "kubernetes-operations-report-sync-ci.yml",
                              "runId": "<kubernetes-operations-report-sync-run-id>",
                              "runIdInput": "kubernetes_operations_report_sync_run_id",
                              "artifactName": "kubernetes-operations-report-sync-<kubernetes-operations-report-sync-run-id>",
                              "artifactNameInput": "kubernetes_operations_report_sync_artifact_name",
                              "downloadPath": ".osmu-run/operations-readiness-artifacts/kubernetes-operations-report-sync",
                              "downloadCommand": "gh run download <kubernetes-operations-report-sync-run-id> -n kubernetes-operations-report-sync-<kubernetes-operations-report-sync-run-id> -D .osmu-run/operations-readiness-artifacts/kubernetes-operations-report-sync",
                              "requiredForReadiness": true,
                              "ready": false,
                              "note": "Imports latest-kubernetes-operations-report-sync.json for convergence-level deployed dashboard sync evidence."
                            },
                            {
                              "group": "minio-bucket-cors",
                              "workflow": "manual-minio-bucket-cors-verification.yml",
                              "runId": "<minio-bucket-cors-run-id>",
                              "runIdInput": "minio_bucket_cors_run_id",
                              "artifactName": "minio-bucket-cors-verification-<minio-bucket-cors-run-id>",
                              "artifactNameInput": "minio_bucket_cors_artifact_name",
                              "downloadPath": ".osmu-run/operations-readiness-artifacts/minio-bucket-cors",
                              "downloadCommand": "gh run download <minio-bucket-cors-run-id> -n minio-bucket-cors-verification-<minio-bucket-cors-run-id> -D .osmu-run/operations-readiness-artifacts/minio-bucket-cors",
                              "requiredForReadiness": false,
                              "ready": false,
                              "note": "Imports latest-minio-bucket-cors-verification.json for dashboard browser multipart upload readiness. This is not a readiness gate or AWS S3 parity work."
                            }
                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-evidence-handoff.json"),
                """
                        {
                          "formatVersion": "osmu.operations-evidence-handoff.v1",
                          "generatedAt": "2026-06-16T07:15:09+09:00",
                          "result": "blocked",
                          "nextStep": {
                            "code": "dispatch-ready-subset",
                            "title": "Plan ready dispatch subset",
                            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                            "reason": "The invocation report still has blocked actions, but 1 action(s) are ready to dispatch: 6.",
                            "note": "Run the ready subset plan command first without -Execute, then dispatch only after review and continue resolving the remaining blocked actions. Execute command is available after plan review: powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -Execute"
                          },
                          "stageCount": 8,
                          "readyStageCount": 1,
                          "dispatchPreflightResult": "action-required",
                          "readyDispatchTemplateCount": 1,
                          "blockedDispatchTemplateCount": 5,
                          "readyDispatchActionOrders": [6],
                          "blockedDispatchActionOrders": [1, 2, 3, 4, 5],
                          "blockedActionCount": 5,
                          "missingWorkflowRunCount": 6,
                          "missingRequiredArtifactCount": 5,
                          "failedImportCount": 0,
                          "finalizerFailedCount": 0,
                          "finalizerGapCount": 1,
                          "stages": [
                            {
                              "name": "evidence-invocation",
                              "reportPath": ".osmu-run/latest-operations-evidence-plan-invocation.json",
                              "exists": true,
                              "result": "blocked",
                              "summary": "selected=6 planned=1 blocked=5 failed=0",
                              "ready": false,
                              "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1",
                              "note": "Guarded workflow/local command invocation report."
                            }
                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-readiness-convergence.json"),
                """
                        {
                          "formatVersion": "osmu.operations-readiness-convergence.v1",
                          "generatedAt": "2026-06-16T08:45:40+09:00",
                          "result": "action-required",
                          "handoffReportPath": ".osmu-run/latest-operations-evidence-handoff.json",
                          "readinessReportPath": ".osmu-run/latest-operations-readiness.json",
                          "operationsReadinessFinalizeReportPath": ".osmu-run/latest-operations-readiness-finalize.json",
                          "handoffExists": true,
                          "handoffResult": "blocked",
                          "readinessExists": true,
                          "readinessResult": "pending",
                          "readinessSummary": "passed=36 pending=6",
                          "finalizerExists": true,
                          "finalizerResult": "pending",
                          "finalizerReadinessResult": "pending",
                          "finalizerFailedCount": 0,
                          "finalizerFailedCountValid": false,
                          "finalizerFailedCountRaw": "0",
                          "kubernetesOperationsReportSyncReportPath": ".osmu-run/latest-kubernetes-operations-report-sync.json",
                          "kubernetesReportSyncExists": true,
                          "kubernetesReportSyncResult": "planned",
                          "kubernetesReportSyncFailedCount": 0,
                          "kubernetesReportSyncFailedCountValid": false,
                          "kubernetesReportSyncFailedCountRaw": "0",
                          "kubernetesReportSyncConfigMapName": "osmu-operations-reports",
                          "kubernetesReportSyncConfigMapKey": "latest-operations-readiness-convergence.json",
                          "kubernetesReportSyncSourceReportResult": "action-required",
                          "kubernetesReportSyncWorkflowCommand": "gh workflow run kubernetes-operations-report-sync-ci.yml -f namespace=osmu -f report_path=./.osmu-run/latest-operations-readiness-convergence.json -f run_live=true -f apply=false -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> -f data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>",
                          "kubernetesReportSyncWorkflowNote": "For GitHub Actions sync, include data_flow_storage_plan_json_base64 only when .osmu-run/latest-data-flow-storage-plan.json should be carried into the operations report ConfigMap, and include data_flow_storage_transition_runbook_json_base64 only when .osmu-run/latest-data-flow-storage-transition-runbook-evidence.json should be carried into the same ConfigMap. MariaDB partition or dual-write plans must include the sanitized query-plan evidence summary, and transition runbook evidence must be result=passed with no raw SQL, raw EXPLAIN, object keys, raw event messages, or credential-shaped content. Omit inputs when no target analytics-storage evidence is ready.",
                          "kubernetesReportSyncReady": false,
                          "finalizerGapCount": 1,
                          "stageCount": 8,
                          "readyStageCount": 1,
                          "dispatchPreflightResult": "action-required",
                          "readyDispatchTemplateCount": 1,
                          "blockedDispatchTemplateCount": 5,
                          "readyDispatchActionOrders": [6],
                          "blockedDispatchActionOrders": [1, 2, 3, 4, 5],
                          "blockedActionCount": 5,
                          "missingWorkflowRunCount": 6,
                          "missingRequiredArtifactCount": 5,
                          "failedImportCount": 0,
                          "currentBottleneck": {
                            "code": "dispatch-ready-subset",
                            "title": "Plan ready dispatch subset",
                            "reason": "The invocation report still has blocked actions, but 1 action(s) are ready to dispatch: 6.",
                            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6"
                          },
                          "recommendedCommands": [
                            {
                              "order": 1,
                              "name": "Plan ready dispatch subset",
                              "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                              "reason": "The invocation report still has blocked actions, but 1 action(s) are ready to dispatch: 6."
                            }
                          ],
                          "decisionRule": "Operations readiness convergence is ready only when the handoff result is ready/none, the readiness report is ready, the operations readiness finalizer report exists with result=ready, readinessResult=ready, failedCount=0, and no gaps, and the Kubernetes operations report sync evidence confirms result=applied, failedCount=0, and sourceReportResult=ready.",
                          "safetyPolicy": "This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-kubernetes-operations-report-sync.json"),
                """
                        {
                          "formatVersion": "osmu.kubernetes-operations-report-sync.v1",
                          "generatedAt": "2026-06-16T08:50:40+09:00",
                          "result": "planned",
                          "namespace": "osmu",
                          "configMapName": "osmu-operations-reports",
                          "configMapKey": "latest-operations-readiness-convergence.json",
                          "evidenceConfigMapKey": "latest-kubernetes-operations-report-sync.json",
                          "dataFlowStoragePlanConfigMapKey": "latest-data-flow-storage-plan.json",
                          "dataFlowStorageTransitionRunbookConfigMapKey": "latest-data-flow-storage-transition-runbook-evidence.json",
                          "publishDataFlowStoragePlanToConfigMap": true,
                          "publishDataFlowStorageTransitionRunbookToConfigMap": true,
                          "sourceReportPath": ".osmu-run/latest-operations-readiness-convergence.json",
                          "sourceReportFormatVersion": "osmu.operations-readiness-convergence.v1",
                          "sourceReportResult": "action-required",
                          "sourceReportBytes": 5249,
                          "sourceReportSha256": "abc123",
                          "dataFlowStorageTransitionRunbookResult": "failed",
                          "dataFlowStorageTransitionRunbookStoragePlanResult": "plan-ready-execute-required",
                          "dataFlowStorageTransitionRunbookCandidateStore": "MARIADB_PARTITION",
                          "dataFlowStorageTransitionRunbookFailureCount": 2,
                          "dataFlowStorageTransitionRunbookCheckCount": 10,
                          "dataFlowStorageTransitionRunbookBytes": 2048,
                          "dataFlowStorageTransitionRunbookSha256": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
                          "clientDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --dry-run=client -o yaml",
                          "serverDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --dry-run=server -o yaml",
                          "applyCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --dry-run=client -o yaml | kubectl apply -f -",
                          "checkCount": 3,
                          "failedCount": 0,
                          "checks": [
                            {
                              "name": "report-file-exists",
                              "passed": true,
                              "summary": "Report file exists.",
                              "command": "",
                              "exitCode": 0
                            }
                          ],
                          "safetyPolicy": "This script writes to Kubernetes only when -Apply is supplied. -ServerDryRunOnly talks to the API server without persisting changes. The default and -PlanOnly modes do not execute kubectl."
                        }
                        """
        );

        mockMvc.perform(get("/api/admin/dashboard/readiness")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("REVIEW"))
                .andExpect(jsonPath("$.data.items[*].category").value(hasItem("OPERATIONS")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_PENDING")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_EVIDENCE_PLAN")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_EVIDENCE_PLAN_INVOCATION")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_INVOCATION_UNBLOCK_PLAN")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_DISPATCH_PREFLIGHT")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_WORKFLOW_RUN_ID_PLAN")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_ARTIFACT_COLLECTION_PLAN")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_FINALIZER")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_EVIDENCE_HANDOFF")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("DATA_FLOW_STORAGE_PLAN")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("MINIO_BUCKET_CORS_VERIFICATION")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_CONVERGENCE")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("KUBERNETES_OPERATIONS_REPORT_SYNC")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_CHECK")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_ARTIFACT_IMPORT")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("DATA_FLOW_STORAGE_TRANSITION_RUNBOOK")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness remains pending: passed=36 pending=6.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations evidence plan is action-required: actionCount=6, unplannedCount=0.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations evidence invocation is blocked: selectedActionCount=6, plannedCount=1, blockedCount=5.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations invocation unblock plan is action-required: blockedActions=5, requiredPlaceholders=6, ambiguousPlaceholders=2.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations dispatch preflight is action-required: failedChecks=3, missingInputs=6, invalidInputs=1, warnings=2.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations workflow run id plan is query-required: workflows=7, missingRuns=7.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations artifact collection plan is action-required: artifacts=7, missingRequired=5.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness finalizer is pending: readinessResult=pending, failedCount=0.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations evidence handoff is blocked: next=dispatch-ready-subset, dispatchReady=1, dispatchBlocked=5, blockedActions=5, missingRuns=6, missingArtifacts=5, finalizerGaps=1.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Data-flow storage plan is plan-ready-execute-required: store=MARIADB_PARTITION, pending=2/4.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Data-flow transition runbook evidence is failed: store=MARIADB_PARTITION, failures=2/10.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("MinIO bucket CORS verification is failed: rules=1, exposedHeaders=2, failures=1, planned=0.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness convergence is action-required: bottleneck=dispatch-ready-subset, stages=1/8, finalizerGaps=1.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Kubernetes operations report sync is planned: namespace=osmu, configMap=osmu-operations-reports, failedCount=0. sourceReportResult=action-required.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness artifact import is failed: status=artifact-import-failed, failedCount=2.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_PLAN')].evidencePath").value(hasItem(".osmu-run/latest-operations-evidence-plan.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_PLAN')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-evidence-plan.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_PLAN_INVOCATION')].evidencePath").value(hasItem(".osmu-run/latest-operations-evidence-plan-invocation.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_PLAN_INVOCATION')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_INVOCATION_UNBLOCK_PLAN')].evidencePath").value(hasItem(".osmu-run/latest-operations-invocation-unblock-plan.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_INVOCATION_UNBLOCK_PLAN')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_INVOCATION_UNBLOCK_PLAN')].remediationWorkflowCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2,3,4,5,6 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_INVOCATION_UNBLOCK_PLAN')].remediationNote").value(hasItem("Resolve placeholders and confirmations before execution.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_DISPATCH_PREFLIGHT')].evidencePath").value(hasItem(".osmu-run/latest-operations-dispatch-preflight.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_DISPATCH_PREFLIGHT')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-dispatch-preflight.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_DISPATCH_PREFLIGHT')].remediationNote").value(hasItem("Run the ready plan command first without -Execute.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_WORKFLOW_RUN_ID_PLAN')].evidencePath").value(hasItem(".osmu-run/latest-operations-workflow-run-ids.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_WORKFLOW_RUN_ID_PLAN')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_ARTIFACT_COLLECTION_PLAN')].evidencePath").value(hasItem(".osmu-run/latest-operations-artifact-collection-plan.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_ARTIFACT_COLLECTION_PLAN')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_ARTIFACT_COLLECTION_PLAN')].remediationWorkflowCommand").value(hasItem("gh workflow run operations-readiness-artifact-finalizer-ci.yml -f storage_expansion_run_id=<storage-expansion-run-id> -f kubernetes_operations_report_sync_run_id=<kubernetes-operations-report-sync-run-id>")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_HANDOFF')].evidencePath").value(hasItem(".osmu-run/latest-operations-evidence-handoff.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_HANDOFF')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_HANDOFF')].remediationNote").value(hasItem("The invocation report still has blocked actions, but 1 action(s) are ready to dispatch: 6. Run the ready subset plan command first without -Execute, then dispatch only after review and continue resolving the remaining blocked actions. Execute command is available after plan review: powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -Execute")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_STORAGE_PLAN')].evidencePath").value(hasItem(".osmu-run/latest-data-flow-storage-plan.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_STORAGE_PLAN')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-data-flow-storage-plan.ps1 -CandidateStore <store> -ExpectedPeakEventsPerDay <n> -ExpectedQueryWindowDays <days> -TargetP95QueryLatencyMs <p95-ms> -ConfirmNoObjectKeyInAggregates -ConfirmBackfillPlan -ConfirmRollbackPlan -ConfirmDashboardCutoverPlan -ConfirmRetentionJobBudget -ConfirmExplainEvidence -QueryPlanEvidenceJsonPath .\\.osmu-run\\latest-mariadb-query-plan-evidence.json -RequireQueryPlanEvidence")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_STORAGE_PLAN')].remediationNote").value(hasItem("OSMU operations analytics only. This plan is not AWS billing parity and aggregate stores must not include object keys or raw event messages.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_STORAGE_TRANSITION_RUNBOOK')].evidencePath").value(hasItem(".osmu-run/latest-data-flow-storage-transition-runbook-evidence.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_STORAGE_TRANSITION_RUNBOOK')].remediationWorkflow").value(hasItem(".github/workflows/manual-data-flow-storage-transition-runbook-evidence.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'MINIO_BUCKET_CORS_VERIFICATION')].evidencePath").value(hasItem(".osmu-run/latest-minio-bucket-cors-verification.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'MINIO_BUCKET_CORS_VERIFICATION')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\verify-minio-bucket-cors.ps1 -BucketName <bucket> -MinioAlias <alias> -Execute -FailIfNotPassed")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'MINIO_BUCKET_CORS_VERIFICATION')].remediationNote").value(hasItem("This evidence verifies MinIO bucket CORS needed by OSMU browser multipart upload and traceability. It is not AWS S3 parity work, and it does not store raw CORS XML, credentials, bearer tokens, private keys, MinIO root credentials, or object data.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].evidencePath").value(hasItem(".osmu-run/latest-operations-readiness-artifact-import.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\import-operations-readiness-artifacts.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].remediationWorkflow").value(hasItem(".github/workflows/operations-readiness-artifact-finalizer-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].remediationNote").value(hasItem("Artifact import copies only JSON/Markdown evidence files and does not read kubeconfig, registry tokens, DR secrets, or bearer tokens.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].evidencePath").value(hasItem(".osmu-run/latest-operations-readiness-finalize.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\finalize-operations-readiness.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].remediationWorkflow").value(hasItem(".github/workflows/operations-readiness-finalizer-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].remediationNote").value(hasItem("Operations readiness finalizer masks admin passwords in recorded commands and does not write kubeconfig, registry tokens, DR secrets, or bearer tokens.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CONVERGENCE')].evidencePath").value(hasItem(".osmu-run/latest-operations-readiness-convergence.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CONVERGENCE')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CONVERGENCE')].remediationNote").value(hasItem("The invocation report still has blocked actions, but 1 action(s) are ready to dispatch: 6. This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].evidencePath").value(hasItem(".osmu-run/latest-kubernetes-operations-report-sync.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationCommand").value(hasItem("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --dry-run=server -o yaml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationWorkflow").value(hasItem(".github/workflows/kubernetes-operations-report-sync-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationWorkflowCommand").value(hasItem("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --dry-run=client -o yaml | kubectl apply -f -")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationNote").value(hasItem("This script writes to Kubernetes only when -Apply is supplied. -ServerDryRunOnly talks to the API server without persisting changes. The default and -PlanOnly modes do not execute kubectl.")))
                .andExpect(jsonPath("$.data.operationsEvidencePlan.result").value("action-required"))
                .andExpect(jsonPath("$.data.operationsEvidencePlan.sourceSummary").value("passed=36 pending=6"))
                .andExpect(jsonPath("$.data.operationsEvidencePlan.pendingCount").value(6))
                .andExpect(jsonPath("$.data.operationsEvidencePlan.actionCount").value(6))
                .andExpect(jsonPath("$.data.operationsEvidencePlan.unplannedCount").value(0))
                .andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].workflowCommand").value("gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true"))
                .andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].operatorInputs").value(hasItem("<YYYYMMDDTHHMMSSZ>")))
                .andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].requiresOperatorApproval").value(true))
                .andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].requiresKubeconfigSecret").value(true))
                .andExpect(jsonPath("$.data.operationsEvidenceInvocation.result").value("blocked"))
                .andExpect(jsonPath("$.data.operationsEvidenceInvocation.sourceSummary").value("passed=36 pending=6"))
                .andExpect(jsonPath("$.data.operationsEvidenceInvocation.selectedActionCount").value(6))
                .andExpect(jsonPath("$.data.operationsEvidenceInvocation.plannedCount").value(1))
                .andExpect(jsonPath("$.data.operationsEvidenceInvocation.blockedCount").value(5))
                .andExpect(jsonPath("$.data.operationsEvidenceInvocation.actions[0].status").value("blocked"))
                .andExpect(jsonPath("$.data.operationsEvidenceInvocation.actions[0].command").value("gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true"))
                .andExpect(jsonPath("$.data.operationsEvidenceInvocation.actions[0].blockReasons").value(hasItem("kubeconfig secret not confirmed")))
                .andExpect(jsonPath("$.data.operationsEvidenceInvocation.actions[0].unresolvedPlaceholders").value(hasItem("<YYYYMMDDTHHMMSSZ>")))
                .andExpect(jsonPath("$.data.operationsEvidenceInvocation.actions[0].invalidPlaceholders").value(hasItem("<restore-api-base>")))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.result").value("action-required"))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.sourceResult").value("blocked"))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.selectedActionCount").value(6))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.blockedCount").value(5))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.requiredPlaceholderCount").value(6))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.ambiguousRepeatedPlaceholderCount").value(2))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.needsKubeconfigSecretConfirmation").value(true))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.needsOperatorApprovalConfirmation").value(true))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.blockedActionOrders").value(hasItem(1)))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.plannedActionOrders").value(hasItem(6)))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.confirmedPlanCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2,3,4,5,6 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>"))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.actions[0].requiredInputs[0].parameter").value("BackupTimestamp"))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.actions[0].invalidPlaceholders").value(hasItem("<restore-api-base>")))
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.actions[0].planCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.result").value("action-required"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.sourceResult").value("action-required"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.selectedActionCount").value(6))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.selectedActionOrders").value(hasItem(1)))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.readyActionCount").value(1))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.readyActionOrders[0]").value(6))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.blockedActionCount").value(5))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.blockedActionOrders[0]").value(1))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.readySubsetPlanCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.readySubsetExecuteCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -Execute"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredInputCount").value(6))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.missingInputCount").value(6))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.unsafeInputCount").value(1))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.invalidInputCount").value(1))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.failedCheckCount").value(3))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.warningCheckCount").value(2))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredGitHubSecrets").value(hasItem("OSMU_KUBECONFIG_BASE64")))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.workflowFiles[0].workflow").value("storage-expansion-finalizer-ci.yml"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.workflowFiles[0].requiredSecrets").value(hasItem("OSMU_ADMIN_PASSWORD")))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.checks[0].code").value("KUBECONFIG_SECRET_CONFIRMED"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.checks[0].status").value("fail"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredInputs[0].parameter").value("BackupTimestamp"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredInputs[0].supplied").value(false))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredInputs[0].safeValue").value(true))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredInputs[0].validValue").value(true))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.inputTemplates[0].workflowInputNames[0]").value("backup_timestamp"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.inputTemplates[0].readyToDispatch").value(false))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.inputTemplates[0].missingInputParameters[0]").value("BackupTimestamp"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.inputTemplates[0].unsafeInputCount").value(0))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.inputTemplates[0].invalidInputCount").value(0))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.inputTemplates[0].operatorChecklist").value(hasItem("Ensure GitHub secret OSMU_ADMIN_PASSWORD is configured")))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.executeCommand").doesNotExist())
                .andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.result").value("query-required"))
                .andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.branch").value("main"))
                .andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflowCount").value(7))
                .andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.missingWorkflowCount").value(7))
                .andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.artifactCollectionPlanCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha abc123"))
                .andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].workflow").value("storage-expansion-finalizer-ci.yml"))
                .andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].queryCommand").value("gh run list --workflow storage-expansion-finalizer-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle"))
                .andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].readyForArtifactDownload").value(false))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.result").value("action-required"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.invocationResult").value("blocked"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifactCount").value(7))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.requiredArtifactCount").value(5))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.missingRequiredArtifactCount").value(5))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.operationsArtifactFinalizerCommand").value("gh workflow run operations-readiness-artifact-finalizer-ci.yml -f storage_expansion_run_id=<storage-expansion-run-id> -f kubernetes_operations_report_sync_run_id=<kubernetes-operations-report-sync-run-id>"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.dataFlowStoragePlanInputNote").value("Optional direct data-flow plan input: add -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> to operations-readiness-artifact-finalizer-ci.yml when target data-flow storage transition evidence should be imported without waiting for a Kubernetes operations report sync artifact. MariaDB partition or dual-write plans must include the sanitized query-plan evidence summary."))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.dataFlowStorageTransitionRunbookInputNote").value("Optional direct data-flow transition runbook input: add -f data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json> to operations-readiness-artifact-finalizer-ci.yml when target transition rehearsal evidence should be imported without waiting for a manual workflow artifact. The snapshot must be sanitized and result=passed."))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.minioBucketCorsInputNote").value("Optional MinIO bucket CORS input: add -f minio_bucket_cors_run_id=<minio-bucket-cors-run-id> -f minio_bucket_cors_artifact_name=minio-bucket-cors-verification-<minio-bucket-cors-run-id> to operations-readiness-artifact-finalizer-ci.yml to promote browser multipart upload CORS verification for dashboard visibility. This is not a readiness gate or AWS S3 parity work."))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].group").value("storage-expansion"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].downloadCommand").value("gh run download <storage-expansion-run-id> -n storage-expansion-finalizer-<storage-expansion-run-id> -D .osmu-run/operations-readiness-artifacts/storage-expansion"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].requiredForReadiness").value(true))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].ready").value(false))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[1].group").value("kubernetes-operations-report-sync"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[1].downloadCommand").value("gh run download <kubernetes-operations-report-sync-run-id> -n kubernetes-operations-report-sync-<kubernetes-operations-report-sync-run-id> -D .osmu-run/operations-readiness-artifacts/kubernetes-operations-report-sync"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[2].group").value("minio-bucket-cors"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[2].requiredForReadiness").value(false))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[2].note").value("Imports latest-minio-bucket-cors-verification.json for dashboard browser multipart upload readiness. This is not a readiness gate or AWS S3 parity work."))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.result").value("failed"))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.status").value("artifact-import-failed"))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.selectedGroupCount").value(2))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.importedCount").value(1))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.failedCount").value(2))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.outputDirectory").value(".osmu-run"))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.secretPolicy").value("Artifact import copies only JSON/Markdown evidence files and does not read kubeconfig, registry tokens, DR secrets, or bearer tokens."))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.entries[0].group").value("ha-dr-readiness"))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.entries[0].status").value("failed"))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.entries[0].passed").value(false))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.entries[0].detail").value("result=failed expected=passed"))
                .andExpect(jsonPath("$.data.operationsReadinessArtifactImport.entries[1].destinationPath").value(".osmu-run/latest-iam-rbac-finalize.json"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.result").value("pending"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.status").value("operations-readiness-finalize-pending"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.readinessResult").value("pending"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.readinessSummary").value("passed=36 pending=6"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.namespace").value("osmu"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.powerShellCommand").value("pwsh"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.failedCount").value(0))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.selectedSteps.storageExpansionFinalizer").value(true))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.paths.operationsReadinessJson").value(".osmu-run/latest-operations-readiness.json"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.paths.dataFlowStoragePlan").value(".osmu-run/latest-data-flow-storage-plan.json"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.paths.dataFlowStorageTransitionRunbookEvidence").value(".osmu-run/latest-data-flow-storage-transition-runbook-evidence.json"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.commands[0].name").value("Operations readiness report"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.commands[0].arguments").value(hasItem("-JsonOutputPath")))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.commands[0].arguments").value(hasItem("-DataFlowStorageTransitionRunbookEvidencePath")))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.steps[0].result").value("passed"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.gaps").value(hasItem("Operations readiness result is pending: passed=36 pending=6.")))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.secretPolicy").value("Operations readiness finalizer masks admin passwords in recorded commands and does not write kubeconfig, registry tokens, DR secrets, or bearer tokens."))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.result").value("failed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.environmentName").value("pilot-prod"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.targetCluster").value("customer-cluster-a"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operatorName").value("ops-admin"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.failureCount").value(2))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.plannedCount").value(1))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.checkCount").value(28))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.noSecretValues").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.runbookReviewed").value(false))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.secretRotationSnapshotReviewed").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.commercialIntegrationSnapshotReviewed").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.commercialApprovalSnapshotReviewed").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.enterpriseAuthSmokeSnapshotReviewed").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.monitoringThresholdReviewed").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.evidenceRefs.commercialApproval").value("latest-commercial-approval-evidence-passed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsReadinessSnapshot.result").value("ready"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsReadinessSnapshot.pendingCount").value(0))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncReady").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncSourceReportResult").value("ready"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerResult").value("ready"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerReadinessResult").value("ready"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerFailedCount").value(0))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerFailedCountValid").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerFailedCountRaw").value("0"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerGapCountValid").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerGapCountRaw").value("0"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncReadyValid").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncReadyRaw").value("True"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncFailedCountValid").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncFailedCountRaw").value("0"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerGapCount").value(0))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.stageCount").value(6))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.result").value("passed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.candidateStore").value("MARIADB_PARTITION"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.expectedPeakEventsPerDay").value(250000))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.targetP95QueryLatencyMs").value(500))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.pendingCount").value(0))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.queryPlanEvidence.result").value("passed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.queryPlanEvidence.failedCount").value(0))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.result").value("passed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.storagePlanResult").value("passed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.candidateStore").value("MARIADB_PARTITION"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.targetP95QueryLatencyMs").value(500))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.failureCount").value(0))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.confirmations.backfillRehearsed").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.confirmations.rollbackRehearsed").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.secretRotationSnapshot.result").value("passed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.secretRotationSnapshot.coreRotatedCount").value(5))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.secretRotationSnapshot.coreRequiredCount").value(5))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.secretRotationSnapshot.confirmations.smokePassed").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.commercialIntegrationSnapshot.result").value("passed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.commercialIntegrationSnapshot.requiredVerifiedCount").value(8))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.commercialIntegrationSnapshot.paymentProviderAdapterReadinessStatus").value("WEBHOOK_PROFILE_READY"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.commercialApprovalSnapshot.result").value("passed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.commercialApprovalSnapshot.productVersion").value("osmu-mvp-0.1"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.commercialApprovalSnapshot.pricingPolicyProposalApprovedPriceListCount").value(1))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthSmokeSnapshot.result").value("scope-out"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthSmokeSnapshot.executionMode").value("scope-out"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthSmokeSnapshot.scopeOut.accepted").value("true"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthSmokeSnapshot.skippedCount").value(6))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.result").value("passed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.mappedAlertCount").value(11))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.requiredAlertCount").value(11))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.routeCount").value(3))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.routes[1]").value("osmu-data-flow"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.confirmations.noSecretValues").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.checks[0].id").value("runbook-reviewed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.checks[0].status").value("FAIL"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.checks[1].evidenceRef").value("latest-commercial-integration-evidence-passed"))
                .andExpect(jsonPath("$.data.storageExpansionFinalize.result").value("failed"))
                .andExpect(jsonPath("$.data.storageExpansionFinalize.namespace").value("pilot-osmu"))
                .andExpect(jsonPath("$.data.storageExpansionFinalize.tenantName").value("osmu-minio"))
                .andExpect(jsonPath("$.data.storageExpansionFinalize.runBackendDryRunRunner").value(true))
                .andExpect(jsonPath("$.data.storageExpansionFinalize.runBackendApply").value(false))
                .andExpect(jsonPath("$.data.storageExpansionFinalize.runStorageBackendTelemetry").value(false))
                .andExpect(jsonPath("$.data.storageExpansionFinalize.failedCount").value(1))
                .andExpect(jsonPath("$.data.storageExpansionFinalize.evidence.rbacAuth").value(".osmu-run/latest-storage-expansion-rbac-auth.json"))
                .andExpect(jsonPath("$.data.storageExpansionFinalize.gaps[0]").value("Backend apply runner was not executed."))
                .andExpect(jsonPath("$.data.storageExpansionFinalize.steps[0].result").value("failed"))
                .andExpect(jsonPath("$.data.kubernetesHaDrReadiness.result").value("failed"))
                .andExpect(jsonPath("$.data.kubernetesHaDrReadiness.namespace").value("pilot-osmu"))
                .andExpect(jsonPath("$.data.kubernetesHaDrReadiness.failureCount").value(1))
                .andExpect(jsonPath("$.data.kubernetesHaDrReadiness.checks[1].name").value("pdb-osmu-minio-effective"))
                .andExpect(jsonPath("$.data.kubernetesHaDrReadiness.checks[1].passed").value(false))
                .andExpect(jsonPath("$.data.kubernetesDrFinalize.result").value("partial"))
                .andExpect(jsonPath("$.data.kubernetesDrFinalize.status").value("kubernetes-dr-finalize-partial"))
                .andExpect(jsonPath("$.data.kubernetesDrFinalize.sourceNamespace").value("pilot-osmu"))
                .andExpect(jsonPath("$.data.kubernetesDrFinalize.restoreNamespace").value("pilot-osmu-restore"))
                .andExpect(jsonPath("$.data.kubernetesDrFinalize.serverDryRunOnly").value(true))
                .andExpect(jsonPath("$.data.kubernetesDrFinalize.confirmRestore").value(false))
                .andExpect(jsonPath("$.data.kubernetesDrFinalize.commands[0].name").value("Kubernetes DR drill wrapper"))
                .andExpect(jsonPath("$.data.kubernetesDrFinalize.steps[0].result").value("skipped"))
                .andExpect(jsonPath("$.data.kubernetesDrFinalize.gaps[0]").value("Server-side dry-run only; no restore was executed."))
                .andExpect(jsonPath("$.data.iamRbacEvidence.result").value("failed"))
                .andExpect(jsonPath("$.data.iamRbacEvidence.status").value("iam-rbac-finalize-failed"))
                .andExpect(jsonPath("$.data.iamRbacEvidence.namespace").value("pilot-osmu"))
                .andExpect(jsonPath("$.data.iamRbacEvidence.serviceAccount").value("osmu-storage-expansion-runner"))
                .andExpect(jsonPath("$.data.iamRbacEvidence.runBackendPolicyTests").value(true))
                .andExpect(jsonPath("$.data.iamRbacEvidence.runKubernetesLiveAuth").value(true))
                .andExpect(jsonPath("$.data.iamRbacEvidence.failedCount").value(1))
                .andExpect(jsonPath("$.data.iamRbacEvidence.gaps[0]").value("Storage expansion live RBAC auth failed with exit code 1."))
                .andExpect(jsonPath("$.data.iamRbacEvidence.commands[0].name").value("IAM/RBAC matrix verifier"))
                .andExpect(jsonPath("$.data.iamRbacEvidence.steps[1].result").value("failed"))
                .andExpect(jsonPath("$.data.securityEvidence.result").value("failed"))
                .andExpect(jsonPath("$.data.securityEvidence.failureCount").value(1))
                .andExpect(jsonPath("$.data.securityEvidence.inputs.imageSigningEvidence").value(".osmu-run/latest-image-signing-evidence.json"))
                .andExpect(jsonPath("$.data.securityEvidence.source.containerSecurityArtifactName").value("osmu-container-security-abc123def456abc123def456abc123def456abcd"))
                .andExpect(jsonPath("$.data.securityEvidence.images.backendDigest").value("sha256:1111111111111111111111111111111111111111111111111111111111111111"))
                .andExpect(jsonPath("$.data.securityEvidence.checks[0].name").value("container security frontend scan"))
                .andExpect(jsonPath("$.data.securityEvidence.imageSigning.result").value("passed"))
                .andExpect(jsonPath("$.data.securityEvidence.imageSigning.version").value("v0.1.0-rc.1"))
                .andExpect(jsonPath("$.data.securityEvidence.imageSigning.backendVersionSignatureVerified").value(true))
                .andExpect(jsonPath("$.data.securityEvidence.containerSecurity.result").value("failed"))
                .andExpect(jsonPath("$.data.securityEvidence.containerSecurity.frontendScanPassed").value(false))
                .andExpect(jsonPath("$.data.securityEvidence.containerSecurity.backendSbomPackageCount").value(42))
                .andExpect(jsonPath("$.data.securityEvidence.containerSecurity.frontendSbomSha256").value("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"))
                .andExpect(jsonPath("$.data.secretRotationEvidence.result").value("failed"))
                .andExpect(jsonPath("$.data.secretRotationEvidence.environmentName").value("pilot-prod"))
                .andExpect(jsonPath("$.data.secretRotationEvidence.rotationWindow.startedAt").value("2026-06-20T00:00:00Z"))
                .andExpect(jsonPath("$.data.secretRotationEvidence.evidenceRefs.secretManagerAudit").value("vault-audit-run-20260620"))
                .andExpect(jsonPath("$.data.secretRotationEvidence.confirmations.noSecretValues").value(true))
                .andExpect(jsonPath("$.data.secretRotationEvidence.confirmations.smokePassed").value(false))
                .andExpect(jsonPath("$.data.secretRotationEvidence.coreRotatedCount").value(4))
                .andExpect(jsonPath("$.data.secretRotationEvidence.coreRequiredCount").value(5))
                .andExpect(jsonPath("$.data.secretRotationEvidence.failureCount").value(2))
                .andExpect(jsonPath("$.data.secretRotationEvidence.rotations[1].id").value("tls-certificate"))
                .andExpect(jsonPath("$.data.secretRotationEvidence.rotations[1].rotated").value(false))
                .andExpect(jsonPath("$.data.secretRotationEvidence.checks[0].id").value("smoke-passed-confirmed"))
                .andExpect(jsonPath("$.data.commercialIntegrationEvidence.result").value("failed"))
                .andExpect(jsonPath("$.data.commercialIntegrationEvidence.environmentName").value("pilot-prod"))
                .andExpect(jsonPath("$.data.commercialIntegrationEvidence.requiredVerifiedCount").value(7))
                .andExpect(jsonPath("$.data.commercialIntegrationEvidence.requiredCount").value(8))
                .andExpect(jsonPath("$.data.commercialIntegrationEvidence.paymentProviderAdapterReadinessStatus").value("WEBHOOK_PROFILE_READY"))
                .andExpect(jsonPath("$.data.commercialIntegrationEvidence.checks[0].id").value("integration-payment-erp"))
                .andExpect(jsonPath("$.data.commercialApprovalEvidence.result").value("failed"))
                .andExpect(jsonPath("$.data.commercialApprovalEvidence.productVersion").value("osmu-mvp-0.1"))
                .andExpect(jsonPath("$.data.commercialApprovalEvidence.confirmations.legalApproved").value(false))
                .andExpect(jsonPath("$.data.commercialApprovalEvidence.evidenceRefs.pricingPolicyProposal").value("pricing-policy-proposal-price-list-approved-20260620"))
                .andExpect(jsonPath("$.data.commercialApprovalEvidence.pricingPolicyProposalApprovedPriceListCount").value(1))
                .andExpect(jsonPath("$.data.commercialApprovalEvidence.checks[0].id").value("legal-approval-confirmed"))
                .andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.result").value("planned"))
                .andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.executionMode").value("plan-only"))
                .andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.requireOidc").value(true))
                .andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.requireLdap").value(true))
                .andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.inputs.adminPasswordProvided").value(false))
                .andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.inputs.adminLoginId").doesNotExist())
                .andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.scopeOut.accepted").value("false"))
                .andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.plannedCount").value(8))
                .andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.checks[0].endpoint").value("GET /api/admin/security/enterprise-auth-plan"))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.result").value("failed"))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.sourceMode").value("cors-xml-path"))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.bucketName").value("uploads"))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.minioAlias").value("osmu-minio"))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.rawCorsXmlStored").value(false))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.ruleCount").value(1))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.exposedHeaderCount").value(2))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.failureCount").value(1))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.allowedMethods[1]").value("PUT"))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.exposeHeaders[0]").value("x-amz-request-id"))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.maxAgeSeconds[0]").value(3000))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.checks[0].id").value("expose-headers"))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.checks[0].passed").value(false))
                .andExpect(jsonPath("$.data.minioBucketCorsVerification.operatorCommands.collectAndVerify").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\verify-minio-bucket-cors.ps1 -BucketName <bucket> -MinioAlias <alias> -Execute -FailIfNotPassed"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.result").value("plan-ready-execute-required"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.environmentName").value("pilot-prod"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.targetCluster").value("customer-cluster-a"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.operatorName").value("ops-admin"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.evidenceRef").value("data-flow-sizing-run-20260621"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.candidateStore").value("MARIADB_PARTITION"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.expectedPeakEventsPerDay").value(250000))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.expectedQueryWindowDays").value(180))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.targetP95QueryLatencyMs").value(500))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.eventRetentionDays").value(90))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.dailyRollupRetentionDays").value(730))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.monthlyRollupRetentionMonths").value(36))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.checkCount").value(4))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.passedCount").value(2))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.pendingCount").value(2))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.checks[0].id").value("aggregate_no_object_keys"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.checks[1].id").value("target_query_latency_budget"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.checks[2].status").value("pending"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.checks[2].nextAction").value("Attach EXPLAIN evidence before enabling partitioned/time-series storage."))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.checks[3].id").value("mariadb_query_plan_evidence"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.queryPlanEvidence.provided").value(false))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.queryPlanEvidence.expectedFormatVersion").value("osmu.mariadb-query-plan-evidence.v1"))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.queryPlanEvidence.detail").value("No MariaDB query plan evidence JSON supplied."))
                .andExpect(jsonPath("$.data.dataFlowStoragePlan.scopePolicy", org.hamcrest.Matchers.containsString("not AWS billing parity")))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.result").value("failed"))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.environmentName").value("pilot-prod"))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.targetCluster").value("customer-cluster-a"))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.evidenceRef").value("data-flow-runbook-rehearsal-20260621"))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.storagePlanResult").value("plan-ready-execute-required"))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.candidateStore").value("MARIADB_PARTITION"))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.targetP95QueryLatencyMs").value(500))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.failureCount").value(2))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.checkCount").value(10))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.confirmations.dualWriteOrPartitionToggleReviewed").value(false))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.topFailedChecks[0].id").value("storage-plan-passed"))
                .andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.scopePolicy", org.hamcrest.Matchers.containsString("not AWS billing parity")))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.result").value("passed"))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.environmentName").value("pilot-prod"))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.targetCluster").value("customer-cluster-a"))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.sourceMode").value("admin-info-json-path"))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.minioAlias").value("osmu-minio"))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.rawAdminInfoStored").value(false))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.poolCount").value(1))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.serverCount").value(2))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.offlineServerCount").value(0))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.driveCount").value(4))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.totalBytes").value(4398046511104L))
                .andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.scopePolicy", org.hamcrest.Matchers.containsString("not AWS S3 parity work")))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.result").value("passed"))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.environmentName").value("pilot-prod"))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.targetCluster").value("customer-cluster-a"))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.evidenceRef").value("monitoring-threshold-run-20260621"))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.reviewWindow.startedAt").value("2026-06-21T08:40:00Z"))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.requiredAlertCount").value(11))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.mappedAlertCount").value(11))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.routeCount").value(3))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.routes[1]").value("osmu-data-flow"))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.grafanaPanelCount").value(11))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.tuningEvidenceCount").value(11))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.alertTargetCoverageComplete").value(true))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.routeCoverageComplete").value(true))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.grafanaPanelCoverageComplete").value(true))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.tuningEvidenceCoverageComplete").value(true))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.thresholdMappingComplete").value(true))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.evidenceRefs.incidentRouting").value("incident-routing-review-20260621"))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.confirmations.noSecretValues").value(true))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.failureCount").value(0))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.checkCount").value(24))
                .andExpect(jsonPath("$.data.monitoringThresholdEvidence.checks[0].id").value("prometheus-rules-loaded-confirmed"))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_HANDOFF_PACKAGE')].evidencePath").value(hasItem(".osmu-run/latest-operations-handoff-package.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_HANDOFF_PACKAGE')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-handoff-package.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'STORAGE_EXPANSION_FINALIZE')].evidencePath").value(hasItem(".osmu-run/latest-storage-expansion-finalize.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'STORAGE_EXPANSION_FINALIZE')].remediationWorkflow").value(hasItem(".github/workflows/storage-expansion-finalizer-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_HA_DR_READINESS')].evidencePath").value(hasItem(".osmu-run/latest-kubernetes-ha-dr-readiness.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_HA_DR_READINESS')].remediationWorkflow").value(hasItem(".github/workflows/kubernetes-ha-dr-readiness-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_DR_FINALIZE')].evidencePath").value(hasItem(".osmu-run/latest-kubernetes-dr-finalize.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_DR_FINALIZE')].remediationWorkflow").value(hasItem(".github/workflows/kubernetes-dr-finalizer-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'IAM_RBAC_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-iam-rbac-finalize.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'IAM_RBAC_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/iam-rbac-finalizer-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'SECURITY_EVIDENCE_FINALIZE')].evidencePath").value(hasItem(".osmu-run/latest-security-evidence-finalize.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'SECURITY_EVIDENCE_FINALIZE')].remediationWorkflow").value(hasItem(".github/workflows/security-evidence-finalizer-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'SECRET_ROTATION_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-secret-rotation-evidence.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'SECRET_ROTATION_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/manual-secret-rotation-evidence.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'COMMERCIAL_INTEGRATION_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-commercial-integration-evidence.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'COMMERCIAL_INTEGRATION_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/manual-commercial-integration-evidence.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'COMMERCIAL_APPROVAL_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-commercial-approval-evidence.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'COMMERCIAL_APPROVAL_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/manual-commercial-approval-evidence.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'ENTERPRISE_AUTH_SMOKE_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-enterprise-auth-smoke.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'ENTERPRISE_AUTH_SMOKE_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/enterprise-auth-smoke-ci.yml")))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.result").value("blocked"))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.nextStep.code").value("dispatch-ready-subset"))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.nextStep.command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6"))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.readyDispatchTemplateCount").value(1))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.blockedDispatchTemplateCount").value(5))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.readyDispatchActionOrders[0]").value(6))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.blockedDispatchActionOrders[0]").value(1))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.blockedActionCount").value(5))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.missingWorkflowRunCount").value(6))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.missingRequiredArtifactCount").value(5))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.finalizerFailedCount").value(0))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.finalizerGapCount").value(1))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.stages[0].name").value("evidence-invocation"))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.stages[0].summary").value("selected=6 planned=1 blocked=5 failed=0"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.result").value("action-required"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffResult").value("blocked"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.readinessResult").value("pending"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.finalizerReadinessResult").value("pending"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.currentBottleneck.code").value("dispatch-ready-subset"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.currentBottleneck.command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.recommendedCommands[0].name").value("Plan ready dispatch subset"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.stageCount").value(8))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.readyStageCount").value(1))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncExists").value(true))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncResult").value("planned"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncFailedCount").value(0))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.finalizerFailedCountValid").value(false))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.finalizerFailedCountRaw").value("0"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncFailedCountValid").value(false))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncFailedCountRaw").value("0"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncConfigMapName").value("osmu-operations-reports"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncWorkflowCommand").value("gh workflow run kubernetes-operations-report-sync-ci.yml -f namespace=osmu -f report_path=./.osmu-run/latest-operations-readiness-convergence.json -f run_live=true -f apply=false -f data_flow_storage_plan_json_base64=<base64-latest-data-flow-storage-plan-json> -f data_flow_storage_transition_runbook_json_base64=<base64-latest-data-flow-storage-transition-runbook-json>"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncWorkflowNote").value(containsString("Omit inputs")))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncReady").value(false))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.finalizerGapCount").value(1))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.safetyPolicy").value("This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance."))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.result").value("planned"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.namespace").value("osmu"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.configMapName").value("osmu-operations-reports"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.sourceReportFormatVersion").value("osmu.operations-readiness-convergence.v1"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.sourceReportResult").value("action-required"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.sourceReportBytes").value(5249))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.sourceReportSha256").value("abc123"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookConfigMapKey").value("latest-data-flow-storage-transition-runbook-evidence.json"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.publishDataFlowStorageTransitionRunbookToConfigMap").value(true))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookResult").value("failed"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookStoragePlanResult").value("plan-ready-execute-required"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookCandidateStore").value("MARIADB_PARTITION"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookFailureCount").value(2))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookCheckCount").value(10))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.serverDryRunCommand").value("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --dry-run=server -o yaml"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.applyCommand").value("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --dry-run=client -o yaml | kubectl apply -f -"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.checkCount").value(3))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.failedCount").value(0))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.checks[0].name").value("report-file-exists"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.checks[0].passed").value(true))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.safetyPolicy").value("This script writes to Kubernetes only when -Apply is supplied. -ServerDryRunOnly talks to the API server without persisting changes. The default and -PlanOnly modes do not execute kubectl."))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CHECK')].evidencePath").value(hasItem(".osmu-run/latest-kubernetes-dr-finalize.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CHECK')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/finalize-kubernetes-dr-drill.ps1 -ConfirmRestore")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CHECK')].remediationWorkflow").value(hasItem(".github/workflows/kubernetes-dr-finalizer-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CHECK')].remediationWorkflowCommand").value(hasItem("gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CHECK')].remediationNote").value(hasItem("Use confirmed restore evidence.")))
                .andExpect(jsonPath("$.data.items[*].targetPanel").value(hasItem("dashboard-readiness-panel")));
    }

    @Test
    void dashboardReadinessKeepsKubernetesSyncWarningUntilSourceReportReady() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        Files.createDirectories(Path.of(".osmu-run"));
        Files.writeString(
                Path.of(".osmu-run/latest-kubernetes-operations-report-sync.json"),
                """
                        {
                          "formatVersion": "osmu.kubernetes-operations-report-sync.v1",
                          "generatedAt": "2026-06-16T08:50:40+09:00",
                          "result": "applied",
                          "namespace": "osmu",
                          "configMapName": "osmu-operations-reports",
                          "configMapKey": "latest-operations-readiness-convergence.json",
                          "sourceReportPath": ".osmu-run/latest-operations-readiness-convergence.json",
                          "sourceReportFormatVersion": "osmu.operations-readiness-convergence.v1",
                          "sourceReportResult": "action-required",
                          "sourceReportBytes": 5249,
                          "sourceReportSha256": "abc123",
                          "clientDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --dry-run=client -o yaml",
                          "serverDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --dry-run=server -o yaml",
                          "applyCommand": "kubectl apply -f -",
                          "checkCount": 1,
                          "failedCount": 0,
                          "checks": [
                            {
                              "name": "report-file-exists",
                              "passed": true,
                              "summary": "Report file exists.",
                              "command": "",
                              "exitCode": 0
                            }
                          ],
                          "safetyPolicy": "No implicit Kubernetes writes."
                        }
                        """
        );

        mockMvc.perform(get("/api/admin/dashboard/readiness")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("KUBERNETES_OPERATIONS_REPORT_SYNC")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Kubernetes operations report sync is applied: namespace=osmu, configMap=osmu-operations-reports, failedCount=0. sourceReportResult=action-required.")))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.result").value("applied"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.failedCount").value(0))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.sourceReportResult").value("action-required"));

        Files.writeString(
                Path.of(".osmu-run/latest-kubernetes-operations-report-sync.json"),
                """
                        {
                          "formatVersion": "osmu.kubernetes-operations-report-sync.v1",
                          "generatedAt": "2026-06-16T08:55:40+09:00",
                          "result": "applied",
                          "namespace": "osmu",
                          "configMapName": "osmu-operations-reports",
                          "configMapKey": "latest-operations-readiness-convergence.json",
                          "sourceReportPath": ".osmu-run/latest-operations-readiness-convergence.json",
                          "sourceReportFormatVersion": "osmu.operations-readiness-convergence.v1",
                          "sourceReportResult": "ready",
                          "sourceReportBytes": 5249,
                          "sourceReportSha256": "def456",
                          "clientDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --dry-run=client -o yaml",
                          "serverDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --dry-run=server -o yaml",
                          "applyCommand": "kubectl apply -f -",
                          "checkCount": 1,
                          "failedCount": 0,
                          "checks": [
                            {
                              "name": "report-file-exists",
                              "passed": true,
                              "summary": "Report file exists.",
                              "command": "",
                              "exitCode": 0
                            }
                          ],
                          "safetyPolicy": "No implicit Kubernetes writes."
                        }
                        """
        );

        mockMvc.perform(get("/api/admin/dashboard/readiness")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[*].code").value(not(hasItem("KUBERNETES_OPERATIONS_REPORT_SYNC"))))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.result").value("applied"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.failedCount").value(0))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.sourceReportResult").value("ready"));
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
}
