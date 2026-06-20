package com.example.osmu.admin;

import static org.hamcrest.Matchers.hasItem;
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
                            "report": ".osmu-run/latest-operations-readiness-finalize.json",
                            "summary": ".osmu-run/latest-operations-readiness-finalize.md"
                          },
                          "commands": [
                            {
                              "name": "Operations readiness report",
                              "script": ".\\\\scripts\\\\write-operations-readiness.ps1",
                              "arguments": ["-JsonOutputPath", ".osmu-run/latest-operations-readiness.json"],
                              "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-readiness.ps1"
                            }
                          ],
                          "steps": [
                            {
                              "name": "Operations readiness report",
                              "script": ".\\\\scripts\\\\write-operations-readiness.ps1",
                              "arguments": ["-JsonOutputPath", ".osmu-run/latest-operations-readiness.json"],
                              "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-readiness.ps1",
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
                            "passedCount": 20,
                            "failureCount": 2,
                            "plannedCount": 1,
                            "checkCount": 23
                          },
                          "confirmations": {
                            "noSecretValues": true,
                            "runbookReviewed": false,
                            "troubleshootingReviewed": true,
                            "rollbackReviewed": true,
                            "supportEscalationReviewed": false,
                            "knownGapsAccepted": true,
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
                          "needsKubeconfigSecretConfirmation": true,
                          "needsOperatorApprovalConfirmation": true,
                          "requiredInputCount": 6,
                          "missingInputCount": 6,
                          "ambiguousInputCount": 2,
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
                          "requiredInputs": [
                            {
                              "actionOrder": 3,
                              "placeholder": "<YYYYMMDDTHHMMSSZ>",
                              "parameter": "BackupTimestamp",
                              "supplied": false,
                              "valuePreview": "",
                              "ambiguousRepeatedPlaceholder": false,
                              "note": "Provide a concrete value before planning or executing this action."
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
                            "code": "resolve-invocation-blockers",
                            "title": "Resolve invocation blockers",
                            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-invocation-unblock-plan.ps1",
                            "reason": "The invocation report still has blocked actions.",
                            "note": "Generate the unblock plan, fill placeholders, confirm operator approvals, and confirm kubeconfig-secret readiness before dispatch."
                          },
                          "stageCount": 7,
                          "readyStageCount": 1,
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
                          "kubernetesOperationsReportSyncReportPath": ".osmu-run/latest-kubernetes-operations-report-sync.json",
                          "kubernetesReportSyncExists": true,
                          "kubernetesReportSyncResult": "planned",
                          "kubernetesReportSyncFailedCount": 0,
                          "kubernetesReportSyncConfigMapName": "osmu-operations-reports",
                          "kubernetesReportSyncConfigMapKey": "latest-operations-readiness-convergence.json",
                          "kubernetesReportSyncSourceReportResult": "action-required",
                          "kubernetesReportSyncReady": false,
                          "finalizerGapCount": 1,
                          "stageCount": 7,
                          "readyStageCount": 1,
                          "blockedActionCount": 5,
                          "missingWorkflowRunCount": 6,
                          "missingRequiredArtifactCount": 5,
                          "failedImportCount": 0,
                          "currentBottleneck": {
                            "code": "resolve-invocation-blockers",
                            "title": "Resolve invocation blockers",
                            "reason": "The invocation report still has blocked actions.",
                            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-invocation-unblock-plan.ps1"
                          },
                          "recommendedCommands": [
                            {
                              "order": 1,
                              "name": "Resolve invocation blockers",
                              "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\\\scripts\\\\write-operations-invocation-unblock-plan.ps1",
                              "reason": "The invocation report still has blocked actions."
                            }
                          ],
                          "decisionRule": "Operations readiness convergence is ready only when the handoff result is ready/none, the readiness report is ready, and any finalizer report confirms readinessResult=ready.",
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
                          "sourceReportPath": ".osmu-run/latest-operations-readiness-convergence.json",
                          "sourceReportFormatVersion": "osmu.operations-readiness-convergence.v1",
                          "sourceReportResult": "action-required",
                          "sourceReportBytes": 5249,
                          "sourceReportSha256": "abc123",
                          "clientDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=client -o yaml",
                          "serverDryRunCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=server -o yaml",
                          "applyCommand": "kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=client -o yaml | kubectl apply -f -",
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
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_CONVERGENCE")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("KUBERNETES_OPERATIONS_REPORT_SYNC")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_CHECK")))
                .andExpect(jsonPath("$.data.items[*].code").value(hasItem("OPERATIONS_READINESS_ARTIFACT_IMPORT")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness remains pending: passed=36 pending=6.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations evidence plan is action-required: actionCount=6, unplannedCount=0.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations evidence invocation is blocked: selectedActionCount=6, plannedCount=1, blockedCount=5.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations invocation unblock plan is action-required: blockedActions=5, requiredPlaceholders=6, ambiguousPlaceholders=2.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations dispatch preflight is action-required: failedChecks=3, missingInputs=6, warnings=2.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations workflow run id plan is query-required: workflows=7, missingRuns=7.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations artifact collection plan is action-required: artifacts=7, missingRequired=5.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness finalizer is pending: readinessResult=pending, failedCount=0.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations evidence handoff is blocked: next=resolve-invocation-blockers, blockedActions=5, missingRuns=6, missingArtifacts=5, finalizerGaps=1.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Operations readiness convergence is action-required: bottleneck=resolve-invocation-blockers, stages=1/7, finalizerGaps=1.")))
                .andExpect(jsonPath("$.data.items[*].message").value(hasItem("Kubernetes operations report sync is planned: namespace=osmu, configMap=osmu-operations-reports, failedCount=0.")))
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
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_HANDOFF')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_EVIDENCE_HANDOFF')].remediationNote").value(hasItem("The invocation report still has blocked actions. Generate the unblock plan, fill placeholders, confirm operator approvals, and confirm kubeconfig-secret readiness before dispatch.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].evidencePath").value(hasItem(".osmu-run/latest-operations-readiness-artifact-import.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\import-operations-readiness-artifacts.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].remediationWorkflow").value(hasItem(".github/workflows/operations-readiness-artifact-finalizer-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_ARTIFACT_IMPORT')].remediationNote").value(hasItem("Artifact import copies only JSON/Markdown evidence files and does not read kubeconfig, registry tokens, DR secrets, or bearer tokens.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].evidencePath").value(hasItem(".osmu-run/latest-operations-readiness-finalize.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\finalize-operations-readiness.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].remediationWorkflow").value(hasItem(".github/workflows/operations-readiness-finalizer-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_FINALIZER')].remediationNote").value(hasItem("Operations readiness finalizer masks admin passwords in recorded commands and does not write kubeconfig, registry tokens, DR secrets, or bearer tokens.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CONVERGENCE')].evidencePath").value(hasItem(".osmu-run/latest-operations-readiness-convergence.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CONVERGENCE')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_READINESS_CONVERGENCE')].remediationNote").value(hasItem("The invocation report still has blocked actions. This convergence writer does not execute kubectl, gh, workflow dispatch, finalizer, or ConfigMap sync commands; it only reads local reports and writes JSON/Markdown guidance.")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].evidencePath").value(hasItem(".osmu-run/latest-kubernetes-operations-report-sync.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationCommand").value(hasItem("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=server -o yaml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationWorkflow").value(hasItem(".github/workflows/kubernetes-operations-report-sync-ci.yml")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'KUBERNETES_OPERATIONS_REPORT_SYNC')].remediationWorkflowCommand").value(hasItem("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=client -o yaml | kubectl apply -f -")))
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
                .andExpect(jsonPath("$.data.operationsInvocationUnblockPlan.actions[0].planCommand").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\invoke-operations-evidence-plan.ps1 -ActionOrder 1 -KubeconfigSecretConfirmed -ConfirmOperatorApproval -BackupTimestamp <YYYYMMDDTHHMMSSZ>"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.result").value("action-required"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.sourceResult").value("action-required"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.selectedActionCount").value(6))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.selectedActionOrders").value(hasItem(1)))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredInputCount").value(6))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.missingInputCount").value(6))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.failedCheckCount").value(3))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.warningCheckCount").value(2))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredGitHubSecrets").value(hasItem("OSMU_KUBECONFIG_BASE64")))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.workflowFiles[0].workflow").value("storage-expansion-finalizer-ci.yml"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.workflowFiles[0].requiredSecrets").value(hasItem("OSMU_ADMIN_PASSWORD")))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.checks[0].code").value("KUBECONFIG_SECRET_CONFIRMED"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.checks[0].status").value("fail"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredInputs[0].parameter").value("BackupTimestamp"))
                .andExpect(jsonPath("$.data.operationsDispatchPreflight.requiredInputs[0].supplied").value(false))
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
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].group").value("storage-expansion"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].downloadCommand").value("gh run download <storage-expansion-run-id> -n storage-expansion-finalizer-<storage-expansion-run-id> -D .osmu-run/operations-readiness-artifacts/storage-expansion"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].requiredForReadiness").value(true))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[0].ready").value(false))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[1].group").value("kubernetes-operations-report-sync"))
                .andExpect(jsonPath("$.data.operationsArtifactCollectionPlan.artifacts[1].downloadCommand").value("gh run download <kubernetes-operations-report-sync-run-id> -n kubernetes-operations-report-sync-<kubernetes-operations-report-sync-run-id> -D .osmu-run/operations-readiness-artifacts/kubernetes-operations-report-sync"))
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
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.commands[0].name").value("Operations readiness report"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.commands[0].arguments").value(hasItem("-JsonOutputPath")))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.steps[0].result").value("passed"))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.gaps").value(hasItem("Operations readiness result is pending: passed=36 pending=6.")))
                .andExpect(jsonPath("$.data.operationsReadinessFinalize.secretPolicy").value("Operations readiness finalizer masks admin passwords in recorded commands and does not write kubeconfig, registry tokens, DR secrets, or bearer tokens."))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.result").value("failed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.environmentName").value("pilot-prod"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.targetCluster").value("customer-cluster-a"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.operatorName").value("ops-admin"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.failureCount").value(2))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.plannedCount").value(1))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.checkCount").value(23))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.noSecretValues").value(true))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.confirmations.runbookReviewed").value(false))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.checks[0].id").value("runbook-reviewed"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.checks[0].status").value("FAIL"))
                .andExpect(jsonPath("$.data.operationsHandoffPackage.checks[1].evidenceRef").value("latest-commercial-integration-evidence-passed"))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_HANDOFF_PACKAGE')].evidencePath").value(hasItem(".osmu-run/latest-operations-handoff-package.json")))
                .andExpect(jsonPath("$.data.items[?(@.code == 'OPERATIONS_HANDOFF_PACKAGE')].remediationCommand").value(hasItem("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-handoff-package.ps1")))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.result").value("blocked"))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.nextStep.code").value("resolve-invocation-blockers"))
                .andExpect(jsonPath("$.data.operationsEvidenceHandoff.nextStep.command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1"))
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
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.currentBottleneck.code").value("resolve-invocation-blockers"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.currentBottleneck.command").value("powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\write-operations-invocation-unblock-plan.ps1"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.recommendedCommands[0].name").value("Resolve invocation blockers"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.stageCount").value(7))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.readyStageCount").value(1))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncExists").value(true))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncResult").value("planned"))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncFailedCount").value(0))
                .andExpect(jsonPath("$.data.operationsReadinessConvergence.kubernetesReportSyncConfigMapName").value("osmu-operations-reports"))
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
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.serverDryRunCommand").value("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=server -o yaml"))
                .andExpect(jsonPath("$.data.kubernetesOperationsReportSync.applyCommand").value("kubectl -n osmu create configmap osmu-operations-reports --from-file=latest-operations-readiness-convergence.json=.osmu-run/latest-operations-readiness-convergence.json --dry-run=client -o yaml | kubectl apply -f -"))
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
