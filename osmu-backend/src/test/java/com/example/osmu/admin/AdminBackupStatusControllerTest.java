package com.example.osmu.admin;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class AdminBackupStatusControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanReadBackupStatus() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/backup/status")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("DRILL_PENDING"))
                .andExpect(jsonPath("$.data.metadataStore").value("in-memory"))
                .andExpect(jsonPath("$.data.objectStore").value("in-memory"))
                .andExpect(jsonPath("$.data.databaseHealthy").value(true))
                .andExpect(jsonPath("$.data.storageHealthy").value(true))
                .andExpect(jsonPath("$.data.rpoTarget").value("24h"))
                .andExpect(jsonPath("$.data.rtoTarget").value("4h"))
                .andExpect(jsonPath("$.data.runbookAvailable").value(true))
                .andExpect(jsonPath("$.data.restoreDrillExecuted").value(false))
                .andExpect(jsonPath("$.data.latestRestoreDrillEvidence").doesNotExist())
                .andExpect(jsonPath("$.data.pendingGates").value(hasItem("MariaDB metadata mode is not enabled.")))
                .andExpect(jsonPath("$.data.pendingGates").value(hasItem("MinIO object storage mode is not enabled.")))
                .andExpect(jsonPath("$.data.pendingGates").value(hasItem("Successful restore drill evidence has not been recorded.")));
    }

    @Test
    void adminCanRecordBackupRestoreDrillEvidence() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        String manifestSha256 = "a".repeat(64);

        mockMvc.perform(post("/api/admin/backup/restore-drill-evidence")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "environment": "local-demo",
                                  "operator": "admin",
                                  "result": "SUCCESS",
                                  "startedAt": "2026-06-15T10:00:00+09:00",
                                  "completedAt": "2026-06-15T11:00:00+09:00",
                                  "backupTimestamp": "2026-06-15T00:00:00+09:00",
                                  "metadataRowCount": 42,
                                  "objectCount": 7,
                                  "objectBytes": 8192,
                                  "backupManifestSha256": "%s",
                                  "evidenceUri": "osmu-run/backup-drills/local-demo-20260615.json",
                                  "gaps": []
                                }
                                """.formatted(manifestSha256)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.environment").value("local-demo"))
                .andExpect(jsonPath("$.data.result").value("SUCCESS"))
                .andExpect(jsonPath("$.data.restoreDurationMinutes").value(60))
                .andExpect(jsonPath("$.data.observedRpoHours").value(11))
                .andExpect(jsonPath("$.data.rpoTargetMet").value(true))
                .andExpect(jsonPath("$.data.rtoTargetMet").value(true))
                .andExpect(jsonPath("$.data.statusImpact").value("READY_GATE_SATISFIED"));

        mockMvc.perform(get("/api/admin/backup/status")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.restoreDrillExecuted").value(true))
                .andExpect(jsonPath("$.data.lastRestoreDrillAt").exists())
                .andExpect(jsonPath("$.data.latestRestoreDrillEvidence.environment").value("local-demo"))
                .andExpect(jsonPath("$.data.latestRestoreDrillEvidence.result").value("SUCCESS"))
                .andExpect(jsonPath("$.data.latestRestoreDrillEvidence.metadataRowCount").value(42))
                .andExpect(jsonPath("$.data.latestRestoreDrillEvidence.objectCount").value(7))
                .andExpect(jsonPath("$.data.latestRestoreDrillEvidence.evidenceUri").value("osmu-run/backup-drills/local-demo-20260615.json"))
                .andExpect(jsonPath("$.data.pendingGates").value(not(hasItem("Successful restore drill evidence has not been recorded."))));

        mockMvc.perform(get("/api/admin/backup/restore-drill-evidence")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("result", "SUCCESS")
                        .param("limit", "5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].environment").value("local-demo"))
                .andExpect(jsonPath("$.items[0].result").value("SUCCESS"))
                .andExpect(jsonPath("$.items[0].metadataRowCount").value(42))
                .andExpect(jsonPath("$.items[0].objectBytes").value(8192))
                .andExpect(jsonPath("$.items[0].backupManifestSha256").value(manifestSha256))
                .andExpect(jsonPath("$.items[0].evidenceUri").value("osmu-run/backup-drills/local-demo-20260615.json"));
    }

    @Test
    void backupRestoreDrillEvidenceRejectsSecretLookingValues() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/admin/backup/restore-drill-evidence")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "environment": "local-demo",
                                  "operator": "admin",
                                  "result": "SUCCESS",
                                  "startedAt": "2026-06-15T10:00:00+09:00",
                                  "completedAt": "2026-06-15T11:00:00+09:00",
                                  "backupTimestamp": "2026-06-15T00:00:00+09:00",
                                  "metadataRowCount": 42,
                                  "objectCount": 7,
                                  "objectBytes": 8192,
                                  "evidenceUri": "password=qwer1234"
                                }
                                """))
                .andExpect(status().isBadRequest());
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
