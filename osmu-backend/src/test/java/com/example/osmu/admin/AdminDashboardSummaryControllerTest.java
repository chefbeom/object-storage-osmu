package com.example.osmu.admin;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasItems;
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
import org.springframework.test.web.servlet.ResultActions;

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
                          "summary": "passed=82 pending=20",
                          "generatedAt": "2026-06-27T00:00:00Z",
                          "passedCount": 82,
                          "pendingCount": 20,
                          "totalCount": 102,
                          "checkCount": 102,
                          "pendingCategorySummary": "chargeback-closeout=1, commercial-approval=1, commercial-integration=1, data-flow=3, enterprise-auth=2, ha-dr=2, monitoring=1, operations-handoff-package=1, security-hardening=6, storage-backend=1, storage-expansion=1",
                          "pendingCategoryCounts": [
                            { "category": "chargeback-closeout", "count": 1 },
                            { "category": "commercial-approval", "count": 1 },
                            { "category": "commercial-integration", "count": 1 },
                            { "category": "data-flow", "count": 3 },
                            { "category": "enterprise-auth", "count": 2 },
                            { "category": "ha-dr", "count": 2 },
                            { "category": "monitoring", "count": 1 },
                            { "category": "operations-handoff-package", "count": 1 },
                            { "category": "security-hardening", "count": 6 },
                            { "category": "storage-backend", "count": 1 },
                            { "category": "storage-expansion", "count": 1 }
                          ],
                          "pendingRemediationCount": 1,
                          "pendingRemediations": [
                            {
                              "name": "Kubernetes DR finalizer evidence",
                              "category": "HA_DR",
                              "evidencePath": ".osmu-run/latest-kubernetes-dr-finalize.json",
                              "requiredEvidence": "Kubernetes DR finalizer result=ready",
                              "detail": "missing latest-kubernetes-dr-finalize.json",
                              "command": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/finalize-kubernetes-dr-drill.ps1 -ConfirmRestore",
                              "workflow": ".github/workflows/kubernetes-dr-finalizer-ci.yml",
                              "workflowCommand": "gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true",
                              "note": "Use confirmed restore evidence."
                            }
                          ],
                          "decisionRule": "Production/B2B operations readiness is ready only when every listed evidence check is PASS.",
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
                Path.of(".osmu-run/latest-cluster-network-access-review-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.cluster-network-access-review-evidence.v1",
                          "generatedAt": "2026-06-24T02:00:00Z",
                          "result": "failed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operator": "network-admin",
                          "reviewWindow": { "startedAt": "2026-06-24T01:30:00Z", "completedAt": "2026-06-24T02:00:00Z", "ordered": true },
                          "evidence": {
                            "changeApprovalRef": "CHG-2026-NETWORK-HARDENING",
                            "dnsEgressReviewRef": "dns-egress-review-20260624",
                            "mariaDbAccessReviewRef": "mariadb-access-review-20260624",
                            "minioAccessReviewRef": "minio-access-review-20260624",
                            "backupAccessReviewRef": "backup-access-review-20260624",
                            "publicIngressReviewRef": "public-ingress-review-20260624",
                            "defaultDenyReviewRef": "default-deny-review-20260624",
                            "observabilityScrapeReviewRef": "observability-review-20260624",
                            "k8sVerifierEvidenceRef": "k8s-networkpolicy-verifier-20260624",
                            "helmVerifierEvidenceRef": "helm-networkpolicy-verifier-20260624",
                            "evidenceRef": "cluster-network-access-review-20260624"
                          },
                          "staticControlSnapshot": {
                            "networkPolicyManifestPath": "infra/k8s/networkpolicy.yaml",
                            "networkPolicyManifestSha256": "abc123",
                            "helmValuesPath": "infra/helm/osmu/values.yaml",
                            "helmValuesSha256": "def456",
                            "requiredPolicyNamesPresent": true,
                            "backendEgressScoped": true,
                            "backupEgressScoped": true,
                            "dnsEgressScoped": false,
                            "mariaDbIngressScoped": true,
                            "minioIngressScoped": true,
                            "noBroadCidr": true,
                            "helmNetworkPolicyEnabled": true
                          },
                          "confirmations": {
                            "backendOnlyMariaDb": true,
                            "backendOnlyMinio": true,
                            "backupOnlyMariaDbMinio": true,
                            "dnsEgressScoped": false,
                            "mariaDbIngressBackendBackupOnly": true,
                            "minioIngressBackendBackupOnly": true,
                            "publicIngressLimited": true,
                            "namespaceDefaultDenyReviewed": true,
                            "observabilityScrapeReviewed": true,
                            "helmNetworkPolicyEnabled": true,
                            "noCredentialValues": true
                          },
                          "summary": { "passCount": 20, "failureCount": 1, "totalCount": 21 },
                          "checks": [ { "id": "dns-egress-review-confirmed", "name": "DNS egress scope confirmed", "status": "FAIL", "passed": false, "detail": "Operator must confirm DNS egress is scoped to cluster DNS.", "evidenceRef": "dns-egress-review-20260624" } ],
                          "scopePolicy": "Reviews static Kubernetes/Helm NetworkPolicy and operator-approved access references; it does not execute kubectl or prove live CNI enforcement.",
                          "secretPolicy": "Evidence must contain references only, never kubeconfig, bearer tokens, passwords, private keys, access keys, or raw secret values.",
                          "decisionRule": "Production/B2B cluster network access review requires result=passed, zero failed checks, current static manifest hashes, and typed operator confirmations."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-helm-values-hardening-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.helm-values-hardening-evidence.v1",
                          "generatedAt": "2026-06-24T02:30:00Z",
                          "result": "failed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operator": "platform-admin",
                          "reviewWindow": { "startedAt": "2026-06-24T02:00:00Z", "completedAt": "2026-06-24T02:30:00Z", "ordered": true },
                          "evidence": {
                            "changeApprovalRef": "CHG-2026-HELM-HARDENING",
                            "helmVerifierEvidenceRef": "helm-template-verifier-20260624",
                            "kubernetesVerifierEvidenceRef": "kubernetes-manifest-verifier-20260624",
                            "containerHardeningEvidenceRef": "container-hardening-review-20260624",
                            "clusterNetworkAccessReviewEvidenceRef": "cluster-network-access-review-20260624",
                            "evidenceRef": "helm-values-hardening-20260624"
                          },
                          "chartSnapshot": { "chartDirectory": "infra/helm/osmu", "files": [ { "relativePath": "values.yaml", "path": "infra/helm/osmu/values.yaml", "exists": true, "byteCount": 100, "sha256": "helm-values-sha" } ] },
                          "staticHardeningSnapshot": {
                            "secretsExternalized": true,
                            "defaultSecretPlaceholdersPresent": false,
                            "haReplicas": 2,
                            "resourceBounds": true,
                            "securityContexts": true,
                            "serviceAccountTokensDisabled": true,
                            "networkPolicyEnabled": true,
                            "tlsIngress": false,
                            "operationsReportsReadOnly": true,
                            "storageExpansionRbacDisabled": true
                          },
                          "confirmations": {
                            "secretsExternalized": true,
                            "defaultSecretPlaceholdersNotUsed": true,
                            "haReplicasReviewed": true,
                            "resourcesBounded": true,
                            "securityContextsReviewed": true,
                            "networkPolicyEnabled": true,
                            "tlsIngressReviewed": false,
                            "operationsReportsReadOnly": true,
                            "storageExpansionRbacDisabledByDefault": true,
                            "noCredentialValues": true
                          },
                          "summary": { "passCount": 18, "failureCount": 1, "totalCount": 19 },
                          "checks": [ { "id": "tls-ingress-confirmed", "name": "TLS ingress review confirmed", "status": "FAIL", "passed": false, "detail": "Operator must confirm TLS/ingress settings are reviewed.", "evidenceRef": "helm-values-hardening-20260624" } ],
                          "scopePolicy": "Reviews static Helm values/templates and operator-approved hardening references; it does not render or apply the chart and does not prove live cluster admission/enforcement.",
                          "secretPolicy": "Evidence stores references and file hashes only. Production secret values, kubeconfig, bearer tokens, private keys, or raw credentials must never be embedded.",
                          "decisionRule": "Production/B2B Helm values hardening requires result=passed, zero failed checks, current chart hashes, and typed operator confirmations."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-support-escalation-handoff-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.support-escalation-handoff-evidence.v1",
                          "generatedAt": "2026-06-24T01:30:00Z",
                          "result": "failed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operator": "support-admin",
                          "reviewWindow": {
                            "startedAt": "2026-06-24T01:00:00Z",
                            "completedAt": "2026-06-24T01:30:00Z",
                            "ordered": true
                          },
                          "evidence": {
                            "changeApprovalRef": "CHG-2026-SUPPORT-HANDOFF",
                            "operationsHandoffPackageRef": "operations-handoff-package-prep-20260624",
                            "runbookReviewRef": "operator-runbook-review-20260624",
                            "troubleshootingReviewRef": "troubleshooting-review-20260624",
                            "rollbackReviewRef": "rollback-review-20260624",
                            "supportEscalationRef": "support-escalation-routing-20260624",
                            "supportSlaRef": "support-sla-approval-20260624",
                            "knownGapsRef": "known-gaps-acceptance-20260624",
                            "evidenceRef": "support-escalation-handoff-20260624"
                          },
                          "documentSnapshot": {
                            "runbookCoverage": true,
                            "troubleshootingCoverage": true,
                            "rollbackCoverage": true,
                            "supportEscalationCoverage": true,
                            "supportSlaCoverage": true,
                            "knownGapsCoverage": true,
                            "handoffPackageCoverage": true
                          },
                          "confirmations": {
                            "runbookReviewed": true,
                            "troubleshootingReviewed": true,
                            "rollbackPathReviewed": true,
                            "supportEscalationReviewed": true,
                            "supportSlaReviewed": false,
                            "knownGapsAccepted": true,
                            "operationsHandoffReferenceReady": true,
                            "noCredentialValues": true
                          },
                          "summary": {
                            "passCount": 30,
                            "failureCount": 1,
                            "totalCount": 31
                          },
                          "checks": [
                            {
                              "id": "support-sla-reviewed-confirmed",
                              "name": "Support SLA review confirmed",
                              "status": "FAIL",
                              "passed": false,
                              "detail": "Operator must confirm support SLA review.",
                              "evidenceRef": "support-sla-approval-20260624"
                            }
                          ],
                          "scopePolicy": "Reviews local handoff documentation and operator-approved references for runbook, troubleshooting, rollback, support escalation, support SLA, and known-gap handoff; it does not contact ticketing systems, support desks, customers, or production clusters.",
                          "secretPolicy": "Evidence stores document hashes, labels, booleans, and non-secret references only. Do not embed passwords, tokens, kubeconfig, private keys, support desk credentials, customer data, or raw incident transcripts.",
                          "decisionRule": "Production/B2B support escalation handoff readiness requires result=passed, zero failed checks, current document hashes, non-secret handoff references, and typed operator confirmations."
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
                          "readinessSummary": "passed=82 pending=20",
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
                          "gaps": ["Operations readiness result is pending: passed=82 pending=20."],
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
                          "sourceSummary": "passed=82 pending=20",
                          "sourceReport": ".osmu-run/latest-operations-readiness.json",
                          "sourcePassedCount": 82,
                          "sourcePendingCount": 20,
                          "sourceTotalCount": 102,
                          "sourceCheckCount": 102,
                          "sourcePendingRemediationCount": 20,
                          "sourcePendingRemediationEntryCount": 20,
                          "sourcePendingRemediationActionCount": 20,
                          "sourcePendingRemediationMissingActionCount": 0,
                          "sourcePendingRemediationCoverageReady": true,
                          "pendingCount": 20,
                          "actionCount": 20,
                          "unplannedCount": 0,
                          "pendingCategorySummary": "chargeback-closeout=1, commercial-approval=1, commercial-integration=1, data-flow=3, enterprise-auth=2, ha-dr=2, monitoring=1, operations-handoff-package=1, security-hardening=6, storage-backend=1, storage-expansion=1",
                          "pendingCategoryCounts": [
                            { "category": "chargeback-closeout", "count": 1 },
                            { "category": "commercial-approval", "count": 1 },
                            { "category": "commercial-integration", "count": 1 },
                            { "category": "data-flow", "count": 3 },
                            { "category": "enterprise-auth", "count": 2 },
                            { "category": "ha-dr", "count": 2 },
                            { "category": "monitoring", "count": 1 },
                            { "category": "operations-handoff-package", "count": 1 },
                            { "category": "security-hardening", "count": 6 },
                            { "category": "storage-backend", "count": 1 },
                            { "category": "storage-expansion", "count": 1 }
                          ],
                          "actionSummary": {
                            "totalActions": 20,
                            "kubernetesLiveActions": 3,
                            "securityCiActions": 6,
                            "operatorRemediationActions": 11,
                            "requiresOperatorApprovalCount": 17,
                            "requiresKubeconfigSecretCount": 3,
                            "actionsWithPlaceholdersCount": 16,
                            "unplannedCheckCount": 0
                          },
                          "actions": [
                            {
                              "order": 1,
                              "name": "Storage expansion finalizer live evidence",
                              "category": "storage-expansion",
                              "actionType": "kubernetes-live",
                              "evidencePath": ".osmu-run/latest-storage-expansion-finalize.json",
                              "requiredEvidence": "finalizer result=passed from target cluster",
                              "currentDetail": "report not found",
                              "localCommand": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\finalize-storage-expansion.ps1 -Namespace osmu -TenantName osmu-minio -ManifestPath .\\\\infra\\\\k8s\\\\examples\\\\minio-tenant-pool-expansion.example.yaml -ImpersonateRunner",
                              "workflow": ".github/workflows/storage-expansion-finalizer-ci.yml",
                              "workflowCommand": "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f manifest_path=./infra/k8s/examples/minio-tenant-pool-expansion.example.yaml -f impersonate_runner=true",
                              "dispatchUrl": "https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml",
                              "recommendedCommand": "gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f manifest_path=./infra/k8s/examples/minio-tenant-pool-expansion.example.yaml -f impersonate_runner=true",
                              "operatorInputs": [],
                              "hasPlaceholders": false,
                              "requiresOperatorApproval": true,
                              "requiresKubeconfigSecret": true,
                              "note": "Run live against the target cluster, or dispatch the workflow with run_live=true and OSMU_KUBECONFIG_BASE64 configured."
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
                            "chargebackCloseout": "latest-chargeback-closeout-evidence-passed",
                            "enterpriseAuth": "latest-enterprise-auth-smoke-scope-out",
                            "clusterNetworkAccessReview": "cluster-network-access-review-passed-20260620",
                            "helmValuesHardening": "helm-values-hardening-passed-20260620",
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
                              "checkCount": 102
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
                              "recommendedCommandCount": 1,
                              "handoffPostDispatchCommandCount": 5,
                              "handoffPostDispatchCommands": [
                                {
                                  "name": "Collect workflow run ids from saved run-list JSON",
                                  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>",
                                  "note": "Use after browser dispatch when GitHub CLI is unavailable locally."
                                },
                                {
                                  "name": "Collect workflow run ids with GitHub REST API",
                                  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1",
                                  "note":  "Use after browser dispatch when GitHub CLI is unavailable and the repository Actions API is readable. Uses GH_TOKEN or GITHUB_TOKEN if present and never writes token values."
                                },
                                {
                                  "name": "Collect workflow run ids with GitHub CLI",
                                  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -Execute",
                                  "note": "Use after browser dispatch when gh is installed and authenticated."
                                },
                                {
                                  "name":  "Regenerate artifact collection plan with browser run ids",
                                  "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68",
                                  "note":  "Use when the workflow run page URL is available but gh/run-list JSON is not. Replace any <RunIdParameter> placeholders with numeric GitHub Actions run ids or full workflow run URLs before running."
                                },
                                {
                                  "name":  "Regenerate artifact collection plan after run id collection",
                                  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha abc123",
                                  "note": "Use after run-id collection so artifact commands stay in scope."
                                }
                              ]
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
                              "candidateDecision": {
                                "candidateStore": "MARIADB_PARTITION",
                                "decision": "Use MariaDB partitioned tables for long-window data-flow analytics.",
                                "evidenceModel": "passed-mariadb-query-plan-evidence",
                                "requiresMariaDbQueryEvidence": true,
                                "requiresTargetStoreEvidence": false,
                                "queryPlanEvidenceRequired": true,
                                "queryPlanEvidencePassed": true,
                                "targetStoreEvidenceConfirmed": true,
                                "safeDataPolicy": "Candidate decisions must use sanitized evidence summaries only; do not store raw SQL, raw EXPLAIN JSON, object keys, raw event messages, or secrets.",
                                "nextAction": "Candidate evidence is ready for transition runbook rehearsal."
                              },
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
                            "dataFlowQueryRetentionBudget": {
                              "provided": true,
                              "path": ".osmu-run/latest-data-flow-query-retention-budget-evidence.json",
                              "parsed": true,
                              "formatVersion": "osmu.data-flow-query-retention-budget-evidence.v1",
                              "expectedFormatVersion": "osmu.data-flow-query-retention-budget-evidence.v1",
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "environmentName": "pilot-prod",
                              "targetCluster": "customer-cluster-a",
                              "operatorName": "ops-admin",
                              "evidenceRef": "latest-data-flow-query-retention-budget-passed",
                              "storagePlanResult": "passed",
                              "candidateStore": "MARIADB_PARTITION",
                              "targetP95QueryLatencyMs": 500,
                              "observedP95QueryLatencyMs": 420,
                              "observedP99QueryLatencyMs": 470,
                              "querySampleCount": 120,
                              "observedQueryWindowDays": 180,
                              "retentionBudgetSeconds": 30,
                              "detailedRetentionObservedSeconds": 20,
                              "dailyRollupRetentionObservedSeconds": 18,
                              "monthlyRollupRetentionObservedSeconds": 12,
                              "detailedRetentionDeletedRows": 1000,
                              "dailyRollupRetentionDeletedRows": 300,
                              "monthlyRollupRetentionDeletedRows": 20,
                              "queryLatencyWithinBudget": true,
                              "retentionJobsWithinBudget": true,
                              "failureCount": 0,
                              "checkCount": 23,
                              "confirmations": {
                                "queryLatencyReviewed": true,
                                "retentionJobsWithinBudget": true,
                                "noObjectKeysInEvidence": true,
                                "noRawSqlOrExplain": true,
                                "noSecretValues": true
                              },
                              "topFailedChecks": []
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
                            "chargebackCloseout": {
                              "provided": true,
                              "parsed": true,
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "environmentName": "pilot-prod",
                              "targetCluster": "customer-cluster-a",
                              "operatorName": "billing-ops",
                              "billingPeriod": "2026-06",
                              "closeoutWindow": {
                                "startedAt": "2026-06-30T01:00:00Z",
                                "completedAt": "2026-06-30T01:45:00Z"
                              },
                              "summaryValid": true,
                              "confirmationsValid": true,
                              "closeoutCountsValid": true,
                              "rawDataFlagsValid": true,
                              "noRawDataStored": true,
                              "reconciliationDifferenceMinorUnits": 0,
                              "checkCount": 24,
                              "passCount": 24,
                              "failureCount": 0,
                              "plannedCount": 0,
                              "chargebackCloseoutSnapshot": {
                                "provided": true,
                                "parsed": true,
                                "valid": true,
                                "billingPeriod": "2026-06",
                                "result": "RECONCILED",
                                "statusClosed": true,
                                "billingPeriodMatches": true,
                                "integersValid": true,
                                "booleansValid": true,
                                "failureCountZero": true,
                                "blockerCountZero": true,
                                "scanLimitPositive": true,
                                "sourceTruncated": false,
                                "sourceComplete": true,
                                "truncationBlockerCountZero": true,
                                "closeoutReady": true,
                                "readinessBooleansClosed": true,
                                "noRawDataStored": true,
                                "counts": {
                                  "invoiceDraftCount": 3,
                                  "finalInvoiceCount": 3,
                                  "paymentRequestedCount": 3,
                                  "paymentHandoffCount": 3,
                                  "paidInvoiceCount": 3,
                                  "scanLimit": 500,
                                  "truncationBlockerCount": 0,
                                  "blockerCount": 0,
                                  "reconciliationDifferenceMinorUnits": 0,
                                  "failureCount": 0
                                },
                                "rawDataFlags": {
                                  "rawCustomerPaymentDataStored": false,
                                  "rawProviderResponseStored": false,
                                  "rawSecretValuesStored": false
                                }
                              },
                              "paymentProviderAdapterReadiness": {
                                "status": "WEBHOOK_PROFILE_READY",
                                "profileCount": 5,
                                "webhookReadyProfileCount": 5,
                                "nativeApiReadyProfileCount": 0
                              },
                              "confirmations": {
                                "noRawCustomerPaymentData": true,
                                "noRawProviderResponses": true,
                                "noSecretValues": true
                              },
                              "evidenceRefs": {
                                "chargebackPreview": "chargeback-preview-export-202606",
                                "commercialApproval": "latest-commercial-approval-evidence-passed"
                              },
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
                            "enterpriseAuthJitRollback": {
                              "provided": true,
                              "path": ".osmu-run/latest-enterprise-auth-jit-rollback-evidence.json",
                              "parsed": true,
                              "formatVersion": "osmu.enterprise-auth-jit-rollback-evidence.v1",
                              "expectedFormatVersion": "osmu.enterprise-auth-jit-rollback-evidence.v1",
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "environmentName": "pilot-prod",
                              "targetCluster": "customer-cluster-a",
                              "operatorName": "auth-ops",
                              "evidenceRef": "enterprise-auth-jit-rollback-review-20260620",
                              "reviewWindow": {
                                "startedAt": "2026-06-20T03:20:00Z",
                                "completedAt": "2026-06-20T03:35:00Z"
                              },
                              "enterpriseAuthSmokeSnapshot": {
                                "provided": true,
                                "parsed": true,
                                "formatVersion": "osmu.enterprise-auth-smoke.v1",
                                "result": "passed",
                                "executionMode": "target-smoke",
                                "passCount": 8,
                                "failCount": 0,
                                "blockedCount": 0,
                                "plannedCount": 0,
                                "scopeOutAccepted": false,
                                "detail": "formatVersion=osmu.enterprise-auth-smoke.v1; result=passed"
                              },
                              "evidenceRefs": {
                                "changeApproval": "CHG-2026-ENTERPRISE-AUTH-JIT",
                                "jitProvision": "jit-provision-admin-approval-20260620",
                                "jitRollbackRunbook": "jit-rollback-runbook-review-20260620",
                                "userDisableRollback": "jit-user-disable-rollback-20260620",
                                "roleMappingRollback": "jit-role-org-team-rollback-20260620",
                                "localLoginFallback": "local-login-fallback-20260620",
                                "auditReview": "jit-audit-review-20260620"
                              },
                              "confirmations": {
                                "adminApprovalRequired": true,
                                "callbackAutoJitDisabled": true,
                                "jitUserDisableOrLockRollbackReviewed": true,
                                "roleOrgTeamRollbackReviewed": true,
                                "localPasswordFallbackValidated": true,
                                "auditEventsReviewed": true,
                                "noRawClaims": true,
                                "noSecretValues": true
                              },
                              "confirmationsValid": true,
                              "failureCount": 0,
                              "checkCount": 10,
                              "topChecks": [],
                              "decisionRule": "Production/B2B enterprise auth JIT readiness requires result=passed.",
                              "scopePolicy": "Enterprise auth JIT rollback evidence only.",
                              "secretPolicy": "Evidence stores references and reduced smoke summary only."
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
                            },
                            "clusterNetworkAccessReview": {
                              "provided": true,
                              "parsed": true,
                              "formatVersion": "osmu.cluster-network-access-review-evidence.v1",
                              "expectedFormatVersion": "osmu.cluster-network-access-review-evidence.v1",
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "environmentName": "pilot-prod",
                              "targetCluster": "customer-cluster-a",
                              "operatorName": "network-ops",
                              "evidenceRef": "cluster-network-access-review-passed-20260620",
                              "passCount": 18,
                              "failureCount": 0,
                              "totalCount": 18,
                              "staticControls": {
                                "requiredPolicyNamesPresent": true,
                                "backendEgressScoped": true,
                                "backupEgressScoped": true,
                                "dnsEgressScoped": true,
                                "mariaDbIngressScoped": true,
                                "minioIngressScoped": true,
                                "noBroadCidr": true,
                                "helmNetworkPolicyEnabled": true
                              },
                              "confirmations": {
                                "backendOnlyMariaDb": true,
                                "backendOnlyMinio": true,
                                "backupOnlyMariaDbMinio": true,
                                "dnsEgressScoped": true,
                                "mariaDbIngressBackendBackupOnly": true,
                                "minioIngressBackendBackupOnly": true,
                                "publicIngressLimited": true,
                                "namespaceDefaultDenyReviewed": true,
                                "observabilityScrapeReviewed": true,
                                "helmNetworkPolicyEnabled": true,
                                "noCredentialValues": true
                              },
                              "topChecks": []
                            },
                            "helmValuesHardening": {
                              "provided": true,
                              "parsed": true,
                              "formatVersion": "osmu.helm-values-hardening-evidence.v1",
                              "expectedFormatVersion": "osmu.helm-values-hardening-evidence.v1",
                              "validFormatVersion": true,
                              "result": "passed",
                              "passed": true,
                              "environmentName": "pilot-prod",
                              "targetCluster": "customer-cluster-a",
                              "operatorName": "helm-ops",
                              "evidenceRef": "helm-values-hardening-passed-20260620",
                              "passCount": 31,
                              "failureCount": 0,
                              "totalCount": 31,
                              "staticHardening": {
                                "secretsExternalized": true,
                                "defaultSecretPlaceholdersPresent": true,
                                "haReplicas": true,
                                "resourceBounds": true,
                                "securityContexts": true,
                                "serviceAccountTokensDisabled": true,
                                "networkPolicyEnabled": true,
                                "tlsIngress": true,
                                "operationsReportsReadOnly": true,
                                "storageExpansionRbacDisabled": true
                              },
                              "confirmations": {
                                "secretsExternalized": true,
                                "defaultSecretPlaceholdersNotUsed": true,
                                "haReplicasReviewed": true,
                                "resourcesBounded": true,
                                "securityContextsReviewed": true,
                                "networkPolicyEnabled": true,
                                "tlsIngressReviewed": true,
                                "operationsReportsReadOnly": true,
                                "storageExpansionRbacDisabledByDefault": true,
                                "noCredentialValues": true
                              },
                              "topChecks": []
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
                            "chargebackCloseoutSnapshotReviewed": true,
                            "enterpriseAuthSmokeSnapshotReviewed": true,
                            "enterpriseAuthJitRollbackSnapshotReviewed": true,
                            "monitoringThresholdReviewed": true,
                            "clusterNetworkAccessReviewReviewed": true,
                            "helmValuesHardeningReviewed": true,
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
                          "scopePolicy": "This evidence covers configured webhook/Slack/EMAIL SMTP relay and payment webhook profile handoff verification with sanitized native bridge readiness while excluding vendor-specific fixed SDK/schema processor claims.",
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
                Path.of(".osmu-run/latest-enterprise-auth-jit-rollback-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.enterprise-auth-jit-rollback-evidence.v1",
                          "generatedAt": "2026-06-20T04:30:00Z",
                          "result": "failed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operatorName": "security-admin",
                          "evidenceRef": "enterprise-auth-jit-rollback-review-20260620",
                          "reviewWindow": {
                            "startedAt": "2026-06-20T04:00:00Z",
                            "completedAt": "2026-06-20T04:30:00Z"
                          },
                          "enterpriseAuthSmokeSnapshot": {
                            "provided": true,
                            "parsed": true,
                            "formatVersion": "osmu.enterprise-auth-smoke.v1",
                            "result": "passed",
                            "executionMode": "execute",
                            "passCount": 8,
                            "failCount": 0,
                            "blockedCount": 0,
                            "plannedCount": 0,
                            "scopeOutAccepted": false,
                            "detail": "result=passed executionMode=execute pass=8 fail=0 blocked=0 planned=0 scopeOutAccepted=False"
                          },
                          "evidenceRefs": {
                            "changeApproval": "CHG-2026-ENTERPRISE-AUTH-JIT",
                            "jitProvision": "jit-provision-target-20260620",
                            "jitRollbackRunbook": "jit-rollback-runbook-20260620",
                            "userDisableRollback": "jit-user-disable-rollback-20260620",
                            "roleMappingRollback": "jit-role-org-team-rollback-20260620",
                            "localLoginFallback": "local-login-fallback-20260620",
                            "auditReview": "oidc-jit-audit-review-20260620"
                          },
                          "confirmations": {
                            "adminApprovalRequired": true,
                            "callbackAutoJitDisabled": true,
                            "jitUserDisableOrLockRollbackReviewed": true,
                            "roleOrgTeamRollbackReviewed": true,
                            "localPasswordFallbackValidated": false,
                            "auditEventsReviewed": true,
                            "noRawClaims": true,
                            "noSecretValues": true
                          },
                          "summary": {
                            "failureCount": 1,
                            "checkCount": 9
                          },
                          "checks": [
                            {
                              "id": "local-password-fallback-confirmed",
                              "name": "Local password fallback validated",
                              "status": "FAIL",
                              "passed": false,
                              "detail": "ConfirmLocalPasswordFallbackValidated=False",
                              "evidenceRef": "local-login-fallback-20260620"
                            },
                            {
                              "id": "enterprise-auth-smoke-snapshot-accepted",
                              "name": "Enterprise auth smoke or scope-out evidence snapshot accepted",
                              "status": "PASS",
                              "passed": true,
                              "detail": "result=passed executionMode=execute pass=8 fail=0 blocked=0 planned=0 scopeOutAccepted=False",
                              "evidenceRef": ""
                            }
                          ],
                          "decisionRule": "Production/B2B enterprise auth JIT readiness requires result=passed after admin-approved JIT provisioning evidence, rollback runbook review, user disable/lock rollback evidence, role/org/team mapping rollback review, local password fallback validation, audit review, and no-raw-claim/no-secret confirmations.",
                          "scopePolicy": "Enterprise auth JIT rollback/runbook evidence only. It does not execute IdP, LDAP, user, role, organization, or team changes; it records operator-reviewed target evidence references and reduced smoke summary only.",
                          "secretPolicy": "Evidence stores only environment labels, operator/change references, timestamps, booleans, reduced enterprise auth smoke summary, and external evidence references; it does not contain passwords, bearer tokens, OIDC codes/states, access/refresh/id tokens, LDAP/admin passwords, client secrets, raw OIDC claims, raw identity provider responses, or raw directory data."
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
                          "candidateDecision": {
                            "candidateStore": "MARIADB_PARTITION",
                            "decision": "Use MariaDB partitioned tables for long-window data-flow analytics.",
                            "evidenceModel": "passed-mariadb-query-plan-evidence",
                            "requiresMariaDbQueryEvidence": true,
                            "requiresTargetStoreEvidence": false,
                            "queryPlanEvidenceRequired": true,
                            "queryPlanEvidencePassed": false,
                            "targetStoreEvidenceConfirmed": true,
                            "safeDataPolicy": "Candidate decisions must use sanitized evidence summaries only; do not store raw SQL, raw EXPLAIN JSON, object keys, raw event messages, or secrets.",
                            "nextAction": "Attach passed MariaDB query-plan evidence before promoting the storage transition plan."
                          },
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
                Path.of(".osmu-run/latest-data-flow-query-retention-budget-evidence.json"),
                """
                        {
                          "formatVersion": "osmu.data-flow-query-retention-budget-evidence.v1",
                          "generatedAt": "2026-06-21T09:22:00Z",
                          "result": "failed",
                          "environmentName": "pilot-prod",
                          "targetCluster": "customer-cluster-a",
                          "operatorName": "ops-admin",
                          "evidenceRef": "data-flow-query-retention-budget-run-20260621",
                          "dataFlowStoragePlanSnapshot": {
                            "formatVersion": "osmu.data-flow-storage-plan.v1",
                            "result": "passed",
                            "candidateStore": "MARIADB_PARTITION",
                            "targetP95QueryLatencyMs": 500,
                            "pendingCount": 0,
                            "checkCount": 10
                          },
                          "queryLatencyBudget": {
                            "evidenceRef": "query-latency-benchmark-20260621",
                            "targetP95QueryLatencyMs": 500,
                            "observedP95QueryLatencyMs": 420,
                            "observedP99QueryLatencyMs": 470,
                            "querySampleCount": 120,
                            "observedQueryWindowDays": 180,
                            "withinBudget": true
                          },
                          "retentionBudget": {
                            "evidenceRef": "retention-dry-run-20260621",
                            "budgetSeconds": 30,
                            "detailedRetentionObservedSeconds": 31,
                            "dailyRollupRetentionObservedSeconds": 18,
                            "monthlyRollupRetentionObservedSeconds": 12,
                            "detailedRetentionDeletedRows": 1000,
                            "dailyRollupRetentionDeletedRows": 300,
                            "monthlyRollupRetentionDeletedRows": 20,
                            "withinBudget": false
                          },
                          "confirmations": {
                            "queryLatencyReviewed": true,
                            "retentionJobsWithinBudget": true,
                            "noObjectKeysInEvidence": true,
                            "noRawSqlOrExplain": true,
                            "noSecretValues": true
                          },
                          "summary": {
                            "failureCount": 1,
                            "checkCount": 23
                          },
                          "checks": [
                            {
                              "id": "retention-jobs-within-budget",
                              "name": "Retention jobs are within budget",
                              "status": "FAIL",
                              "passed": false,
                              "detail": "budgetSeconds=30; detailed=31; daily=18; monthly=12"
                            }
                          ],
                          "scopePolicy": "OSMU operations analytics and internal chargeback scale evidence only. This is not AWS billing parity."
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
                            "formatVersion":  "osmu.operations-evidence-plan-invocation.v1",
                            "generatedAt":  "2026-06-30T12:48:08.3771639+09:00",
                            "result":  "planned",
                            "sourcePlan":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-evidence-plan.json",
                            "sourceResult":  "action-required",
                            "sourceSummary":  "passed=82 pending=20",
                            "sourcePassedCount":  82,
                            "sourcePendingCount":  20,
                            "sourceTotalCount":  102,
                            "sourceCheckCount":  102,
                            "commandMode":  "Workflow",
                            "executionMode":  "plan-only",
                            "githubCliPath":  "",
                            "githubCliExecutionSource":  "",
                            "selectedActionCount":  1,
                            "selectedActionOrders":  [
                                                         6
                                                     ],
                            "plannedCount":  1,
                            "blockedCount":  0,
                            "executedCount":  0,
                            "failedCount":  0,
                            "decisionRule":  "Only execute actions after placeholders are resolved, operator approval is confirmed when required, kubeconfig secret readiness is confirmed when required, and the command passes the allowlist check. Regenerate operations readiness after execution.",
                            "actions":  [
                                            {
                                                "order":  6,
                                                "name":  "Container scan/SBOM evidence",
                                                "category":  "security-hardening",
                                                "actionType":  "security-ci",
                                                "evidencePath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-container-security-evidence.json",
                                                "commandMode":  "Workflow",
                                                "command":  "gh workflow run container-security-ci.yml",
                                                "status":  "planned",
                                                "blockReasons":  [

                                                                 ],
                                                "unresolvedPlaceholders":  [

                                                                           ],
                                                "invalidPlaceholders":  [

                                                                        ],
                                                "requiresOperatorApproval":  false,
                                                "requiresKubeconfigSecret":  false,
                                                "exitCode":  null,
                                                "output":  [

                                                           ]
                                            }
                                        ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-invocation-unblock-plan.json"),
                """
                        {
                            "formatVersion":  "osmu.operations-invocation-unblock-plan.v1",
                            "generatedAt":  "2026-06-30T12:48:08.7487667+09:00",
                            "result":  "ready",
                            "sourceInvocationReport":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-evidence-plan-invocation.json",
                            "sourceResult":  "planned",
                            "sourceSummary":  "passed=82 pending=20",
                            "sourcePassedCount":  82,
                            "sourcePendingCount":  20,
                            "sourceTotalCount":  102,
                            "sourceCheckCount":  102,
                            "selectedActionCount":  1,
                            "plannedCount":  1,
                            "blockedCount":  0,
                            "failedCount":  0,
                            "needsKubeconfigSecretConfirmation":  false,
                            "needsOperatorApprovalConfirmation":  false,
                            "requiredPlaceholderCount":  0,
                            "ambiguousRepeatedPlaceholderCount":  0,
                            "confirmationGroupCount":  0,
                            "requiredInputGroupCount":  0,
                            "blockedActionOrders":  [

                                                    ],
                            "plannedActionOrders":  [
                                                        6
                                                    ],
                            "confirmedPlanCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                            "blockedOnlyPlanCommand":  "",
                            "plannedOnlyCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                            "decisionRule":  "Resolve placeholders, confirm operator approval when required, confirm OSMU_KUBECONFIG_BASE64 readiness when required, then rerun invoke-operations-evidence-plan.ps1 in plan-only mode before using -Execute.",
                            "confirmationGroups":  [

                                                   ],
                            "requiredInputGroups":  [

                                                    ],
                            "actions":  [
                                            {
                                                "order":  6,
                                                "name":  "Container scan/SBOM evidence",
                                                "category":  "security-hardening",
                                                "actionType":  "security-ci",
                                                "evidencePath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-container-security-evidence.json",
                                                "status":  "planned",
                                                "commandMode":  "Workflow",
                                                "command":  "gh workflow run container-security-ci.yml",
                                                "blockReasons":  [

                                                                 ],
                                                "unresolvedPlaceholders":  [

                                                                           ],
                                                "invalidPlaceholders":  [

                                                                        ],
                                                "requiresOperatorApproval":  false,
                                                "requiresKubeconfigSecret":  false,
                                                "needsOperatorApprovalConfirmation":  false,
                                                "needsKubeconfigSecretConfirmation":  false,
                                                "requiredInputs":  [

                                                                   ],
                                                "ambiguousRepeatedPlaceholders":  false,
                                                "planCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6"
                                            }
                                        ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-dispatch-preflight.json"),
                """
                        {
                            "formatVersion":  "osmu.operations-dispatch-preflight.v1",
                            "generatedAt":  "2026-06-30T12:48:09.2261223+09:00",
                            "result":  "action-required",
                            "sourceUnblockPlan":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-invocation-unblock-plan.json",
                            "sourceResult":  "ready",
                            "sourcePassedCount":  82,
                            "sourcePendingCount":  20,
                            "sourceTotalCount":  102,
                            "sourceCheckCount":  102,
                            "selectedActionCount":  1,
                            "selectedActionOrders":  [
                                                         6
                                                     ],
                            "readyActionCount":  1,
                            "readyActionOrders":  [
                                                      6
                                                  ],
                            "blockedActionCount":  0,
                            "blockedActionOrders":  [

                                                    ],
                            "needsKubeconfigSecretConfirmation":  false,
                            "needsOperatorApprovalConfirmation":  false,
                            "requiredInputCount":  0,
                            "missingInputCount":  0,
                            "ambiguousInputCount":  0,
                            "unsafeInputCount":  0,
                            "invalidInputCount":  0,
                            "requiredGitHubSecrets":  [

                                                      ],
                            "githubCliPath":  "",
                            "githubCliAvailableForDispatch":  false,
                            "githubRepository":  "chefbeom/object-storage-osmu",
                            "githubRef":  "main",
                            "defaultBranchRef":  "origin/main",
                            "githubApiTokenPresent":  false,
                            "githubApiDispatchAvailable":  false,
                            "githubApiDispatchUnavailableReasons":  [
                                                                     "GH_TOKEN or GITHUB_TOKEN is not set"
                                                                 ],
                            "workflowFiles":  [
                                                  {
                                                      "actionOrder":  6,
                                                      "workflow":  "container-security-ci.yml",
                                                      "path":  "C:\\\\project\\\\object-storage-osmu\\\\.github\\\\workflows\\\\container-security-ci.yml",
                                                      "exists":  true,
                                                      "defaultBranchRef":  "origin/main",
                                                      "existsOnDefaultBranch":  true,
                                                      "dispatchUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                      "requiredSecrets":  [

                                                                          ]
                                                  }
                                              ],
                            "checks":  [
                                           {
                                               "code":  "ACTION_SELECTION",
                                               "status":  "pass",
                                               "message":  "1 action(s) selected for dispatch preflight."
                                           },
                                           {
                                               "code":  "KUBECONFIG_SECRET_CONFIRMED",
                                               "status":  "pass",
                                               "message":  "Selected actions do not require kubeconfig secret confirmation."
                                           },
                                           {
                                               "code":  "OPERATOR_APPROVAL_CONFIRMED",
                                               "status":  "pass",
                                               "message":  "Selected actions do not require operator approval confirmation."
                                           },
                                           {
                                               "code":  "REQUIRED_INPUTS_SUPPLIED",
                                               "status":  "pass",
                                               "message":  "All required placeholder values were supplied."
                                           },
                                           {
                                               "code":  "SAFE_INPUT_VALUES",
                                               "status":  "pass",
                                               "message":  "All supplied placeholder values pass the invocation command guard."
                                           },
                                           {
                                               "code":  "KNOWN_INPUT_VALUE_SHAPES",
                                               "status":  "pass",
                                               "message":  "Known placeholder values match expected shapes."
                                           },
                                           {
                                               "code":  "WORKFLOW_FILES_PRESENT",
                                               "status":  "pass",
                                               "message":  "All selected workflow files exist locally."
                                           },
                                           {
                                               "code":  "GITHUB_CLI_AVAILABLE",
                                               "status":  "fail",
                                               "message":  "GitHub CLI was not found on PATH."
                                           },
                                           {
                                               "code":  "AMBIGUOUS_PLACEHOLDERS",
                                               "status":  "pass",
                                               "message":  "No repeated generic placeholder inputs detected."
                                           },
                                           {
                                               "code":  "GITHUB_REF_SYNC",
                                               "status":  "fail",
                                               "message":  "Working tree has uncommitted changes; GitHub Actions will only run committed content from GitHubRef 'main', not local dirty files. Current branch 'main' is also 25 commit(s) ahead of 'origin/main'. Commit or intentionally exclude the changes, rerun preflight, then push a branch and dispatch that ref. Suggested ref after commit: codex/operations-readiness-a0730b64."
                                           }
                                       ],
                            "failedCheckCount":  2,
                            "warningCheckCount":  0,
                            "readyPlanCommand":  "",
                            "executeCommand":  "",
                            "apiExecuteCommand":  "",
                            "readySubsetPlanCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                            "readySubsetExecuteCommand":  "",
                            "readySubsetApiExecuteCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute",
                            "gitRefSafety":  {
                                                  "checked":  true,
                                                  "status":  "action-required",
                                                  "githubRef":  "main",
                                                  "currentBranch":  "main",
                                                  "commitSha":  "a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                  "shortCommitSha":  "a0730b64",
                                                  "upstreamRef":  "origin/main",
                                                  "upstreamCommitSha":  "572eb099aacdc3ed03929bf24c34e251e37885bd",
                                                  "aheadCount":  25,
                                                  "behindCount":  0,
                                                  "workingTreeDirty":  true,
                                                  "githubRefMatchesCurrentBranch":  true,
                                                  "githubRefLikelyContainsCommit":  false,
                                                  "suggestedGitHubRef":  "codex/operations-readiness-a0730b64",
                                                  "note":  "Working tree has uncommitted changes; GitHub Actions will only run committed content from GitHubRef 'main', not local dirty files. Current branch 'main' is also 25 commit(s) ahead of 'origin/main'. Commit or intentionally exclude the changes, rerun preflight, then push a branch and dispatch that ref. Suggested ref after commit: codex/operations-readiness-a0730b64."
                                              },
                            "requiredInputs":  [

                                               ],
                            "inputTemplates":  [
                                                   {
                                                       "actionOrder":  6,
                                                       "name":  "Container scan/SBOM evidence",
                                                       "category":  "security-hardening",
                                                       "actionType":  "security-ci",
                                                       "commandMode":  "Workflow",
                                                       "workflow":  "container-security-ci.yml",
                                                       "dispatchUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                       "needsOperatorApprovalConfirmation":  false,
                                                       "needsKubeconfigSecretConfirmation":  false,
                                                       "requiredSecrets":  [

                                                                           ],
                                                       "workflowInputNames":  [

                                                                              ],
                                                       "readyToDispatch":  true,
                                                       "missingInputCount":  0,
                                                       "unsafeInputCount":  0,
                                                       "invalidInputCount":  0,
                                                       "ambiguousInputCount":  0,
                                                       "missingInputParameters":  [

                                                                                  ],
                                                       "unsafeInputParameters":  [

                                                                                 ],
                                                       "invalidInputParameters":  [

                                                                                  ],
                                                       "inputs":  [

                                                                  ],
                                                       "operatorChecklist":  [

                                                                             ]
                                                   }
                                               ],
                            "decisionRule":  "Run the ready plan command first without -Execute. Use the execute command only after this preflight is ready and operator-approved live dispatch is intended; use GitHub CLI auth or -UseGitHubApi with GH_TOKEN/GITHUB_TOKEN. When readyActionCount is lower than selectedActionCount, the ready subset commands may be used to plan or execute only actions whose input templates are readyToDispatch=true."
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-workflow-run-ids.json"),
                """
                        {
                            "formatVersion":  "osmu.operations-workflow-run-id-plan.v1",
                            "generatedAt":  "2026-06-30T12:48:09.7557889+09:00",
                            "result":  "query-required",
                            "sourceInvocationReport":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-evidence-plan-invocation.json",
                            "invocationResult":  "planned",
                            "sourceSummary":  "passed=82 pending=20",
                            "sourcePassedCount":  82,
                            "sourcePendingCount":  20,
                            "sourceTotalCount":  102,
                            "sourceCheckCount":  102,
                            "sourceActionCount":  1,
                            "sourceActionOrders":  [
                                                       6
                                                   ],
                            "selectedActionOrders":  [
                                                         6
                                                     ],
                            "branch":  "main",
                            "githubRepository":  "chefbeom/object-storage-osmu",
                            "queryMode":  "plan-only",
                            "githubApiTokenPresent":  false,
                            "githubApiUnauthenticated":  false,
                            "queryExecuted":  false,
                            "queryExecutedCount":  0,
                            "queryWorkflowCount":  1,
                            "querySucceededCount":  1,
                            "queryErrorCount":  0,
                            "candidateCount":  0,
                            "runListJsonDirectory":  ".\\\\.osmu-run\\\\workflow-run-lists",
                            "runListJsonDirectoryCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory .\\\\.osmu-run\\\\workflow-run-lists",
                            "githubApiRunListCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1",
                            "githubApiBaseUrl":  "https://api.github.com",
                            "runListJsonFilePattern":  "<workflow>.json",
                            "runListJsonHandoffNote":  "Save each workflow run-list JSON as .\\\\.osmu-run\\\\workflow-run-lists\\\\<workflow>.json. Each file may contain an array of runs or an object with a runs array.",
                            "browserWorkflowRunsUrls":  [
                                                             "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                             "https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml"
                                                         ],
                            "workflowRunIdInputs":  [
                                                         {
                                                             "workflow":  "container-security-ci.yml",
                                                             "group":  "container-security-source",
                                                             "actionOrders":  [
                                                                                  6
                                                                              ],
                                                             "runIdParameter":  "ContainerSecurityRunId",
                                                             "recommendedRunId":  "",
                                                             "artifactName":  "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                             "requiredForReadiness":  false,
                                                             "readyForArtifactDownload":  false,
                                                             "runsUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                            "runListJsonPath":  ".\\\\.osmu-run\\\\workflow-run-lists\\\\container-security-ci.yml.json",
                                                             "queryCommand":  "gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle",
                                                             "gitHubApiQueryUrl":  "https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20",
                                                             "sourceSelected":  true,
                                                             "supplementalForSecurityFinalizer":  false
                                                         }
                                                     ],
                            "recommendedCommands":  [
                                                          {
                                                              "order":  1,
                                                              "name":  "Collect run ids from saved run-list JSON",
                                                              "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory .\\\\.osmu-run\\\\workflow-run-lists",
                                                              "reason":  "Use after browser dispatch when GitHub CLI is unavailable locally.",
                                                              "note":  "Save each workflow run-list JSON as .\\\\.osmu-run\\\\workflow-run-lists\\\\<workflow>.json. Each file may contain an array of runs or an object with a runs array.",
                                                              "dispatchUrls":  [
                                                                                   "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                                                   "https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml"
                                                                               ]
                                                          },
                                                           {
                                                               "order":  2,
                                                               "name":  "Collect workflow run ids with GitHub REST API",
                                                               "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1",
                                                               "reason":  "Use after browser dispatch when GitHub CLI is unavailable and the repository Actions API is readable.",
                                                               "note":  "Queries workflow_dispatch runs through the GitHub REST API, using GH_TOKEN or GITHUB_TOKEN if present, and never writes token values to the report.",
                                                               "dispatchUrls":  [
                                                                                   "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                                                   "https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml"
                                                                               ]
                                                           },
                                                          {
                                                               "order":  3,
                                                              "name":  "Collect workflow run ids with GitHub CLI",
                                                              "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -Execute",
                                                              "reason":  "Use after workflow dispatch when gh is installed and authenticated.",
                                                              "note":  "Regenerates this plan by querying workflow_dispatch runs directly.",
                                                              "dispatchUrls":  []
                                                          },
                                                          {
                                                               "order":  4,
                                                              "name":  "Write artifact collection plan with browser run ids",
                                                              "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningRunId <ImageSigningRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                              "reason":  "Use when a browser workflow run page shows the run id but gh/run-list JSON is unavailable.",
                                                              "note":  "Replace each <RunIdParameter> placeholder with either the numeric GitHub Actions run id or the full workflow run URL; artifact collection normalizes /actions/runs/<id> before regenerating the same selected-action scope. Security finalizer dependency: this dispatch can supply ContainerSecurityRunId; also collect ImageSigningRunId before running security-evidence-finalizer-ci.yml.",
                                                              "dispatchUrls":  [
                                                                                   "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                                                   "https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml"
                                                                               ]
                                                          },
                                                          {
                                                               "order":  5,
                                                              "name":  "Write artifact collection plan",
                                                              "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                              "reason":  "Use after recommended run ids are available.",
                                                              "note":  "Feeds run ids into the artifact collection/import chain.",
                                                              "dispatchUrls":  []
                                                          }
,
                                                          {
                                                               "order":  6,
                                                              "name":  "Run security evidence finalizer",
                                                              "command":  "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=\u003cimage-signing-run-id\u003e -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=\u003ccontainer-security-run-id\u003e -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true",
                                                              "reason":  "Use after image signing and container security run ids are collected.",
                                                              "note":  "Promotes signed-image and container scan/SBOM evidence into the security finalizer artifact. Missing run id inputs: ImageSigningRunId, ContainerSecurityRunId.",
                                                              "dispatchUrls":  []
                                                          }
                                                      ],
                            "limit":  20,
                            "workflowCount":  1,
                            "readyWorkflowCount":  0,
                            "missingWorkflowCount":  1,
                            "staleWorkflowCount":  0,
                            "imageSigningVersion":  "v0.1.0-rc.1",
                            "commitSha":  "a0730b64636a22c38639b5f5c647f2e13792fc68",
                            "artifactCollectionPlanCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68",
                            "manualArtifactCollectionPlanCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningRunId <ImageSigningRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68",
                            "securityEvidenceFinalizerReady":  false,
                            "securityEvidenceFinalizerRunIdInputs":  [
                                                                         "ImageSigningRunId",
                                                                         "ContainerSecurityRunId"
                                                                     ],
                            "securityEvidenceFinalizerRunIdInputHints":  [
                                                                               {
                                                                                   "workflow":  "image-publish-sign-ci.yml",
                                                                                   "group":  "image-signing-source",
                                                                                   "actionOrders":  [],
                                                                                   "runIdParameter":  "ImageSigningRunId",
                                                                                   "recommendedRunId":  "",
                                                                                   "artifactName":  "osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                                   "requiredForReadiness":  false,
                                                                                   "readyForArtifactDownload":  false,
                                                                                   "runsUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml",
                                                                                   "runListJsonPath":  ".\\\\.osmu-run\\\\workflow-run-lists\\\\image-publish-sign-ci.yml.json",
                                                                                   "queryCommand":  "gh run list --workflow image-publish-sign-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle",
                                                                                   "gitHubApiQueryUrl":  "https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20",
                                                                                   "sourceSelected":  false,
                                                                                   "supplementalForSecurityFinalizer":  true
                                                                               },
                                                                               {
                                                                                   "workflow":  "container-security-ci.yml",
                                                                                   "group":  "container-security-source",
                                                                                   "actionOrders":  [
                                                                                                        6
                                                                                                    ],
                                                                                   "runIdParameter":  "ContainerSecurityRunId",
                                                                                   "recommendedRunId":  "",
                                                                                   "artifactName":  "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                                   "requiredForReadiness":  false,
                                                                                   "readyForArtifactDownload":  false,
                                                                                   "runsUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                                                   "runListJsonPath":  ".\\\\.osmu-run\\\\workflow-run-lists\\\\container-security-ci.yml.json",
                                                                                   "queryCommand":  "gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle",
                                                                                   "gitHubApiQueryUrl":  "https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20",
                                                                                   "sourceSelected":  true,
                                                                                   "supplementalForSecurityFinalizer":  false
                                                                               }
                                                                           ],
                            "securityEvidenceFinalizerMissingRunIdInputs":  [
                                                                                  "ImageSigningRunId",
                                                                                  "ContainerSecurityRunId"
                                                                              ],
                            "securityEvidenceFinalizerDependencyNote":  "Security finalizer dependency: this dispatch can supply ContainerSecurityRunId; also collect ImageSigningRunId before running security-evidence-finalizer-ci.yml.",
                            "securityEvidenceFinalizerCommand":  "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=\\u003cimage-signing-run-id\\u003e -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=\\u003ccontainer-security-run-id\\u003e -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true",
                            "decisionRule":  "Use the query commands or workflow runs URLs to identify latest successful workflow_dispatch runs, run the security evidence finalizer after image signing and container security artifacts are ready, then regenerate the artifact collection plan with the recommended run ids.",
                            "workflows":  [
                                              {
                                                  "workflow":  "container-security-ci.yml",
                                                  "sourceActionCount":  1,
                                                  "primaryActionOrder":  6,
                                                  "primaryActionName":  "Container scan/SBOM evidence",
                                                  "primaryActionStatus":  "planned",
                                                  "actionOrders":  [
                                                                       6
                                                                   ],
                                                  "actionNames":  [
                                                                      "Container scan/SBOM evidence"
                                                                  ],
                                                  "actionStatuses":  [
                                                                         "planned"
                                                                     ],
                                                  "actionCategories":  [
                                                                           "security-hardening"
                                                                       ],
                                                  "actionTypes":  [
                                                                      "security-ci"
                                                                  ],
                                                  "group":  "container-security-source",
                                                  "queryCommand":  "gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle",
                                                  "gitHubApiQueryUrl":  "https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20",
                                                  "runListJsonFile":  "container-security-ci.yml.json",
                                                  "runListJsonPath":  ".\\\\.osmu-run\\\\workflow-run-lists\\\\container-security-ci.yml.json",
                                                  "runListJsonExists":  false,
                                                  "runListJsonNote":  "Save a run-list JSON array or object with a runs array here when collecting run ids without GitHub CLI on this machine.",
                                                  "runsUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                  "queryMode":  "plan-only",
                                                  "candidateCount":  0,
                                                  "latestRunId":  "",
                                                  "latestStatus":  "",
                                                  "latestConclusion":  "",
                                                  "latestCreatedAt":  "",
                                                  "latestHeadSha":  "",
                                                  "latestUrl":  "",
                                                  "recommendedRunId":  "",
                                                  "recommendedHeadSha":  "",
                                                  "recommendedCreatedAt":  "",
                                                  "recommendedUrl":  "",
                                                  "latestRunIsRecommended":  false,
                                                  "readyForArtifactDownload":  false,
                                                  "requiredForReadiness":  false,
                                                  "runIdParameter":  "ContainerSecurityRunId",
                                                  "artifactName":  "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                  "note":  "Source artifact for security-evidence-finalizer-ci.yml."
                                              }
                                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-artifact-collection-plan.json"),
                """
                        {
                            "formatVersion":  "osmu.operations-artifact-collection-plan.v1",
                            "generatedAt":  "2026-06-30T12:48:10.1602611+09:00",
                            "result":  "security-source-action-required",
                            "sourceInvocationReport":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-evidence-plan-invocation.json",
                            "invocationResult":  "planned",
                            "sourceSummary":  "passed=82 pending=20",
                            "sourcePassedCount":  82,
                            "sourcePendingCount":  20,
                            "sourceTotalCount":  102,
                            "sourceCheckCount":  102,
                            "invocationSummary":  "selected=1 planned=1 blocked=0 executed=0 failed=0",
                            "sourceActionCount":  1,
                            "sourceActionOrders":  [
                                                       6
                                                   ],
                            "selectedActionOrders":  [
                                                         6
                                                     ],
                            "artifactCount":  1,
                            "requiredArtifactCount":  0,
                            "readyArtifactCount":  0,
                            "missingRequiredArtifactCount":  0,
                            "securitySourceArtifactCount":  1,
                            "readySecuritySourceArtifactCount":  0,
                            "missingSecuritySourceArtifactCount":  1,
                            "securityEvidenceFinalizerReady":  false,
                            "securityEvidenceFinalizerInputs":  [
                                                                     {
                                                                         "name":  "ImageSigningRunId",
                                                                         "runIdParameter":  "image_signing_run_id",
                                                                         "workflow":  "image-publish-sign-ci.yml",
                                                                         "artifactName":  "osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                         "artifactNameParameter":  "image_signing_artifact_name",
                                                                         "runId":  "<image-signing-run-id>",
                                                                         "ready":  false,
                                                                         "sourceArtifactSelected":  false,
                                                                         "sourceArtifactReady":  false,
                                                                         "requiredForSecurityFinalizer":  true,
                                                                         "note":  "Source artifact for security-evidence-finalizer-ci.yml."
                                                                     },
                                                                     {
                                                                         "name":  "ContainerSecurityRunId",
                                                                         "runIdParameter":  "container_security_run_id",
                                                                         "workflow":  "container-security-ci.yml",
                                                                         "artifactName":  "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                         "artifactNameParameter":  "container_security_artifact_name",
                                                                         "runId":  "<container-security-run-id>",
                                                                         "ready":  false,
                                                                         "sourceArtifactSelected":  true,
                                                                         "sourceArtifactReady":  false,
                                                                         "requiredForSecurityFinalizer":  true,
                                                                         "note":  "Source artifact for security-evidence-finalizer-ci.yml."
                                                                     }
                                                                 ],
                            "securityEvidenceFinalizerMissingRunIdInputs":  [
                                                                               "ImageSigningRunId",
                                                                               "ContainerSecurityRunId"
                                                                           ],
                            "securityEvidenceFinalizerCommand":  "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=\\u003cimage-signing-run-id\\u003e -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=\\u003ccontainer-security-run-id\\u003e -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true",
                            "operationsArtifactFinalizerCommand":  "",
                            "dataFlowStoragePlanInputNote":  "Optional direct data-flow plan input: add -f data_flow_storage_plan_json_base64=\\u003cbase64-latest-data-flow-storage-plan-json\\u003e to operations-readiness-artifact-finalizer-ci.yml when target data-flow storage transition evidence should be imported without waiting for a Kubernetes operations report sync artifact. MariaDB partition or dual-write plans must include the sanitized query-plan evidence summary.",
                            "dataFlowQueryRetentionBudgetInputNote":  "Optional direct data-flow query/retention budget input: add -f data_flow_query_retention_budget_json_base64=\\u003cbase64-latest-data-flow-query-retention-budget-json\\u003e to operations-readiness-artifact-finalizer-ci.yml when target query latency and retention budget evidence should be imported without waiting for a manual workflow artifact. The snapshot must be sanitized and result=passed.",
                            "dataFlowStorageTransitionRunbookInputNote":  "Optional direct data-flow transition runbook input: add -f data_flow_storage_transition_runbook_json_base64=\\u003cbase64-latest-data-flow-storage-transition-runbook-json\\u003e to operations-readiness-artifact-finalizer-ci.yml when target transition rehearsal evidence should be imported without waiting for a manual workflow artifact. The snapshot must be sanitized and result=passed.",
                            "minioBucketCorsInputNote":  "",
                            "localImportCommand":  "",
                            "decisionRule":  "After evidence workflows finish, fill missing run ids or paste GitHub Actions run URLs, verify artifact names, then either dispatch operations-readiness-artifact-finalizer-ci.yml or download artifacts locally and run import-operations-readiness-artifacts.ps1.",
                            "artifacts":  [
                                              {
                                                  "group":  "container-security-source",
                                                  "workflow":  "container-security-ci.yml",
                                                  "runId":  "\\u003ccontainer-security-run-id\\u003e",
                                                  "runIdInput":  "container_security_run_id",
                                                  "artifactName":  "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                  "artifactNameInput":  "container_security_artifact_name",
                                                  "downloadPath":  ".osmu-run/security-evidence-finalizer/source/container-security",
                                                  "downloadCommand":  "gh run download \\u003ccontainer-security-run-id\\u003e -n osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -D .osmu-run/security-evidence-finalizer/source/container-security",
                                                  "requiredForReadiness":  false,
                                                  "ready":  false,
                                                  "note":  "Source artifact for security-evidence-finalizer-ci.yml."
                                              }
                                          ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-evidence-handoff.json"),
                """
                        {
                            "formatVersion":  "osmu.operations-evidence-handoff.v1",
                            "generatedAt":  "2026-06-30T12:48:10.6661472+09:00",
                            "result":  "action-required",
                            "nextStep":  {
                                             "code":  "dispatch-ready-subset-browser",
                                             "title":  "Open browser or API dispatch for ready subset",
                                             "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                                             "reason":  "The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web/API dispatch exists for action(s): 6.",
                                             "note":  "Run the ready subset plan command first without -Execute, then use the web dispatch URL(s) after operator review. Alternatively, set GH_TOKEN or GITHUB_TOKEN and run API dispatch: powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute. GITHUB_CLI_AVAILABLE: GitHub CLI was not found on PATH. Web dispatch URL(s) for ready templates: action 6: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml. Review failed preflight checks and operator approvals before using browser dispatch.",
                                             "dispatchUrls":  [
                                                                  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
                                                              ]
                                         },
                            "currentBottleneck":  {
                                                      "code":  "dispatch-ready-subset-browser",
                                                      "title":  "Open browser or API dispatch for ready subset",
                                                      "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                                                      "reason":  "The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web/API dispatch exists for action(s): 6.",
                                                      "note":  "Run the ready subset plan command first without -Execute, then use the web dispatch URL(s) after operator review. Alternatively, set GH_TOKEN or GITHUB_TOKEN and run API dispatch: powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute. GITHUB_CLI_AVAILABLE: GitHub CLI was not found on PATH. Web dispatch URL(s) for ready templates: action 6: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml. Review failed preflight checks and operator approvals before using browser dispatch.",
                                                      "dispatchUrls":  [
                                                                           "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
                                                                       ]
                                                  },
                            "stageCount":  8,
                            "readyStageCount":  2,
                            "readinessSummary":  "passed=82 pending=20",
                            "readinessPassedCount":  82,
                            "readinessPendingCount":  20,
                            "readinessTotalCount":  102,
                            "readinessCheckCount":  102,
                            "dispatchPreflightResult":  "action-required",
                            "dispatchGithubRepository":  "chefbeom/object-storage-osmu",
                            "requiredGitHubSecretCount":  2,
                            "requiredGitHubSecrets":  [
                                                           "KUBECONFIG_B64",
                                                           "GITHUB_TOKEN"
                                                       ],
                            "requiredGitHubSecretSummaries":  [
                                                                    {
                                                                        "secretName":  "KUBECONFIG_B64",
                                                                        "actionCount":  1,
                                                                        "actionOrders":  [
                                                                                              1
                                                                                          ],
                                                                        "inputFreeBlockedActionCount":  1,
                                                                        "inputFreeBlockedActionOrders":  [
                                                                                                             1
                                                                                                         ]
                                                                    },
                                                                    {
                                                                        "secretName":  "GITHUB_TOKEN",
                                                                        "actionCount":  1,
                                                                        "actionOrders":  [
                                                                                              5
                                                                                          ],
                                                                        "inputFreeBlockedActionCount":  0,
                                                                        "inputFreeBlockedActionOrders":  [

                                                                                                         ]
                                                                    }
                                                                ],
                            "readyDispatchTemplateCount":  1,
                            "blockedDispatchTemplateCount":  0,
                            "readyDispatchActionOrders":  [
                                                              6
                                                          ],
                            "blockedDispatchActionOrders":  [

                                                            ],
                            "invocationSelectedActionOrders":  [
                                                                   6
                                                               ],
                            "dispatchPreflightSelectedActionOrders":  [
                                                                          6
                                                                      ],
                            "workflowRunIdPlanActionOrders":  [
                                                                  6
                                                              ],
                            "artifactCollectionActionOrders":  [
                                                                   6
                                                               ],
                            "readyDispatchWorkflows":  [
                                                           {
                                                               "actionOrder":  6,
                                                               "name":  "Container scan/SBOM evidence",
                                                               "category":  "security-hardening",
                                                               "actionType":  "security-ci",
                                                               "commandMode":  "Workflow",
                                                               "workflow":  "container-security-ci.yml",
                                                               "dispatchUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                               "readyToDispatch":  true,
                                                               "missingInputCount":  0,
                                                               "unsafeInputCount":  0,
                                                               "invalidInputCount":  0,
                                                               "ambiguousInputCount":  0,
                                                               "requiredSecrets":  [

                                                                                   ],
                                                               "workflowInputNames":  [

                                                                                      ],
                                                               "missingInputParameters":  [

                                                                                          ],
                                                               "operatorChecklist":  [

                                                                                     ]
                                                           }
                                                       ],
                            "blockedDispatchWorkflows":  [

                                                         ],
                            "invocationStale":  false,
                            "dispatchPreflightStale":  false,
                            "dispatchPreflightScopeMismatch":  false,
                            "workflowRunIdPlanStale":  false,
                            "workflowRunIdPlanScopeMismatch":  false,
                            "workflowRunIdPlanQueryMode":  "github-api",
                            "workflowRunIdPlanGithubApiTokenPresent":  false,
                            "workflowRunIdPlanGithubApiUnauthenticated":  true,
                            "workflowRunIdPlanQueryExecuted":  true,
                            "workflowRunIdPlanQueryExecutedCount":  1,
                            "workflowRunIdPlanQueryWorkflowCount":  1,
                            "workflowRunIdPlanQuerySucceededCount":  1,
                            "workflowRunIdPlanQueryErrorCount":  0,
                            "workflowRunIdPlanCandidateCount":  0,
                            "inputFreeBlockedReviewReportExists":  true,
                            "inputFreeBlockedReviewReportResult":  "blocked",
                            "inputFreeBlockedReviewReportGeneratedAt":  "2026-06-30T12:48:09.0000000+09:00",
                            "inputFreeBlockedReviewReportSelectedActionCount":  1,
                            "inputFreeBlockedReviewReportPlannedCount":  0,
                            "inputFreeBlockedReviewReportBlockedCount":  1,
                            "inputFreeBlockedReviewReportFailedCount":  0,
                            "inputFreeBlockedReviewReportExecutedCount":  0,
                            "inputFreeBlockedReviewReportActionOrders":  [
                                                                           6
                                                                       ],
                            "inputFreeBlockedReviewReportStale":  false,
                            "inputFreeBlockedReviewReportScopeMismatch":  false,
                            "inputFreeBlockedActions":  [
                                                        {
                                                            "actionOrder":  1,
                                                            "name":  "Storage expansion finalizer live evidence",
                                                            "status":  "blocked",
                                                            "blockReasonCount":  2,
                                                            "blockReasons":  [
                                                                                 "operator approval not confirmed",
                                                                                 "kubeconfig secret not confirmed"
                                                                             ],
                                                            "requiredInputCount":  0,
                                                            "requiredSecretCount":  1,
                                                            "requiredSecrets":  [
                                                                                  "KUBECONFIG_B64"
                                                                              ],
                                                            "needsOperatorApprovalConfirmation":  true,
                                                            "needsKubeconfigSecretConfirmation":  true,
                                                            "defaultBranchWorkflowMissing":  false,
                                                            "reviewCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -NoWrite",
                                                            "confirmedPlanCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 1",
                                                            "planCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 1"
                                                        }
                                                    ],
                            "operatorInputValuesProfileReportPath":  ".\\\\.osmu-run\\\\latest-operations-operator-input-values-profile.json",
                            "operatorInputValuesProfileExists":  true,
                            "operatorInputValuesProfileResult":  "action-required",
                            "operatorInputValuesProfileGeneratedAt":  "2026-06-30T12:50:00+09:00",
                            "operatorInputValuesProfileDefaultsUsed":  false,
                            "operatorInputValuesProfileDefaultsSkipped":  true,
                            "operatorInputValuesProfileDefaultsSkipReason":  "handoff package identity contains self-test marker",
                            "operatorInputValuesProfileDefaultValueCount":  0,
                            "operatorInputValuesProfileFilledValueCount":  0,
                            "operatorInputValuesProfileBlankValueCount":  4,
                            "operatorInputValuesProfileCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-operator-input-values-profile.ps1 -WorksheetCsvPath .\\\\.osmu-run\\\\latest-operations-operator-input-worksheet.csv -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -RunRef <run-ref> -ChangeApprovalRef <change-id> -StartTime <iso-start> -CompletedTime <iso-complete> -ApprovedAt <iso-approved>",
                            "operatorInputValuesCheckCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-operator-input-values-check.ps1 -ValuesCsvPath .\\\\.osmu-run\\\\latest-operations-operator-input-values-profile.csv",
                            "artifactCollectionStale":  false,
                            "artifactCollectionScopeMismatch":  false,
                            "staleReportCount":  0,
                            "blockedActionCount":  0,
                            "missingWorkflowRunCount":  1,
                            "missingRequiredArtifactCount":  0,
                            "failedImportCount":  0,
                            "finalizerFailedCount":  0,
                            "finalizerGapCount":  0,
                            "browserDispatchChecklistCount":  1,
                            "browserDispatchChecklist":  [
                                                             {
                                                                 "actionOrder":  6,
                                                                 "name":  "Container scan/SBOM evidence",
                                                                 "category":  "security-hardening",
                                                                 "actionType":  "security-ci",
                                                                 "workflow":  "container-security-ci.yml",
                                                                 "dispatchUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                                 "runsUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                                 "runIdParameter":  "ContainerSecurityRunId",
                                                                 "artifactName":  "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                 "runListJsonPath":  ".\\\\.osmu-run\\\\workflow-run-lists\\\\container-security-ci.yml.json",
                                                                 "runListJsonDirectoryCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory .\\\\.osmu-run\\\\workflow-run-lists",
                                                                 "manualArtifactCollectionCommand":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                 "workflowInputNames":  [

                                                                                        ],
                                                                 "operatorChecklist":  [

                                                                                       ],
                                                                 "steps":  [
                                                                               "Open the workflow dispatch URL and select branch main.",
                                                                               "No workflow inputs are required for this dispatch template.",
                                                                               "Run the workflow and open the workflow run page from the runs URL.",
                                                                               "Copy the numeric run id or full workflow run URL into ContainerSecurityRunId.",
                                                                               "Regenerate artifact collection with the manual run-id command."
                                                                           ]
                                                             }
                                                         ],
                            "securityEvidenceFinalizerRunIdInputHintCount":  2,
                            "securityEvidenceFinalizerRunIdInputHints":  [
                                                                               {
                                                                                   "workflow":  "image-publish-sign-ci.yml",
                                                                                   "group":  "image-signing-source",
                                                                                   "actionOrders":  [],
                                                                                   "runIdParameter":  "ImageSigningRunId",
                                                                                   "recommendedRunId":  "",
                                                                                   "artifactName":  "osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                                   "requiredForReadiness":  false,
                                                                                   "readyForArtifactDownload":  false,
                                                                                   "runsUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml",
                                                                                   "runListJsonPath":  ".\\\\.osmu-run\\\\workflow-run-lists\\\\image-publish-sign-ci.yml.json",
                                                                                   "queryCommand":  "gh run list --workflow image-publish-sign-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle",
                                                                                   "gitHubApiQueryUrl":  "https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20",
                                                                                   "sourceSelected":  false,
                                                                                   "supplementalForSecurityFinalizer":  true
                                                                               },
                                                                               {
                                                                                   "workflow":  "container-security-ci.yml",
                                                                                   "group":  "container-security-source",
                                                                                   "actionOrders":  [
                                                                                                        6
                                                                                                    ],
                                                                                   "runIdParameter":  "ContainerSecurityRunId",
                                                                                   "recommendedRunId":  "",
                                                                                   "artifactName":  "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                                   "requiredForReadiness":  false,
                                                                                   "readyForArtifactDownload":  false,
                                                                                   "runsUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                                                   "runListJsonPath":  ".\\\\.osmu-run\\\\workflow-run-lists\\\\container-security-ci.yml.json",
                                                                                   "queryCommand":  "gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle",
                                                                                   "gitHubApiQueryUrl":  "https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20",
                                                                                   "sourceSelected":  true,
                                                                                   "supplementalForSecurityFinalizer":  false
                                                                               }
                                                                           ],
                            "postDispatchCommands":  [
                                                       {
                                                           "name":  "Collect workflow run ids from saved run-list JSON",
                                                           "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>",
                                                           "note":  "Use after browser dispatch when GitHub CLI is unavailable locally. Store gh run list JSON per workflow in the directory, then let the run-id plan derive artifact commands."
                                                       },
                                                       {
                                                           "name":  "Collect workflow run ids with GitHub REST API",
                                                           "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1",
                                                           "note":  "Use after browser dispatch when GitHub CLI is unavailable and the repository Actions API is readable. Uses GH_TOKEN or GITHUB_TOKEN if present and never writes token values."
                                                       },
                                                       {
                                                           "name":  "Collect workflow run ids with GitHub CLI",
                                                           "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -Execute",
                                                           "note":  "Use after browser dispatch when gh is installed and authenticated."
                                                       },
                                                       {
                                                           "name":  "Regenerate artifact collection plan with browser run ids",
                                                           "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                           "note":  "Use when the workflow run page URL is available but gh/run-list JSON is not. Replace any <RunIdParameter> placeholders with numeric GitHub Actions run ids or full workflow run URLs before running."
                                                       },
                                                       {
                                                           "name":  "Regenerate artifact collection plan after run id collection",
                                                           "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                           "note":  "Use after one of the run-id collection commands has produced recommended run ids so artifact names, download commands, and finalizer commands stay in the same selected-action scope."
                                                       }
                                                   ],
                            "stages":  [
                                           {
                                               "name":  "operations-readiness",
                                               "reportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-readiness.json",
                                               "exists":  true,
                                               "result":  "pending",
                                               "summary":  "passed=82 pending=20",
                                               "ready":  false,
                                               "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-readiness.ps1",
                                               "note":  "Production/B2B readiness gate summary."
                                           },
                                           {
                                               "name":  "evidence-plan",
                                               "reportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-evidence-plan.json",
                                               "exists":  true,
                                               "result":  "action-required",
                                               "summary":  "pending=20 actions=20 unplanned=0",
                                               "ready":  true,
                                               "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-evidence-plan.ps1",
                                               "note":  "Ordered remediation plan."
                                           },
                                           {
                                               "name":  "evidence-invocation",
                                               "reportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-evidence-plan-invocation.json",
                                               "exists":  true,
                                               "result":  "planned",
                                               "summary":  "selected=1 planned=1 blocked=0 failed=0",
                                               "ready":  true,
                                               "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1",
                                               "note":  "Guarded workflow/local command invocation report."
                                           },
                                           {
                                               "name":  "dispatch-preflight",
                                               "reportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-dispatch-preflight.json",
                                               "exists":  true,
                                               "result":  "action-required",
                                               "summary":  "selected=1 readyTemplates=1 blockedTemplates=0 missingInputs=0 readyOrders=6",
                                               "ready":  false,
                                               "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-dispatch-preflight.ps1 -CheckGitHubCli",
                                               "note":  "No-execute workflow dispatch preflight and input template readiness."
                                           },
                                           {
                                               "name":  "workflow-run-ids",
                                               "reportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-workflow-run-ids.json",
                                               "exists":  true,
                                               "result":  "query-required",
                                               "summary":  "workflows=1 ready=0 missing=1 stale=0 actionOrders=6",
                                               "ready":  false,
                                               "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1",
                                               "note":  "GitHub workflow run id handoff. Prefer the GitHub REST API command when gh is unavailable; it uses GH_TOKEN or GITHUB_TOKEN only if present and never writes token values. Browser workflow runs URL(s): container-security-ci.yml: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml."
                                           },
                                           {
                                               "name":  "artifact-collection",
                                               "reportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-artifact-collection-plan.json",
                                               "exists":  true,
                                               "result":  "security-source-action-required",
                                               "summary":  "artifacts=1 ready=0 missingRequired=0 securitySources=0/1 missingSecuritySources=1 actionOrders=6",
                                               "ready":  false,
                                               "command":  "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=\\u003cimage-signing-run-id\\u003e -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=\\u003ccontainer-security-run-id\\u003e -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true",
                                               "note":  "Artifact download/import or finalizer plan."
                                           },
                                           {
                                               "name":  "artifact-import",
                                               "reportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-readiness-artifact-import.json",
                                               "exists":  false,
                                               "result":  "",
                                               "summary":  "failed=0",
                                               "ready":  false,
                                               "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\import-operations-readiness-artifacts.ps1",
                                               "note":  "Promotion of downloaded evidence artifacts into latest readiness paths."
                                           },
                                           {
                                               "name":  "operations-finalizer",
                                               "reportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-readiness-finalize.json",
                                               "exists":  false,
                                               "result":  "",
                                               "summary":  "readiness= failed=0 gaps=0",
                                               "ready":  false,
                                               "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\finalize-operations-readiness.ps1",
                                               "note":  "Combined finalizer and final readiness regeneration."
                                           }
                                       ]
                        }
                        """
        );
        Files.writeString(
                Path.of(".osmu-run/latest-operations-readiness-convergence.json"),
                """
                        {
                            "formatVersion":  "osmu.operations-readiness-convergence.v1",
                            "generatedAt":  "2026-06-30T12:48:11.1058503+09:00",
                            "result":  "action-required",
                            "handoffReportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-evidence-handoff.json",
                            "readinessReportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-readiness.json",
                            "operationsReadinessFinalizeReportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-readiness-finalize.json",
                            "kubernetesOperationsReportSyncReportPath":  "C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-kubernetes-operations-report-sync.json",
                            "handoffExists":  true,
                            "handoffResult":  "action-required",
                            "handoffStale":  false,
                            "handoffTimestamp":  "2026-06-30T12:48:10.6661472+09:00",
                            "handoffTimestampSource":  "generatedAt",
                            "readinessTimestamp":  "2026-06-30T12:48:07.4142068+09:00",
                            "readinessTimestampSource":  "generatedAt",
                            "readinessExists":  true,
                            "readinessResult":  "pending",
                            "readinessSummary":  "passed=82 pending=20",
                            "readinessPassedCount":  82,
                            "readinessPendingCount":  20,
                            "readinessTotalCount":  102,
                            "readinessCheckCount":  102,
                            "finalizerExists":  false,
                            "finalizerResult":  "",
                            "finalizerReadinessResult":  "",
                            "finalizerFailedCount":  0,
                            "finalizerFailedCountValid":  false,
                            "finalizerFailedCountRaw":  "\\u003cmissing\\u003e",
                            "finalizerGapCount":  0,
                            "kubernetesReportSyncExists":  true,
                            "kubernetesReportSyncResult":  "planned",
                            "kubernetesReportSyncStale":  true,
                            "kubernetesReportSyncTimestamp":  "2026-06-16T09:33:30.1080022+09:00",
                            "kubernetesReportSyncTimestampSource":  "generatedAt",
                            "kubernetesReportSyncFreshnessReason":  "Kubernetes operations report sync evidence is older than the latest handoff/readiness/finalizer input: sync=2026-06-16T09:33:30.1080022+09:00 via generatedAt; latest=2026-06-30T12:48:10.6661472+09:00 via generatedAt.",
                            "kubernetesReportSyncFailedCount":  0,
                            "kubernetesReportSyncFailedCountValid":  true,
                            "kubernetesReportSyncFailedCountRaw":  "0",
                            "kubernetesReportSyncConfigMapName":  "osmu-operations-reports",
                            "kubernetesReportSyncConfigMapKey":  "latest-operations-readiness-convergence.json",
                            "kubernetesReportSyncSourceReportResult":  "action-required",
                            "kubernetesReportSyncWorkflowCommand":  "gh workflow run kubernetes-operations-report-sync-ci.yml -f namespace=osmu -f report_path=C:\\\\project\\\\object-storage-osmu\\\\.osmu-run\\\\latest-operations-readiness-convergence.json -f run_live=true -f apply=false -f data_flow_storage_plan_json_base64=\\u003cbase64-latest-data-flow-storage-plan-json\\u003e -f data_flow_query_retention_budget_json_base64=\\u003cbase64-latest-data-flow-query-retention-budget-json\\u003e -f data_flow_storage_transition_runbook_json_base64=\\u003cbase64-latest-data-flow-storage-transition-runbook-json\\u003e",
                            "kubernetesReportSyncWorkflowNote":  "For GitHub Actions sync, include data_flow_storage_plan_json_base64 only when .osmu-run/latest-data-flow-storage-plan.json should be carried into the operations report ConfigMap, include data_flow_query_retention_budget_json_base64 only when .osmu-run/latest-data-flow-query-retention-budget-evidence.json should be carried into the same ConfigMap, and include data_flow_storage_transition_runbook_json_base64 only when .osmu-run/latest-data-flow-storage-transition-runbook-evidence.json should be carried into the same ConfigMap. MariaDB partition or dual-write plans must include the sanitized query-plan evidence summary, and query/retention budget and transition runbook evidence must be result=passed with no raw SQL, raw EXPLAIN, object keys, raw event messages, or credential-shaped content. Omit inputs when no target analytics-storage evidence is ready.",
                            "kubernetesReportSyncReady":  false,
                            "handoffFinalizerGapCount":  0,
                            "stageCount":  8,
                            "readyStageCount":  2,
                            "blockedActionCount":  0,
                            "handoffRequiredGitHubSecretCount":  2,
                            "handoffRequiredGitHubSecrets":  [
                                                                 "KUBECONFIG_B64",
                                                                 "GITHUB_TOKEN"
                                                             ],
                            "handoffRequiredGitHubSecretSummaries":  [
                                                                          {
                                                                              "secretName":  "KUBECONFIG_B64",
                                                                              "actionCount":  1,
                                                                              "actionOrders":  [
                                                                                                    1
                                                                                                ],
                                                                              "inputFreeBlockedActionCount":  1,
                                                                              "inputFreeBlockedActionOrders":  [
                                                                                                                   1
                                                                                                               ]
                                                                          }
                                                                      ],
                            "handoffWorkflowRunIdPlanQueryMode":  "github-api",
                            "handoffWorkflowRunIdPlanGithubApiTokenPresent":  false,
                            "handoffWorkflowRunIdPlanGithubApiUnauthenticated":  true,
                            "handoffWorkflowRunIdPlanQueryExecuted":  true,
                            "handoffWorkflowRunIdPlanQueryExecutedCount":  1,
                            "handoffWorkflowRunIdPlanQueryWorkflowCount":  1,
                            "handoffWorkflowRunIdPlanQuerySucceededCount":  1,
                            "handoffWorkflowRunIdPlanQueryErrorCount":  0,
                            "handoffWorkflowRunIdPlanCandidateCount":  0,
                            "handoffInputFreeBlockedReviewReportExists":  true,
                            "handoffInputFreeBlockedReviewReportResult":  "blocked",
                            "handoffInputFreeBlockedReviewReportGeneratedAt":  "2026-06-30T12:48:09.0000000+09:00",
                            "handoffInputFreeBlockedReviewReportSelectedActionCount":  1,
                            "handoffInputFreeBlockedReviewReportPlannedCount":  0,
                            "handoffInputFreeBlockedReviewReportBlockedCount":  1,
                            "handoffInputFreeBlockedReviewReportFailedCount":  0,
                            "handoffInputFreeBlockedReviewReportExecutedCount":  0,
                            "handoffInputFreeBlockedReviewReportActionOrders":  [
                                                                                  6
                                                                              ],
                            "handoffInputFreeBlockedReviewReportStale":  false,
                            "handoffInputFreeBlockedReviewReportScopeMismatch":  false,
                            "handoffOperatorInputValuesProfileReportPath":  ".\\\\.osmu-run\\\\latest-operations-operator-input-values-profile.json",
                            "handoffOperatorInputValuesProfileExists":  true,
                            "handoffOperatorInputValuesProfileResult":  "action-required",
                            "handoffOperatorInputValuesProfileGeneratedAt":  "2026-06-30T12:50:00+09:00",
                            "handoffOperatorInputValuesProfileDefaultsUsed":  false,
                            "handoffOperatorInputValuesProfileDefaultsSkipped":  true,
                            "handoffOperatorInputValuesProfileDefaultsSkipReason":  "handoff package identity contains self-test marker",
                            "handoffOperatorInputValuesProfileDefaultValueCount":  0,
                            "handoffOperatorInputValuesProfileFilledValueCount":  0,
                            "handoffOperatorInputValuesProfileBlankValueCount":  4,
                            "missingWorkflowRunCount":  1,
                            "missingRequiredArtifactCount":  0,
                            "failedImportCount":  0,
                            "currentBottleneck":  {
                                                      "code":  "dispatch-ready-subset-browser",
                                                      "title":  "Open browser or API dispatch for ready subset",
                                                      "reason":  "The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web/API dispatch exists for action(s): 6.",
                                                      "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                                                      "note":  "Run the ready subset plan command first without -Execute, then use the web dispatch URL(s) after operator review. Alternatively, set GH_TOKEN or GITHUB_TOKEN and run API dispatch: powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute. GITHUB_CLI_AVAILABLE: GitHub CLI was not found on PATH. Web dispatch URL(s) for ready templates: action 6: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml. Review failed preflight checks and operator approvals before using browser dispatch. Security finalizer dependency: this dispatch can supply ContainerSecurityRunId; also collect ImageSigningRunId before running security-evidence-finalizer-ci.yml.",
                                                      "dispatchUrls":  [
                                                                           "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
                                                                       ]
                                                  },
                            "handoffBrowserDispatchDependencyNotes":  [
                                                                    "Security finalizer dependency: this dispatch can supply ContainerSecurityRunId; also collect ImageSigningRunId before running security-evidence-finalizer-ci.yml."
                                                                ],
                            "handoffSecurityEvidenceFinalizerRunIdInputHintCount":  2,
                            "handoffSecurityEvidenceFinalizerRunIdInputHints":  [
                                                                                     {
                                                                                         "workflow":  "image-publish-sign-ci.yml",
                                                                                         "group":  "image-signing-source",
                                                                                         "actionOrders":  [],
                                                                                         "runIdParameter":  "ImageSigningRunId",
                                                                                         "recommendedRunId":  "",
                                                                                         "artifactName":  "osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                                         "requiredForReadiness":  false,
                                                                                         "readyForArtifactDownload":  false,
                                                                                         "runsUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml",
                                                                                         "runListJsonPath":  ".\\\\.osmu-run\\\\workflow-run-lists\\\\image-publish-sign-ci.yml.json",
                                                                                         "queryCommand":  "gh run list --workflow image-publish-sign-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle",
                                                                                         "gitHubApiQueryUrl":  "https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20",
                                                                                         "sourceSelected":  false,
                                                                                         "supplementalForSecurityFinalizer":  true
                                                                                     },
                                                                                     {
                                                                                         "workflow":  "container-security-ci.yml",
                                                                                         "group":  "container-security-source",
                                                                                         "actionOrders":  [
                                                                                                              6
                                                                                                          ],
                                                                                         "runIdParameter":  "ContainerSecurityRunId",
                                                                                         "recommendedRunId":  "",
                                                                                         "artifactName":  "osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                                         "requiredForReadiness":  false,
                                                                                         "readyForArtifactDownload":  false,
                                                                                         "runsUrl":  "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml",
                                                                                         "runListJsonPath":  ".\\\\.osmu-run\\\\workflow-run-lists\\\\container-security-ci.yml.json",
                                                                                         "queryCommand":  "gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle",
                                                                                         "gitHubApiQueryUrl":  "https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20",
                                                                                         "sourceSelected":  true,
                                                                                         "supplementalForSecurityFinalizer":  false
                                                                                     }
                                                                                 ],
                            "handoffPostDispatchCommands":  [
                                                                {
                                                                    "name":  "Collect workflow run ids from saved run-list JSON",
                                                                    "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>",
                                                                    "note":  "Use after browser dispatch when GitHub CLI is unavailable locally. Store gh run list JSON per workflow in the directory, then let the run-id plan derive artifact commands."
                                                                },
                                                                {
                                                                    "name":  "Collect workflow run ids with GitHub REST API",
                                                                    "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1",
                                                                    "note":  "Use after browser dispatch when GitHub CLI is unavailable and the repository Actions API is readable. Uses GH_TOKEN or GITHUB_TOKEN if present and never writes token values."
                                                                },
                                                                {
                                                                    "name":  "Collect workflow run ids with GitHub CLI",
                                                                    "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -Execute",
                                                                    "note":  "Use after browser dispatch when gh is installed and authenticated."
                                                                },
                                                                {
                                                                    "name":  "Regenerate artifact collection plan with browser run ids",
                                                                    "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                    "note":  "Use when the workflow run page URL is available but gh/run-list JSON is not. Replace any <RunIdParameter> placeholders with numeric GitHub Actions run ids or full workflow run URLs before running."
                                                                },
                                                                {
                                                                    "name":  "Regenerate artifact collection plan after run id collection",
                                                                    "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68",
                                                                    "note":  "Use after one of the run-id collection commands has produced recommended run ids so artifact names, download commands, and finalizer commands stay in the same selected-action scope."
                                                                }
                                                            ],
                            "recommendedCommands":  [
                                                        {
                                                            "order":  1,
                                                            "name":  "Open browser or API dispatch for ready subset",
                                                            "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6",
                                                            "reason":  "The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web/API dispatch exists for action(s): 6.",
                                                            "note":  "Run the ready subset plan command first without -Execute, then use the web dispatch URL(s) after operator review. Alternatively, set GH_TOKEN or GITHUB_TOKEN and run API dispatch: powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute. GITHUB_CLI_AVAILABLE: GitHub CLI was not found on PATH. Web dispatch URL(s) for ready templates: action 6: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml. Review failed preflight checks and operator approvals before using browser dispatch. Security finalizer dependency: this dispatch can supply ContainerSecurityRunId; also collect ImageSigningRunId before running security-evidence-finalizer-ci.yml.",
                                                            "dispatchUrls":  [
                                                                                 "https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"
                                                                             ]
                                                        },
                                                        {
                                                            "order":  2,
                                                            "name":  "Review operations-readiness",
                                                            "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-readiness.ps1",
                                                            "reason":  "Production/B2B readiness gate summary.",
                                                            "note":  ""
                                                        },
                                                        {
                                                            "order":  3,
                                                            "name":  "Review dispatch-preflight",
                                                            "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-dispatch-preflight.ps1 -CheckGitHubCli",
                                                            "reason":  "No-execute workflow dispatch preflight and input template readiness.",
                                                            "note":  ""
                                                        },
                                                        {
                                                            "order":  4,
                                                            "name":  "Review workflow-run-ids",
                                                            "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1",
                                                            "reason":  "GitHub workflow run id handoff. Prefer the GitHub REST API command when gh is unavailable; browser workflow runs URL(s): container-security-ci.yml: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml.",
                                                            "note":  ""
                                                        },
                                                        {
                                                            "order":  5,
                                                            "name":  "Review artifact-collection",
                                                            "command":  "gh workflow run security-evidence-finalizer-ci.yml -f image_signing_run_id=\\u003cimage-signing-run-id\\u003e -f image_signing_artifact_name=osmu-image-signing-v0.1.0-rc.1-a0730b64636a22c38639b5f5c647f2e13792fc68 -f container_security_run_id=\\u003ccontainer-security-run-id\\u003e -f container_security_artifact_name=osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68 -f fail_if_not_passed=true",
                                                            "reason":  "Artifact download/import or finalizer plan.",
                                                            "note":  ""
                                                        },
                                                        {
                                                            "order":  6,
                                                            "name":  "Review artifact-import",
                                                            "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\import-operations-readiness-artifacts.ps1",
                                                            "reason":  "Promotion of downloaded evidence artifacts into latest readiness paths.",
                                                            "note":  ""
                                                        },
                                                        {
                                                            "order":  7,
                                                            "name":  "Review operations-finalizer",
                                                            "command":  "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\finalize-operations-readiness.ps1",
                                                            "reason":  "Combined finalizer and final readiness regeneration.",
                                                            "note":  ""
                                                        }
                                                    ],
                            "decisionRule":  "Operations readiness convergence is ready only when the handoff result is ready/none, the readiness report is ready, the operations readiness finalizer report exists with result=ready, readinessResult=ready, typed integer failedCount=0, and no gaps, and the Kubernetes operations report sync evidence is fresh against the latest handoff/readiness/finalizer inputs and confirms result=applied, typed integer failedCount=0, and sourceReportResult=ready.",
                            "safetyPolicy":  "This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance."
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
                          "dataFlowQueryRetentionBudgetConfigMapKey": "latest-data-flow-query-retention-budget-evidence.json",
                          "publishDataFlowStoragePlanToConfigMap": true,
                          "publishDataFlowStorageTransitionRunbookToConfigMap": true,
                          "publishDataFlowQueryRetentionBudgetToConfigMap": true,
                          "sourceReportPath": ".osmu-run/latest-operations-readiness-convergence.json",
                          "sourceReportFormatVersion": "osmu.operations-readiness-convergence.v1",
                          "sourceReportResult": "action-required",
                          "sourceReportBytes": 5249,
                          "sourceReportSha256": "abc123",
                          "dataFlowQueryRetentionBudgetResult": "passed",
                          "dataFlowQueryRetentionBudgetStoragePlanResult": "passed",
                          "dataFlowQueryRetentionBudgetCandidateStore": "MARIADB_PARTITION",
                          "dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs": 500,
                          "dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs": 420,
                          "dataFlowQueryRetentionBudgetRetentionBudgetSeconds": 30,
                          "dataFlowQueryRetentionBudgetFailureCount": 0,
                          "dataFlowQueryRetentionBudgetCheckCount": 8,
                          "dataFlowQueryRetentionBudgetBytes": 1024,
                          "dataFlowQueryRetentionBudgetSha256": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
                          "dataFlowStorageTransitionRunbookResult": "failed",
                          "dataFlowStorageTransitionRunbookStoragePlanResult": "plan-ready-execute-required",
                          "dataFlowStorageTransitionRunbookCandidateStore": "MARIADB_PARTITION",
                          "dataFlowStorageTransitionRunbookFailureCount": 2,
                          "dataFlowStorageTransitionRunbookCheckCount": 10,
                          "dataFlowStorageTransitionRunbookBytes": 2048,
                          "dataFlowStorageTransitionRunbookSha256": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
                          "clientDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --from-file=latest-data-flow-query-retention-budget-evidence.json=.osmu-run/latest-data-flow-query-retention-budget-evidence.json --dry-run=client -o yaml",
                          "serverDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --from-file=latest-data-flow-query-retention-budget-evidence.json=.osmu-run/latest-data-flow-query-retention-budget-evidence.json --dry-run=server -o yaml",
                          "applyCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --from-file=latest-data-flow-query-retention-budget-evidence.json=.osmu-run/latest-data-flow-query-retention-budget-evidence.json --dry-run=client -o yaml | kubectl apply -f -",
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

        ResultActions readiness = mockMvc.perform(get("/api/admin/dashboard/readiness")
                        .header("Authorization", "Bearer " + adminToken));
        readiness.andExpect(status().isOk());
        readiness.andExpect(jsonPath("$.data.status").value("REVIEW"));
        readiness.andExpect(jsonPath("$.data.items[*].category").value(hasItem("OPERATIONS")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_PENDING")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_EVIDENCE_PLAN_INVOCATION")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_DISPATCH_PREFLIGHT")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_WORKFLOW_RUN_ID_PLAN")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_ARTIFACT_COLLECTION_PLAN")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_FINALIZER")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_EVIDENCE_HANDOFF")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("ENTERPRISE_AUTH_JIT_ROLLBACK_EVIDENCE")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("DATA_FLOW_STORAGE_PLAN")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("MINIO_BUCKET_CORS_VERIFICATION")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("CLUSTER_NETWORK_ACCESS_REVIEW_EVIDENCE")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("HELM_VALUES_HARDENING_EVIDENCE")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("SUPPORT_ESCALATION_HANDOFF_EVIDENCE")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_CONVERGENCE")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("KUBERNETES_OPERATIONS_REPORT_SYNC")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_CHECK")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_ARTIFACT_IMPORT")));
        readiness.andExpect(jsonPath("$.data.items[*].code").value(hasItem("DATA_FLOW_STORAGE_TRANSITION_RUNBOOK")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness remains pending: passed=82 pending=20.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations evidence invocation is planned: selectedActionCount=1, plannedCount=1, blockedCount=0.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations dispatch preflight is action-required: failedChecks=2, missingInputs=0, invalidInputs=0, warnings=0.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations workflow run id plan is query-required: workflows=1, missingRuns=1.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations artifact collection plan is security-source-action-required: artifacts=1, missingRequired=0, missingSecuritySources=1, missingSecurityFinalizerInputs=ImageSigningRunId/ContainerSecurityRunId.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness finalizer is pending: readinessResult=pending, failedCount=0.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations evidence handoff is action-required: next=dispatch-ready-subset-browser, dispatchReady=1, dispatchBlocked=0, blockedActions=0, missingRuns=1, missingArtifacts=0.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Data-flow storage plan is plan-ready-execute-required: store=MARIADB_PARTITION, pending=2/4.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Data-flow transition runbook evidence is failed: store=MARIADB_PARTITION, failures=2/10.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("MinIO bucket CORS verification is failed: rules=1, exposedHeaders=2, failures=1, planned=0.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Cluster network access review evidence is failed: failures=1/21.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Helm values hardening evidence is failed: failures=1/19.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Support escalation handoff evidence is failed: failures=1/31.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness convergence is action-required: bottleneck=dispatch-ready-subset-browser, stages=2/8.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Kubernetes operations report sync is planned: namespace=osmu, configMap=osmu-operations-reports, failedCount=0. sourceReportResult=action-required.")));
        readiness.andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness artifact import is failed: status=artifact-import-failed, failedCount=2.")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_PLAN_INVOCATION')].evidencePath").value(hasItem(".osmu-run/latest-operations-evidence-plan-invocation.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_PLAN_INVOCATION')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_DISPATCH_PREFLIGHT')].evidencePath").value(hasItem(".osmu-run/latest-operations-dispatch-preflight.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_DISPATCH_PREFLIGHT')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-dispatch-preflight.ps1")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_DISPATCH_PREFLIGHT')].remediationWorkflowCommand").value(hasItem("git status --short")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_DISPATCH_PREFLIGHT')].remediationNote").value(hasItem(containsString("Run the ready plan command first without -Execute."))));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_DISPATCH_PREFLIGHT')].remediationNote").value(hasItem(containsString("Ready subset GitHub REST API dispatch command is available after setting GH_TOKEN or GITHUB_TOKEN."))));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_WORKFLOW_RUN_ID_PLAN')].evidencePath").value(hasItem(".osmu-run/latest-operations-workflow-run-ids.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_WORKFLOW_RUN_ID_PLAN')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_ARTIFACT_COLLECTION_PLAN')].evidencePath").value(hasItem(".osmu-run/latest-operations-artifact-collection-plan.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_ARTIFACT_COLLECTION_PLAN')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_HANDOFF')].evidencePath").value(hasItem(".osmu-run/latest-operations-evidence-handoff.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_HANDOFF')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_HANDOFF')].remediationNote").value(hasItem("The invocation is planned and dispatch preflight only failed because GitHub CLI is unavailable; ready web/API dispatch exists for action(s): 6. Run the ready subset plan command first without -Execute, then use the web dispatch URL(s) after operator review. Alternatively, set GH_TOKEN or GITHUB_TOKEN and run API dispatch: powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute. GITHUB_CLI_AVAILABLE: GitHub CLI was not found on PATH. Web dispatch URL(s) for ready templates: action 6: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml. Review failed preflight checks and operator approvals before using browser dispatch.")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'ENTERPRISE_AUTH_JIT_ROLLBACK_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-enterprise-auth-jit-rollback-evidence.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'ENTERPRISE_AUTH_JIT_ROLLBACK_EVIDENCE')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-enterprise-auth-jit-rollback-evidence.ps1")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_STORAGE_PLAN')].evidencePath").value(hasItem(".osmu-run/latest-data-flow-storage-plan.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_STORAGE_PLAN')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-data-flow-storage-plan.ps1 -CandidateStore <store> -ExpectedPeakEventsPerDay <n> -ExpectedQueryWindowDays <days> -TargetP95QueryLatencyMs <p95-ms> -ConfirmNoObjectKeyInAggregates -ConfirmBackfillPlan -ConfirmRollbackPlan -ConfirmDashboardCutoverPlan -ConfirmRetentionJobBudget -ConfirmExplainEvidence -QueryPlanEvidenceJsonPath .\\.osmu-run\\latest-mariadb-query-plan-evidence.json -RequireQueryPlanEvidence")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_STORAGE_PLAN')].remediationNote").value(hasItem("OSMU operations analytics only. This plan is not AWS billing parity and aggregate stores must not include object keys or raw event messages.")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_QUERY_RETENTION_BUDGET')].evidencePath").value(hasItem(".osmu-run/latest-data-flow-query-retention-budget-evidence.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_QUERY_RETENTION_BUDGET')].remediationWorkflow").value(hasItem(".github/workflows/manual-data-flow-query-retention-budget-evidence.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_STORAGE_TRANSITION_RUNBOOK')].evidencePath").value(hasItem(".osmu-run/latest-data-flow-storage-transition-runbook-evidence.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'DATA_FLOW_STORAGE_TRANSITION_RUNBOOK')].remediationWorkflow").value(hasItem(".github/workflows/manual-data-flow-storage-transition-runbook-evidence.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'MINIO_BUCKET_CORS_VERIFICATION')].evidencePath").value(hasItem(".osmu-run/latest-minio-bucket-cors-verification.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'MINIO_BUCKET_CORS_VERIFICATION')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\verify-minio-bucket-cors.ps1 -BucketName <bucket> -MinioAlias <alias> -Execute -FailIfNotPassed")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'MINIO_BUCKET_CORS_VERIFICATION')].remediationNote").value(hasItem("This evidence verifies MinIO bucket CORS needed by OSMU browser multipart upload and traceability. It is not AWS S3 parity work, and it does not store raw CORS XML, credentials, bearer tokens, private keys, MinIO root credentials, or object data.")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'CLUSTER_NETWORK_ACCESS_REVIEW_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-cluster-network-access-review-evidence.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'CLUSTER_NETWORK_ACCESS_REVIEW_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/manual-cluster-network-access-review-evidence.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'HELM_VALUES_HARDENING_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-helm-values-hardening-evidence.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'HELM_VALUES_HARDENING_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/manual-helm-values-hardening-evidence.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'SUPPORT_ESCALATION_HANDOFF_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-support-escalation-handoff-evidence.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'SUPPORT_ESCALATION_HANDOFF_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/manual-support-escalation-handoff-evidence.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'SUPPORT_ESCALATION_HANDOFF_EVIDENCE')].remediationNote").value(hasItem("Evidence stores document hashes, labels, booleans, and non-secret references only. Do not embed passwords, tokens, kubeconfig, private keys, support desk credentials, customer data, or raw incident transcripts.")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].evidencePath").value(hasItem(".osmu-run/latest-operations-readiness-artifact-import.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\import-operations-readiness-artifacts.ps1")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].remediationWorkflow").value(hasItem(".github/workflows/operations-readiness-artifact-finalizer-ci.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].remediationNote").value(hasItem("Artifact import copies only JSON/Markdown evidence files and does not read kubeconfig, registry tokens, DR secrets, or bearer tokens.")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].evidencePath").value(hasItem(".osmu-run/latest-operations-readiness-finalize.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\finalize-operations-readiness.ps1")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].remediationWorkflow").value(hasItem(".github/workflows/operations-readiness-finalizer-ci.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].remediationNote").value(hasItem("Operations readiness finalizer masks admin passwords in recorded commands and does not write kubeconfig, registry tokens, DR secrets, or bearer tokens.")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CONVERGENCE')].evidencePath").value(hasItem(".osmu-run/latest-operations-readiness-convergence.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CONVERGENCE')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CONVERGENCE')].remediationNote").value(hasItem(containsString("ready web/API dispatch exists for action(s): 6"))));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].evidencePath").value(hasItem(".osmu-run/latest-kubernetes-operations-report-sync.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationCommand").value(hasItem("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --from-file=latest-data-flow-query-retention-budget-evidence.json=.osmu-run/latest-data-flow-query-retention-budget-evidence.json --dry-run=server -o yaml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationWorkflow").value(hasItem(".github/workflows/kubernetes-operations-report-sync-ci.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationWorkflowCommand").value(hasItem("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --from-file=latest-data-flow-query-retention-budget-evidence.json=.osmu-run/latest-data-flow-query-retention-budget-evidence.json --dry-run=client -o yaml | kubectl apply -f -")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationNote").value(hasItem("This script writes to Kubernetes only when -Apply is supplied. -ServerDryRunOnly talks to the API server without persisting changes. The default and -PlanOnly modes do not execute kubectl.")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.result").value("pending"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.summary").value("passed=82 pending=20"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.reportPath").value(".osmu-run/latest-operations-readiness.json"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.generatedAt").value("2026-06-27T00:00:00Z"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.passedCount").value(82));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.pendingCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.totalCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.checkCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.pendingCategorySummary").value("chargeback-closeout=1, commercial-approval=1, commercial-integration=1, data-flow=3, enterprise-auth=2, ha-dr=2, monitoring=1, operations-handoff-package=1, security-hardening=6, storage-backend=1, storage-expansion=1"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.pendingCategoryCounts[0].category").value("chargeback-closeout"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.pendingCategoryCounts[0].count").value(1));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.pendingRemediationCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.pendingRemediations[0].name").value("Kubernetes DR finalizer evidence"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.pendingRemediations[0].category").value("HA_DR"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.pendingRemediations[0].evidencePath").value(".osmu-run/latest-kubernetes-dr-finalize.json"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.pendingRemediations[0].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/finalize-kubernetes-dr-drill.ps1 -ConfirmRestore"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.pendingRemediations[0].workflowCommand").value("gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessSummary.decisionRule").value("Production/B2B operations readiness is ready only when every listed evidence check is PASS."));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.result").value("action-required"));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.sourceSummary").value("passed=82 pending=20"));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.sourcePassedCount").value(82));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.sourcePendingCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.sourceTotalCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.sourceCheckCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.sourcePendingRemediationCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.sourcePendingRemediationEntryCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.sourcePendingRemediationActionCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.sourcePendingRemediationMissingActionCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.sourcePendingRemediationCoverageReady").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.pendingCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actionCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.unplannedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.pendingCategorySummary").value("chargeback-closeout=1, commercial-approval=1, commercial-integration=1, data-flow=3, enterprise-auth=2, ha-dr=2, monitoring=1, operations-handoff-package=1, security-hardening=6, storage-backend=1, storage-expansion=1"));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.pendingCategoryCounts[0].category").value("chargeback-closeout"));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.pendingCategoryCounts[0].count").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actionSummary.totalActions").value(20));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actionSummary.kubernetesLiveActions").value(3));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actionSummary.securityCiActions").value(6));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actionSummary.operatorRemediationActions").value(11));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actionSummary.requiresOperatorApprovalCount").value(17));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actionSummary.requiresKubeconfigSecretCount").value(3));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actionSummary.actionsWithPlaceholdersCount").value(16));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actionSummary.unplannedCheckCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].workflowCommand").value("gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f manifest_path=./infra/k8s/examples/minio-tenant-pool-expansion.example.yaml -f impersonate_runner=true"));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].currentDetail").value("report not found"));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].recommendedCommand").value("gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f manifest_path=./infra/k8s/examples/minio-tenant-pool-expansion.example.yaml -f impersonate_runner=true"));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].dispatchUrl").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/storage-expansion-finalizer-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].operatorInputs").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].requiresOperatorApproval").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidencePlan.actions[0].requiresKubeconfigSecret").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.result").value("planned"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.sourceSummary").value("passed=82 pending=20"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.sourcePassedCount").value(82));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.sourcePendingCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.sourceTotalCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.sourceCheckCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.selectedActionCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.selectedActionOrders").value(hasItem(6)));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.plannedCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.blockedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.actions[0].status").value("planned"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.actions[0].command").value("gh workflow run container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.actions[0].blockReasons").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.actions[0].unresolvedPlaceholders").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsEvidenceInvocation.actions[0].invalidPlaceholders").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.result").value("ready"));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.sourceResult").value("planned"));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.sourcePassedCount").value(82));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.sourcePendingCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.sourceTotalCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.sourceCheckCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.selectedActionCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.blockedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.requiredPlaceholderCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.ambiguousRepeatedPlaceholderCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.confirmationGroupCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.requiredInputGroupCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.needsKubeconfigSecretConfirmation").value(false));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.needsOperatorApprovalConfirmation").value(false));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.blockedActionOrders").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.plannedActionOrders").value(hasItem(6)));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.confirmedPlanCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6"));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.confirmationGroups").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.requiredInputGroups").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.actions[0].status").value("planned"));
        readiness.andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.actions[0].planCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.result").value("action-required"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.sourceResult").value("ready"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.sourcePassedCount").value(82));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.sourcePendingCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.sourceTotalCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.sourceCheckCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.selectedActionCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.selectedActionOrders").value(hasItem(6)));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.readyActionCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.readyActionOrders[0]").value(6));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.blockedActionCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.blockedActionOrders").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.readySubsetPlanCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.readySubsetExecuteCommand").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredInputCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.missingInputCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.unsafeInputCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.invalidInputCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.failedCheckCount").value(2));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.warningCheckCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredGitHubSecrets").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.githubCliPath").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.githubCliAvailableForDispatch").value(false));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.githubRepository").value("chefbeom/object-storage-osmu"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.githubRef").value("main"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.defaultBranchRef").value("origin/main"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.githubApiTokenPresent").value(false));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.githubApiDispatchAvailable").value(false));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.githubApiDispatchUnavailableReasons[0]").value("GH_TOKEN or GITHUB_TOKEN is not set"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.gitRefSafety.status").value("action-required"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.gitRefSafety.aheadCount").value(25));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.gitRefSafety.githubRefLikelyContainsCommit").value(false));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.gitRefSafety.suggestedGitHubRef").value("codex/operations-readiness-a0730b64"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.gitRefSafety.suggestedPushCommand").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.gitRefSafety.note").value(containsString("Working tree has uncommitted changes")));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.readySubsetApiExecuteCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.apiExecuteCommand").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.workflowFiles[0].workflow").value("container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.workflowFiles[0].defaultBranchRef").value("origin/main"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.workflowFiles[0].existsOnDefaultBranch").value(true));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.workflowFiles[0].dispatchUrl").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.workflowFiles[0].requiredSecrets").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.checks[0].code").value("ACTION_SELECTION"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.checks[0].status").value("pass"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredInputs").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.inputTemplates[0].dispatchUrl").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.inputTemplates[0].readyToDispatch").value(true));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.inputTemplates[0].missingInputCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsDispatchPreflight.executeCommand").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.result").value("query-required"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.sourceSummary").value("passed=82 pending=20"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.sourcePassedCount").value(82));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.sourcePendingCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.sourceTotalCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.sourceCheckCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.selectedActionOrders").value(hasItem(6)));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.branch").value("main"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.githubRepository").value("chefbeom/object-storage-osmu"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.runListJsonDirectory").value(".\\.osmu-run\\workflow-run-lists"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.runListJsonDirectoryCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory .\\.osmu-run\\workflow-run-lists"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.githubApiRunListCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.runListJsonFilePattern").value("<workflow>.json"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.browserWorkflowRunsUrls[0]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.browserWorkflowRunsUrls[1]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflowRunIdInputs[0].workflow").value("container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflowRunIdInputs[0].runIdParameter").value("ContainerSecurityRunId"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflowRunIdInputs[0].runListJsonPath").value(".\\.osmu-run\\workflow-run-lists\\container-security-ci.yml.json"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflowRunIdInputs[0].queryCommand").value("gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflowRunIdInputs[0].sourceSelected").value(true));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflowRunIdInputs[0].supplementalForSecurityFinalizer").value(false));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[0].name").value("Collect run ids from saved run-list JSON"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[0].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory .\\.osmu-run\\workflow-run-lists"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[0].dispatchUrls[0]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[0].dispatchUrls[1]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[1].name").value("Collect workflow run ids with GitHub REST API"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[1].command").value(containsString("-UseGitHubApi")));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[1].dispatchUrls[0]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[1].dispatchUrls[1]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[3].name").value("Write artifact collection plan with browser run ids"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[3].command").value(containsString("-ContainerSecurityRunId <ContainerSecurityRunId>")));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[3].command").value(containsString("-ImageSigningRunId <ImageSigningRunId>")));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[3].dispatchUrls[0]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[3].dispatchUrls[1]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/image-publish-sign-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[3].note").value(containsString("ImageSigningRunId")));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.recommendedCommands[5].note").value(containsString("Missing run id inputs: ImageSigningRunId, ContainerSecurityRunId")));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerReady").value(false));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerRunIdInputs").value(hasItems("ImageSigningRunId", "ContainerSecurityRunId")));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerRunIdInputHints[0].runIdParameter").value("ImageSigningRunId"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerRunIdInputHints[0].workflow").value("image-publish-sign-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerRunIdInputHints[0].sourceSelected").value(false));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerRunIdInputHints[0].supplementalForSecurityFinalizer").value(true));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerRunIdInputHints[1].runIdParameter").value("ContainerSecurityRunId"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerRunIdInputHints[1].sourceSelected").value(true));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerRunIdInputHints[1].supplementalForSecurityFinalizer").value(false));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerMissingRunIdInputs").value(hasItems("ImageSigningRunId", "ContainerSecurityRunId")));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.securityEvidenceFinalizerDependencyNote").value(containsString("ImageSigningRunId")));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflowCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.githubApiTokenPresent").value(false));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.githubApiUnauthenticated").value(false));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.queryExecuted").value(false));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.queryExecutedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.queryWorkflowCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.querySucceededCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.queryErrorCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.candidateCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.missingWorkflowCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.artifactCollectionPlanCommand").value(containsString("write-operations-artifact-collection-plan.ps1")));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].workflow").value("container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].sourceActionCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].primaryActionOrder").value(6));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].primaryActionStatus").value("planned"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].actionOrders").value(hasItem(6)));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].actionStatuses").value(hasItem("planned")));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].queryCommand").value("gh run list --workflow container-security-ci.yml --branch main --limit 20 --json databaseId,workflowName,status,conclusion,createdAt,headSha,url,displayTitle"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].gitHubApiQueryUrl").value("https://api.github.com/repos/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml/runs?branch=main&event=workflow_dispatch&per_page=20"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].runListJsonFile").value("container-security-ci.yml.json"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].runListJsonPath").value(".\\.osmu-run\\workflow-run-lists\\container-security-ci.yml.json"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].runListJsonExists").value(false));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].runsUrl").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsWorkflowRunIdPlan.workflows[0].readyForArtifactDownload").value(false));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.result").value("security-source-action-required"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.invocationResult").value("planned"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.sourceSummary").value("passed=82 pending=20"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.sourcePassedCount").value(82));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.sourcePendingCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.sourceTotalCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.sourceCheckCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.selectedActionOrders").value(hasItem(6)));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifactCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.requiredArtifactCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.missingRequiredArtifactCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securitySourceArtifactCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.readySecuritySourceArtifactCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.missingSecuritySourceArtifactCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerReady").value(false));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerInputs[0].name").value("ImageSigningRunId"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerInputs[0].runIdParameter").value("image_signing_run_id"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerInputs[0].workflow").value("image-publish-sign-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerInputs[0].sourceArtifactSelected").value(false));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerInputs[1].name").value("ContainerSecurityRunId"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerInputs[1].runIdParameter").value("container_security_run_id"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerInputs[1].artifactName").value("osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerInputs[1].ready").value(false));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerInputs[1].sourceArtifactSelected").value(true));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerMissingRunIdInputs").value(hasItems("ImageSigningRunId", "ContainerSecurityRunId")));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.operationsArtifactFinalizerCommand").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.securityEvidenceFinalizerCommand").value(containsString("container_security_run_id")));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].group").value("container-security-source"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].workflow").value("container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].downloadCommand").value(containsString("osmu-container-security")));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].requiredForReadiness").value(false));
        readiness.andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].ready").value(false));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.status").value("artifact-import-failed"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.selectedGroupCount").value(2));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.importedCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.failedCount").value(2));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.outputDirectory").value(".osmu-run"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.secretPolicy").value("Artifact import copies only JSON/Markdown evidence files and does not read kubeconfig, registry tokens, DR secrets, or bearer tokens."));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.entries[0].group").value("ha-dr-readiness"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.entries[0].status").value("failed"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.entries[0].passed").value(false));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.entries[0].detail").value("result=failed expected=passed"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessArtifactImport.entries[1].destinationPath").value(".osmu-run/latest-iam-rbac-finalize.json"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.result").value("pending"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.status").value("operations-readiness-finalize-pending"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.readinessResult").value("pending"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.readinessSummary").value("passed=82 pending=20"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.namespace").value("osmu"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.powerShellCommand").value("pwsh"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.failedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.selectedSteps.storageExpansionFinalizer").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.paths.operationsReadinessJson").value(".osmu-run/latest-operations-readiness.json"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.paths.dataFlowStoragePlan").value(".osmu-run/latest-data-flow-storage-plan.json"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.paths.dataFlowStorageTransitionRunbookEvidence").value(".osmu-run/latest-data-flow-storage-transition-runbook-evidence.json"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.commands[0].name").value("Operations readiness report"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.commands[0].arguments").value(hasItem("-JsonOutputPath")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.commands[0].arguments").value(hasItem("-DataFlowStorageTransitionRunbookEvidencePath")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.steps[0].result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.gaps").value(hasItem("Operations readiness result is pending: passed=82 pending=20.")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessFinalize.secretPolicy").value("Operations readiness finalizer masks admin passwords in recorded commands and does not write kubeconfig, registry tokens, DR secrets, or bearer tokens."));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.environmentName").value("pilot-prod"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.targetCluster").value("customer-cluster-a"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operatorName").value("ops-admin"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.failureCount").value(2));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.plannedCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.checkCount").value(28));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.noSecretValues").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.runbookReviewed").value(false));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.secretRotationSnapshotReviewed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.commercialIntegrationSnapshotReviewed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.commercialApprovalSnapshotReviewed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.chargebackCloseoutSnapshotReviewed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.enterpriseAuthSmokeSnapshotReviewed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.monitoringThresholdReviewed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.evidenceRefs.commercialApproval").value("latest-commercial-approval-evidence-passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.evidenceRefs.chargebackCloseout").value("latest-chargeback-closeout-evidence-passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsReadinessSnapshot.result").value("ready"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsReadinessSnapshot.pendingCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncReady").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncSourceReportResult").value("ready"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerResult").value("ready"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerReadinessResult").value("ready"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerFailedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerFailedCountValid").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerFailedCountRaw").value("0"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerGapCountValid").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerGapCountRaw").value("0"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncReadyValid").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncReadyRaw").value("True"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncFailedCountValid").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.kubernetesReportSyncFailedCountRaw").value("0"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.finalizerGapCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.stageCount").value(6));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.handoffPostDispatchCommandCount").value(5));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.handoffPostDispatchCommands[0].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.handoffPostDispatchCommands[1].command").value(containsString("-UseGitHubApi")));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.operationsConvergenceSnapshot.handoffPostDispatchCommands[3].name").value("Regenerate artifact collection plan with browser run ids"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.candidateStore").value("MARIADB_PARTITION"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.candidateDecision.candidateStore").value("MARIADB_PARTITION"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.candidateDecision.queryPlanEvidencePassed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.candidateDecision.targetStoreEvidenceConfirmed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.expectedPeakEventsPerDay").value(250000));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.targetP95QueryLatencyMs").value(500));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.pendingCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.queryPlanEvidence.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStoragePlanSnapshot.queryPlanEvidence.failedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowQueryRetentionBudgetSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowQueryRetentionBudgetSnapshot.observedP95QueryLatencyMs").value(420));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowQueryRetentionBudgetSnapshot.retentionBudgetSeconds").value(30));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowQueryRetentionBudgetSnapshot.failureCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowQueryRetentionBudgetSnapshot.confirmations.noSecretValues").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.storagePlanResult").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.candidateStore").value("MARIADB_PARTITION"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.targetP95QueryLatencyMs").value(500));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.failureCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.confirmations.backfillRehearsed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot.confirmations.rollbackRehearsed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.secretRotationSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.secretRotationSnapshot.coreRotatedCount").value(5));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.secretRotationSnapshot.coreRequiredCount").value(5));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.secretRotationSnapshot.confirmations.smokePassed").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.commercialIntegrationSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.commercialIntegrationSnapshot.requiredVerifiedCount").value(8));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.commercialIntegrationSnapshot.paymentProviderAdapterReadinessStatus").value("WEBHOOK_PROFILE_READY"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.commercialApprovalSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.commercialApprovalSnapshot.productVersion").value("osmu-mvp-0.1"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.commercialApprovalSnapshot.pricingPolicyProposalApprovedPriceListCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.billingPeriod").value("2026-06"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.closeoutSnapshotValid").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.scanLimit").value(500));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.sourceTruncated").value(false));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.sourceComplete").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.truncationBlockerCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.closeoutReady").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.reconciliationDifferenceMinorUnits").value(0));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.finalInvoiceCount").value(3));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.paidInvoiceCount").value(3));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.noRawDataStored").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.rawCustomerPaymentDataStored").value(false));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.chargebackCloseoutSnapshot.paymentProviderAdapterReadinessStatus").value("WEBHOOK_PROFILE_READY"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthSmokeSnapshot.result").value("scope-out"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthSmokeSnapshot.executionMode").value("scope-out"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthSmokeSnapshot.scopeOut.accepted").value("true"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthSmokeSnapshot.skippedCount").value(6));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthJitRollbackSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthJitRollbackSnapshot.evidenceRef").value("enterprise-auth-jit-rollback-review-20260620"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthJitRollbackSnapshot.enterpriseAuthSmokeSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthJitRollbackSnapshot.enterpriseAuthSmokeSnapshot.passCount").value(8));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthJitRollbackSnapshot.confirmations.noRawClaims").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.enterpriseAuthJitRollbackSnapshot.failureCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.mappedAlertCount").value(11));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.requiredAlertCount").value(11));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.routeCount").value(3));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.routes[1]").value("osmu-data-flow"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.monitoringThresholdSnapshot.confirmations.noSecretValues").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.clusterNetworkAccessReviewSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.clusterNetworkAccessReviewSnapshot.operatorName").value("network-ops"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.clusterNetworkAccessReviewSnapshot.staticSnapshot.backendEgressScoped").value("true"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.clusterNetworkAccessReviewSnapshot.confirmations.noCredentialValues").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.helmValuesHardeningSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.helmValuesHardeningSnapshot.operatorName").value("helm-ops"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.helmValuesHardeningSnapshot.staticSnapshot.networkPolicyEnabled").value("true"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.helmValuesHardeningSnapshot.confirmations.noCredentialValues").value(true));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.checks[0].id").value("runbook-reviewed"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.checks[0].status").value("FAIL"));
        readiness.andExpect(jsonPath("$.data.operationsHandoffPackage.checks[1].evidenceRef").value("latest-commercial-integration-evidence-passed"));
        readiness.andExpect(jsonPath("$.data.storageExpansionFinalize.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.storageExpansionFinalize.namespace").value("pilot-osmu"));
        readiness.andExpect(jsonPath("$.data.storageExpansionFinalize.tenantName").value("osmu-minio"));
        readiness.andExpect(jsonPath("$.data.storageExpansionFinalize.runBackendDryRunRunner").value(true));
        readiness.andExpect(jsonPath("$.data.storageExpansionFinalize.runBackendApply").value(false));
        readiness.andExpect(jsonPath("$.data.storageExpansionFinalize.runStorageBackendTelemetry").value(false));
        readiness.andExpect(jsonPath("$.data.storageExpansionFinalize.failedCount").value(1));
        readiness.andExpect(jsonPath("$.data.storageExpansionFinalize.evidence.rbacAuth").value(".osmu-run/latest-storage-expansion-rbac-auth.json"));
        readiness.andExpect(jsonPath("$.data.storageExpansionFinalize.gaps[0]").value("Backend apply runner was not executed."));
        readiness.andExpect(jsonPath("$.data.storageExpansionFinalize.steps[0].result").value("failed"));
        readiness.andExpect(jsonPath("$.data.kubernetesHaDrReadiness.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.kubernetesHaDrReadiness.namespace").value("pilot-osmu"));
        readiness.andExpect(jsonPath("$.data.kubernetesHaDrReadiness.failureCount").value(1));
        readiness.andExpect(jsonPath("$.data.kubernetesHaDrReadiness.checks[1].name").value("pdb-osmu-minio-effective"));
        readiness.andExpect(jsonPath("$.data.kubernetesHaDrReadiness.checks[1].passed").value(false));
        readiness.andExpect(jsonPath("$.data.kubernetesDrFinalize.result").value("partial"));
        readiness.andExpect(jsonPath("$.data.kubernetesDrFinalize.status").value("kubernetes-dr-finalize-partial"));
        readiness.andExpect(jsonPath("$.data.kubernetesDrFinalize.sourceNamespace").value("pilot-osmu"));
        readiness.andExpect(jsonPath("$.data.kubernetesDrFinalize.restoreNamespace").value("pilot-osmu-restore"));
        readiness.andExpect(jsonPath("$.data.kubernetesDrFinalize.serverDryRunOnly").value(true));
        readiness.andExpect(jsonPath("$.data.kubernetesDrFinalize.confirmRestore").value(false));
        readiness.andExpect(jsonPath("$.data.kubernetesDrFinalize.commands[0].name").value("Kubernetes DR drill wrapper"));
        readiness.andExpect(jsonPath("$.data.kubernetesDrFinalize.steps[0].result").value("skipped"));
        readiness.andExpect(jsonPath("$.data.kubernetesDrFinalize.gaps[0]").value("Server-side dry-run only; no restore was executed."));
        readiness.andExpect(jsonPath("$.data.iamRbacEvidence.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.iamRbacEvidence.status").value("iam-rbac-finalize-failed"));
        readiness.andExpect(jsonPath("$.data.iamRbacEvidence.namespace").value("pilot-osmu"));
        readiness.andExpect(jsonPath("$.data.iamRbacEvidence.serviceAccount").value("osmu-storage-expansion-runner"));
        readiness.andExpect(jsonPath("$.data.iamRbacEvidence.runBackendPolicyTests").value(true));
        readiness.andExpect(jsonPath("$.data.iamRbacEvidence.runKubernetesLiveAuth").value(true));
        readiness.andExpect(jsonPath("$.data.iamRbacEvidence.failedCount").value(1));
        readiness.andExpect(jsonPath("$.data.iamRbacEvidence.gaps[0]").value("Storage expansion live RBAC auth failed with exit code 1."));
        readiness.andExpect(jsonPath("$.data.iamRbacEvidence.commands[0].name").value("IAM/RBAC matrix verifier"));
        readiness.andExpect(jsonPath("$.data.iamRbacEvidence.steps[1].result").value("failed"));
        readiness.andExpect(jsonPath("$.data.securityEvidence.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.securityEvidence.failureCount").value(1));
        readiness.andExpect(jsonPath("$.data.securityEvidence.inputs.imageSigningEvidence").value(".osmu-run/latest-image-signing-evidence.json"));
        readiness.andExpect(jsonPath("$.data.securityEvidence.source.containerSecurityArtifactName").value("osmu-container-security-abc123def456abc123def456abc123def456abcd"));
        readiness.andExpect(jsonPath("$.data.securityEvidence.images.backendDigest").value("sha256:1111111111111111111111111111111111111111111111111111111111111111"));
        readiness.andExpect(jsonPath("$.data.securityEvidence.checks[0].name").value("container security frontend scan"));
        readiness.andExpect(jsonPath("$.data.securityEvidence.imageSigning.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.securityEvidence.imageSigning.version").value("v0.1.0-rc.1"));
        readiness.andExpect(jsonPath("$.data.securityEvidence.imageSigning.backendVersionSignatureVerified").value(true));
        readiness.andExpect(jsonPath("$.data.securityEvidence.containerSecurity.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.securityEvidence.containerSecurity.frontendScanPassed").value(false));
        readiness.andExpect(jsonPath("$.data.securityEvidence.containerSecurity.backendSbomPackageCount").value(42));
        readiness.andExpect(jsonPath("$.data.securityEvidence.containerSecurity.frontendSbomSha256").value("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.environmentName").value("pilot-prod"));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.rotationWindow.startedAt").value("2026-06-20T00:00:00Z"));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.evidenceRefs.secretManagerAudit").value("vault-audit-run-20260620"));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.confirmations.noSecretValues").value(true));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.confirmations.smokePassed").value(false));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.coreRotatedCount").value(4));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.coreRequiredCount").value(5));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.failureCount").value(2));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.rotations[1].id").value("tls-certificate"));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.rotations[1].rotated").value(false));
        readiness.andExpect(jsonPath("$.data.secretRotationEvidence.checks[0].id").value("smoke-passed-confirmed"));
        readiness.andExpect(jsonPath("$.data.commercialIntegrationEvidence.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.commercialIntegrationEvidence.environmentName").value("pilot-prod"));
        readiness.andExpect(jsonPath("$.data.commercialIntegrationEvidence.requiredVerifiedCount").value(7));
        readiness.andExpect(jsonPath("$.data.commercialIntegrationEvidence.requiredCount").value(8));
        readiness.andExpect(jsonPath("$.data.commercialIntegrationEvidence.paymentProviderAdapterReadinessStatus").value("WEBHOOK_PROFILE_READY"));
        readiness.andExpect(jsonPath("$.data.commercialIntegrationEvidence.checks[0].id").value("integration-payment-erp"));
        readiness.andExpect(jsonPath("$.data.commercialApprovalEvidence.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.commercialApprovalEvidence.productVersion").value("osmu-mvp-0.1"));
        readiness.andExpect(jsonPath("$.data.commercialApprovalEvidence.confirmations.legalApproved").value(false));
        readiness.andExpect(jsonPath("$.data.commercialApprovalEvidence.evidenceRefs.pricingPolicyProposal").value("pricing-policy-proposal-price-list-approved-20260620"));
        readiness.andExpect(jsonPath("$.data.commercialApprovalEvidence.pricingPolicyProposalApprovedPriceListCount").value(1));
        readiness.andExpect(jsonPath("$.data.commercialApprovalEvidence.checks[0].id").value("legal-approval-confirmed"));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.result").value("planned"));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.executionMode").value("plan-only"));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.requireOidc").value(true));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.requireLdap").value(true));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.inputs.adminPasswordProvided").value(false));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.inputs.adminLoginId").doesNotExist());
        readiness.andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.scopeOut.accepted").value("false"));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.plannedCount").value(8));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthSmokeEvidence.checks[0].endpoint").value("GET /api/admin/security/enterprise-auth-plan"));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthJitRollbackEvidence.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthJitRollbackEvidence.environmentName").value("pilot-prod"));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthJitRollbackEvidence.reviewWindow.startedAt").value("2026-06-20T04:00:00Z"));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthJitRollbackEvidence.enterpriseAuthSmokeSnapshot.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthJitRollbackEvidence.enterpriseAuthSmokeSnapshot.passCount").value(8));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthJitRollbackEvidence.evidenceRefs.jitRollbackRunbook").value("jit-rollback-runbook-20260620"));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthJitRollbackEvidence.confirmations.localPasswordFallbackValidated").value(false));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthJitRollbackEvidence.failureCount").value(1));
        readiness.andExpect(jsonPath("$.data.enterpriseAuthJitRollbackEvidence.checks[0].id").value("local-password-fallback-confirmed"));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.sourceMode").value("cors-xml-path"));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.bucketName").value("uploads"));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.minioAlias").value("osmu-minio"));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.rawCorsXmlStored").value(false));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.ruleCount").value(1));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.exposedHeaderCount").value(2));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.failureCount").value(1));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.allowedMethods[1]").value("PUT"));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.exposeHeaders[0]").value("x-amz-request-id"));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.maxAgeSeconds[0]").value(3000));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.checks[0].id").value("expose-headers"));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.checks[0].passed").value(false));
        readiness.andExpect(jsonPath("$.data.minioBucketCorsVerification.operatorCommands.collectAndVerify").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\verify-minio-bucket-cors.ps1 -BucketName <bucket> -MinioAlias <alias> -Execute -FailIfNotPassed"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.result").value("plan-ready-execute-required"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.environmentName").value("pilot-prod"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.targetCluster").value("customer-cluster-a"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.operatorName").value("ops-admin"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.evidenceRef").value("data-flow-sizing-run-20260621"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.candidateStore").value("MARIADB_PARTITION"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.candidateDecision.candidateStore").value("MARIADB_PARTITION"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.candidateDecision.requiresMariaDbQueryEvidence").value(true));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.candidateDecision.requiresTargetStoreEvidence").value(false));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.candidateDecision.queryPlanEvidencePassed").value(false));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.candidateDecision.targetStoreEvidenceConfirmed").value(true));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.candidateDecision.safeDataPolicy", org.hamcrest.Matchers.containsString("raw EXPLAIN JSON")));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.expectedPeakEventsPerDay").value(250000));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.expectedQueryWindowDays").value(180));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.targetP95QueryLatencyMs").value(500));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.eventRetentionDays").value(90));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.dailyRollupRetentionDays").value(730));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.monthlyRollupRetentionMonths").value(36));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.checkCount").value(4));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.passedCount").value(2));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.pendingCount").value(2));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.checks[0].id").value("aggregate_no_object_keys"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.checks[1].id").value("target_query_latency_budget"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.checks[2].status").value("pending"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.checks[2].nextAction").value("Attach EXPLAIN evidence before enabling partitioned/time-series storage."));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.checks[3].id").value("mariadb_query_plan_evidence"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.queryPlanEvidence.provided").value(false));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.queryPlanEvidence.expectedFormatVersion").value("osmu.mariadb-query-plan-evidence.v1"));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.queryPlanEvidence.detail").value("No MariaDB query plan evidence JSON supplied."));
        readiness.andExpect(jsonPath("$.data.dataFlowStoragePlan.scopePolicy", org.hamcrest.Matchers.containsString("not AWS billing parity")));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.environmentName").value("pilot-prod"));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.storagePlanResult").value("passed"));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.candidateStore").value("MARIADB_PARTITION"));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.observedP95QueryLatencyMs").value(420));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.targetP95QueryLatencyMs").value(500));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.retentionBudgetSeconds").value(30));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.detailedRetentionObservedSeconds").value(31));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.retentionJobsWithinBudget").value(false));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.failureCount").value(1));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.topFailedChecks[0].id").value("retention-jobs-within-budget"));
        readiness.andExpect(jsonPath("$.data.dataFlowQueryRetentionBudget.scopePolicy", org.hamcrest.Matchers.containsString("not AWS billing parity")));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.environmentName").value("pilot-prod"));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.targetCluster").value("customer-cluster-a"));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.evidenceRef").value("data-flow-runbook-rehearsal-20260621"));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.storagePlanResult").value("plan-ready-execute-required"));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.candidateStore").value("MARIADB_PARTITION"));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.targetP95QueryLatencyMs").value(500));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.failureCount").value(2));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.checkCount").value(10));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.confirmations.dualWriteOrPartitionToggleReviewed").value(false));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.topFailedChecks[0].id").value("storage-plan-passed"));
        readiness.andExpect(jsonPath("$.data.dataFlowStorageTransitionRunbook.scopePolicy", org.hamcrest.Matchers.containsString("not AWS billing parity")));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.environmentName").value("pilot-prod"));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.targetCluster").value("customer-cluster-a"));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.sourceMode").value("admin-info-json-path"));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.minioAlias").value("osmu-minio"));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.rawAdminInfoStored").value(false));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.poolCount").value(1));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.serverCount").value(2));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.offlineServerCount").value(0));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.driveCount").value(4));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.totalBytes").value(4398046511104L));
        readiness.andExpect(jsonPath("$.data.storageBackendTelemetryEvidence.scopePolicy", org.hamcrest.Matchers.containsString("not AWS S3 parity work")));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.result").value("passed"));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.environmentName").value("pilot-prod"));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.targetCluster").value("customer-cluster-a"));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.evidenceRef").value("monitoring-threshold-run-20260621"));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.reviewWindow.startedAt").value("2026-06-21T08:40:00Z"));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.requiredAlertCount").value(11));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.mappedAlertCount").value(11));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.routeCount").value(3));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.routes[1]").value("osmu-data-flow"));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.grafanaPanelCount").value(11));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.tuningEvidenceCount").value(11));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.alertTargetCoverageComplete").value(true));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.routeCoverageComplete").value(true));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.grafanaPanelCoverageComplete").value(true));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.tuningEvidenceCoverageComplete").value(true));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.thresholdMappingComplete").value(true));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.evidenceRefs.incidentRouting").value("incident-routing-review-20260621"));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.confirmations.noSecretValues").value(true));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.failureCount").value(0));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.checkCount").value(24));
        readiness.andExpect(jsonPath("$.data.monitoringThresholdEvidence.checks[0].id").value("prometheus-rules-loaded-confirmed"));
        readiness.andExpect(jsonPath("$.data.clusterNetworkAccessReviewEvidence.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.clusterNetworkAccessReviewEvidence.operatorName").value("network-admin"));
        readiness.andExpect(jsonPath("$.data.clusterNetworkAccessReviewEvidence.evidence.dnsEgressReviewRef").value("dns-egress-review-20260624"));
        readiness.andExpect(jsonPath("$.data.clusterNetworkAccessReviewEvidence.staticSnapshot.networkPolicyManifestPath").value("infra/k8s/networkpolicy.yaml"));
        readiness.andExpect(jsonPath("$.data.clusterNetworkAccessReviewEvidence.staticSnapshot.dnsEgressScoped").value("false"));
        readiness.andExpect(jsonPath("$.data.clusterNetworkAccessReviewEvidence.confirmations.dnsEgressScoped").value(false));
        readiness.andExpect(jsonPath("$.data.clusterNetworkAccessReviewEvidence.failureCount").value(1));
        readiness.andExpect(jsonPath("$.data.clusterNetworkAccessReviewEvidence.totalCount").value(21));
        readiness.andExpect(jsonPath("$.data.clusterNetworkAccessReviewEvidence.checks[0].id").value("dns-egress-review-confirmed"));
        readiness.andExpect(jsonPath("$.data.clusterNetworkAccessReviewEvidence.secretPolicy", org.hamcrest.Matchers.containsString("kubeconfig")));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.operatorName").value("platform-admin"));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.evidence.clusterNetworkAccessReviewEvidenceRef").value("cluster-network-access-review-20260624"));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.staticSnapshot.chartDirectory").value("infra/helm/osmu"));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.staticSnapshot.chartFileCount").value("1"));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.staticSnapshot.tlsIngress").value("false"));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.confirmations.tlsIngressReviewed").value(false));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.failureCount").value(1));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.totalCount").value(19));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.checks[0].id").value("tls-ingress-confirmed"));
        readiness.andExpect(jsonPath("$.data.helmValuesHardeningEvidence.secretPolicy", org.hamcrest.Matchers.containsString("Production secret values")));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.result").value("failed"));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.environmentName").value("pilot-prod"));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.targetCluster").value("customer-cluster-a"));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.operatorName").value("support-admin"));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.reviewWindow.startedAt").value("2026-06-24T01:00:00Z"));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.evidence.supportSlaRef").value("support-sla-approval-20260624"));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.documentSnapshot.supportEscalationCoverage").value(true));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.confirmations.supportSlaReviewed").value(false));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.failureCount").value(1));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.totalCount").value(31));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.checks[0].id").value("support-sla-reviewed-confirmed"));
        readiness.andExpect(jsonPath("$.data.supportEscalationHandoffEvidence.secretPolicy", org.hamcrest.Matchers.containsString("support desk credentials")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_HANDOFF_PACKAGE')].evidencePath").value(hasItem(".osmu-run/latest-operations-handoff-package.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_HANDOFF_PACKAGE')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-handoff-package.ps1")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'STORAGE_EXPANSION_FINALIZE')].evidencePath").value(hasItem(".osmu-run/latest-storage-expansion-finalize.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'STORAGE_EXPANSION_FINALIZE')].remediationWorkflow").value(hasItem(".github/workflows/storage-expansion-finalizer-ci.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_HA_DR_READINESS')].evidencePath").value(hasItem(".osmu-run/latest-kubernetes-ha-dr-readiness.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_HA_DR_READINESS')].remediationWorkflow").value(hasItem(".github/workflows/kubernetes-ha-dr-readiness-ci.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_DR_FINALIZE')].evidencePath").value(hasItem(".osmu-run/latest-kubernetes-dr-finalize.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_DR_FINALIZE')].remediationWorkflow").value(hasItem(".github/workflows/kubernetes-dr-finalizer-ci.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'IAM_RBAC_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-iam-rbac-finalize.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'IAM_RBAC_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/iam-rbac-finalizer-ci.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'SECURITY_EVIDENCE_FINALIZE')].evidencePath").value(hasItem(".osmu-run/latest-security-evidence-finalize.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'SECURITY_EVIDENCE_FINALIZE')].remediationWorkflow").value(hasItem(".github/workflows/security-evidence-finalizer-ci.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'SECRET_ROTATION_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-secret-rotation-evidence.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'SECRET_ROTATION_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/manual-secret-rotation-evidence.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'COMMERCIAL_INTEGRATION_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-commercial-integration-evidence.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'COMMERCIAL_INTEGRATION_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/manual-commercial-integration-evidence.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'COMMERCIAL_APPROVAL_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-commercial-approval-evidence.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'COMMERCIAL_APPROVAL_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/manual-commercial-approval-evidence.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'ENTERPRISE_AUTH_SMOKE_EVIDENCE')].evidencePath").value(hasItem(".osmu-run/latest-enterprise-auth-smoke.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'ENTERPRISE_AUTH_SMOKE_EVIDENCE')].remediationWorkflow").value(hasItem(".github/workflows/enterprise-auth-smoke-ci.yml")));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.result").value("action-required"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.nextStep.code").value("dispatch-ready-subset-browser"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.nextStep.command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.nextStep.note").value("Run the ready subset plan command first without -Execute, then use the web dispatch URL(s) after operator review. Alternatively, set GH_TOKEN or GITHUB_TOKEN and run API dispatch: powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -Execute. GITHUB_CLI_AVAILABLE: GitHub CLI was not found on PATH. Web dispatch URL(s) for ready templates: action 6: https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml. Review failed preflight checks and operator approvals before using browser dispatch."));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.nextStep.dispatchUrls[0]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.currentBottleneck.code").value("dispatch-ready-subset-browser"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.currentBottleneck.dispatchUrls[0]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.dispatchGithubRepository").value("chefbeom/object-storage-osmu"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.requiredGitHubSecretCount").value(2));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.requiredGitHubSecrets[0]").value("KUBECONFIG_B64"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.requiredGitHubSecretSummaries[0].secretName").value("KUBECONFIG_B64"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.requiredGitHubSecretSummaries[0].inputFreeBlockedActionCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.requiredGitHubSecretSummaries[0].inputFreeBlockedActionOrders[0]").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readyDispatchTemplateCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.blockedDispatchTemplateCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readinessSummary").value("passed=82 pending=20"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readinessPassedCount").value(82));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readinessPendingCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readinessTotalCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readinessCheckCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.staleReportCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readyDispatchActionOrders[0]").value(6));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.blockedDispatchActionOrders").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.invocationSelectedActionOrders[0]").value(6));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.dispatchPreflightSelectedActionOrders[0]").value(6));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanActionOrders[0]").value(6));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.artifactCollectionActionOrders[0]").value(6));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.dispatchPreflightScopeMismatch").value(false));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanStale").value(false));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanScopeMismatch").value(false));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanQueryMode").value("github-api"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanGithubApiTokenPresent").value(false));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanGithubApiUnauthenticated").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanQueryExecuted").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanQueryExecutedCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanQueryWorkflowCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanQuerySucceededCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanQueryErrorCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.workflowRunIdPlanCandidateCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedReviewReportExists").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedReviewReportResult").value("blocked"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedReviewReportSelectedActionCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedReviewReportBlockedCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedReviewReportFailedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedReviewReportExecutedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedReviewReportActionOrders[0]").value(6));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedReviewReportStale").value(false));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedReviewReportScopeMismatch").value(false));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedActions[0].actionOrder").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedActions[0].name").value("Storage expansion finalizer live evidence"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedActions[0].blockReasons[0]").value("operator approval not confirmed"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedActions[0].requiredSecrets[0]").value("KUBECONFIG_B64"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedActions[0].needsOperatorApprovalConfirmation").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.inputFreeBlockedActions[0].needsKubeconfigSecretConfirmation").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesProfileReportPath").value(".\\.osmu-run\\latest-operations-operator-input-values-profile.json"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesProfileExists").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesProfileResult").value("action-required"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesProfileDefaultsUsed").value(false));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesProfileDefaultsSkipped").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesProfileDefaultsSkipReason").value("handoff package identity contains self-test marker"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesProfileDefaultValueCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesProfileFilledValueCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesProfileBlankValueCount").value(4));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesProfileCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-operator-input-values-profile.ps1 -WorksheetCsvPath .\\.osmu-run\\latest-operations-operator-input-worksheet.csv -EnvironmentName <env> -TargetCluster <cluster> -Operator <operator> -RunRef <run-ref> -ChangeApprovalRef <change-id> -StartTime <iso-start> -CompletedTime <iso-complete> -ApprovedAt <iso-approved>"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.operatorInputValuesCheckCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-operator-input-values-check.ps1 -ValuesCsvPath .\\.osmu-run\\latest-operations-operator-input-values-profile.csv"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.artifactCollectionStale").value(false));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.artifactCollectionScopeMismatch").value(false));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readyDispatchWorkflows[0].actionOrder").value(6));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readyDispatchWorkflows[0].workflow").value("container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readyDispatchWorkflows[0].dispatchUrl").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.readyDispatchWorkflows[0].name").value("Container scan/SBOM evidence"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.blockedDispatchWorkflows").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.blockedActionCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.missingWorkflowRunCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.missingRequiredArtifactCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.finalizerFailedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.finalizerGapCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.browserDispatchChecklistCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.browserDispatchChecklist[0].actionOrder").value(6));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.browserDispatchChecklist[0].workflow").value("container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.browserDispatchChecklist[0].runIdParameter").value("ContainerSecurityRunId"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.browserDispatchChecklist[0].artifactName").value("osmu-container-security-a0730b64636a22c38639b5f5c647f2e13792fc68"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.browserDispatchChecklist[0].steps[3]").value("Copy the numeric run id or full workflow run URL into ContainerSecurityRunId."));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.securityEvidenceFinalizerRunIdInputHintCount").value(2));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.securityEvidenceFinalizerRunIdInputHints[0].runIdParameter").value("ImageSigningRunId"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.securityEvidenceFinalizerRunIdInputHints[0].workflow").value("image-publish-sign-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.securityEvidenceFinalizerRunIdInputHints[0].supplementalForSecurityFinalizer").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.securityEvidenceFinalizerRunIdInputHints[1].runIdParameter").value("ContainerSecurityRunId"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.securityEvidenceFinalizerRunIdInputHints[1].sourceSelected").value(true));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.postDispatchCommands[0].name").value("Collect workflow run ids from saved run-list JSON"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.postDispatchCommands[0].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.postDispatchCommands[1].name").value("Collect workflow run ids with GitHub REST API"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.postDispatchCommands[1].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.postDispatchCommands[2].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -Execute"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.postDispatchCommands[3].name").value("Regenerate artifact collection plan with browser run ids"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.postDispatchCommands[3].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.postDispatchCommands[4].name").value("Regenerate artifact collection plan after run id collection"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.postDispatchCommands[4].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.stages[2].name").value("evidence-invocation"));
        readiness.andExpect(jsonPath("$.data.operationsEvidenceHandoff.stages[2].summary").value("selected=1 planned=1 blocked=0 failed=0"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.result").value("action-required"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffResult").value("action-required"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffStale").value(false));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffTimestampSource").value("generatedAt"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.readinessTimestampSource").value("generatedAt"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.readinessResult").value("pending"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.readinessSummary").value("passed=82 pending=20"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.readinessPassedCount").value(82));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.readinessPendingCount").value(20));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.readinessTotalCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.readinessCheckCount").value(102));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.finalizerExists").value(false));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.finalizerReadinessResult").doesNotExist());
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.currentBottleneck.code").value("dispatch-ready-subset-browser"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.currentBottleneck.command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 6"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.currentBottleneck.note").value(containsString("Web dispatch URL(s) for ready templates")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.currentBottleneck.note").value(containsString("ImageSigningRunId")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffBrowserDispatchDependencyNotes[0]").value(containsString("security-evidence-finalizer-ci.yml")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffSecurityEvidenceFinalizerRunIdInputHintCount").value(2));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffSecurityEvidenceFinalizerRunIdInputHints[0].runIdParameter").value("ImageSigningRunId"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffSecurityEvidenceFinalizerRunIdInputHints[0].supplementalForSecurityFinalizer").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffSecurityEvidenceFinalizerRunIdInputHints[1].runIdParameter").value("ContainerSecurityRunId"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffSecurityEvidenceFinalizerRunIdInputHints[1].sourceSelected").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffRequiredGitHubSecretCount").value(2));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffRequiredGitHubSecrets[0]").value("KUBECONFIG_B64"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffRequiredGitHubSecretSummaries[0].secretName").value("KUBECONFIG_B64"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffRequiredGitHubSecretSummaries[0].inputFreeBlockedActionOrders[0]").value(1));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffWorkflowRunIdPlanQueryMode").value("github-api"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffWorkflowRunIdPlanGithubApiTokenPresent").value(false));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffWorkflowRunIdPlanGithubApiUnauthenticated").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffWorkflowRunIdPlanQueryExecuted").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffWorkflowRunIdPlanQueryExecutedCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffWorkflowRunIdPlanQueryWorkflowCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffWorkflowRunIdPlanQuerySucceededCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffWorkflowRunIdPlanQueryErrorCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffWorkflowRunIdPlanCandidateCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffInputFreeBlockedReviewReportExists").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffInputFreeBlockedReviewReportResult").value("blocked"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffInputFreeBlockedReviewReportSelectedActionCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffInputFreeBlockedReviewReportBlockedCount").value(1));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffInputFreeBlockedReviewReportFailedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffInputFreeBlockedReviewReportExecutedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffInputFreeBlockedReviewReportActionOrders[0]").value(6));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffInputFreeBlockedReviewReportStale").value(false));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffInputFreeBlockedReviewReportScopeMismatch").value(false));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffOperatorInputValuesProfileReportPath").value(".\\.osmu-run\\latest-operations-operator-input-values-profile.json"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffOperatorInputValuesProfileExists").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffOperatorInputValuesProfileResult").value("action-required"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffOperatorInputValuesProfileDefaultsUsed").value(false));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffOperatorInputValuesProfileDefaultsSkipped").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffOperatorInputValuesProfileDefaultsSkipReason").value("handoff package identity contains self-test marker"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffOperatorInputValuesProfileDefaultValueCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffOperatorInputValuesProfileFilledValueCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffOperatorInputValuesProfileBlankValueCount").value(4));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.currentBottleneck.dispatchUrls[0]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.recommendedCommands[0].name").value("Open browser or API dispatch for ready subset"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.recommendedCommands[0].note").value(containsString("container-security-ci.yml")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.recommendedCommands[0].dispatchUrls[0]").value("https://github.com/chefbeom/object-storage-osmu/actions/workflows/container-security-ci.yml"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.recommendedCommands[3].name").value("Review workflow-run-ids"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.recommendedCommands[3].command").value(containsString("-UseGitHubApi")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffPostDispatchCommands[0].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -RunListJsonDirectory <run-list-json-dir>"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffPostDispatchCommands[1].name").value("Collect workflow run ids with GitHub REST API"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffPostDispatchCommands[1].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffPostDispatchCommands[3].name").value("Regenerate artifact collection plan with browser run ids"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffPostDispatchCommands[3].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ContainerSecurityRunId <ContainerSecurityRunId> -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffPostDispatchCommands[4].name").value("Regenerate artifact collection plan after run id collection"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.handoffPostDispatchCommands[4].command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1 -CommitSha a0730b64636a22c38639b5f5c647f2e13792fc68"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.stageCount").value(8));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.readyStageCount").value(2));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncExists").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncResult").value("planned"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncStale").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncTimestampSource").value("generatedAt"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncFreshnessReason").value(containsString("older than the latest")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncFailedCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.finalizerFailedCountValid").value(false));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.finalizerFailedCountRaw").value("<missing>"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncFailedCountValid").value(true));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncFailedCountRaw").value("0"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncConfigMapName").value("osmu-operations-reports"));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncWorkflowCommand").value(containsString("kubernetes-operations-report-sync-ci.yml")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncWorkflowCommand").value(containsString("data_flow_query_retention_budget_json_base64")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncWorkflowNote").value(containsString("query/retention budget and transition runbook evidence must be result=passed")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncWorkflowNote").value(containsString("Omit inputs")));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncReady").value(false));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.finalizerGapCount").value(0));
        readiness.andExpect(jsonPath("$.data.operationsReadinessConvergence.safetyPolicy").value("This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance."));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.result").value("planned"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.namespace").value("osmu"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.configMapName").value("osmu-operations-reports"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.sourceReportFormatVersion").value("osmu.operations-readiness-convergence.v1"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.sourceReportResult").value("action-required"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.sourceReportBytes").value(5249));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.sourceReportSha256").value("abc123"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookConfigMapKey").value("latest-data-flow-storage-transition-runbook-evidence.json"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowQueryRetentionBudgetConfigMapKey").value("latest-data-flow-query-retention-budget-evidence.json"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.publishDataFlowQueryRetentionBudgetToConfigMap").value(true));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowQueryRetentionBudgetResult").value("passed"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowQueryRetentionBudgetStoragePlanResult").value("passed"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowQueryRetentionBudgetCandidateStore").value("MARIADB_PARTITION"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs").value(500));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs").value(420));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowQueryRetentionBudgetRetentionBudgetSeconds").value(30));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowQueryRetentionBudgetFailureCount").value(0));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowQueryRetentionBudgetCheckCount").value(8));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.publishDataFlowStorageTransitionRunbookToConfigMap").value(true));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookResult").value("failed"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookStoragePlanResult").value("plan-ready-execute-required"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookCandidateStore").value("MARIADB_PARTITION"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookFailureCount").value(2));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookCheckCount").value(10));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.serverDryRunCommand").value("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --from-file=latest-data-flow-query-retention-budget-evidence.json=.osmu-run/latest-data-flow-query-retention-budget-evidence.json --dry-run=server -o yaml"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.applyCommand").value("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --from-file=latest-data-flow-storage-plan.json=.osmu-run/latest-data-flow-storage-plan.json --from-file=latest-data-flow-storage-transition-runbook-evidence.json=.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json --from-file=latest-data-flow-query-retention-budget-evidence.json=.osmu-run/latest-data-flow-query-retention-budget-evidence.json --dry-run=client -o yaml | kubectl apply -f -"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.checkCount").value(3));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.failedCount").value(0));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.checks[0].name").value("report-file-exists"));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.checks[0].passed").value(true));
        readiness.andExpect(jsonPath("$.data.kubernetesOperationsReportSync.safetyPolicy").value("This script writes to Kubernetes only when -Apply is supplied. -ServerDryRunOnly talks to the API server without persisting changes. The default and -PlanOnly modes do not execute kubectl."));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CHECK')].evidencePath").value(hasItem(".osmu-run/latest-kubernetes-dr-finalize.json")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CHECK')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/finalize-kubernetes-dr-drill.ps1 -ConfirmRestore")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CHECK')].remediationWorkflow").value(hasItem(".github/workflows/kubernetes-dr-finalizer-ci.yml")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CHECK')].remediationWorkflowCommand").value(hasItem("gh workflow run kubernetes-dr-finalizer-ci.yml -f run_live=true -f confirm_restore=true")));
        readiness.andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CHECK')].remediationNote").value(hasItem("Use confirmed restore evidence.")));
        readiness.andExpect(jsonPath("$.data.items[*].targetPanel").value(hasItem("dashboard-readiness-panel")));
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
                          "dataFlowQueryRetentionBudgetResult": "passed",
                          "dataFlowQueryRetentionBudgetStoragePlanResult": "passed",
                          "dataFlowQueryRetentionBudgetCandidateStore": "MARIADB_PARTITION",
                          "dataFlowQueryRetentionBudgetTargetP95QueryLatencyMs": 500,
                          "dataFlowQueryRetentionBudgetObservedP95QueryLatencyMs": 420,
                          "dataFlowQueryRetentionBudgetRetentionBudgetSeconds": 30,
                          "dataFlowQueryRetentionBudgetFailureCount": 0,
                          "dataFlowQueryRetentionBudgetCheckCount": 8,
                          "dataFlowQueryRetentionBudgetBytes": 1024,
                          "dataFlowQueryRetentionBudgetSha256": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
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
