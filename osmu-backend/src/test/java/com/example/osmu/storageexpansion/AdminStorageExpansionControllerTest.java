package com.example.osmu.storageexpansion;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class AdminStorageExpansionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanPlanAndApproveStorageExpansionRequest() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/storage-expansion/runner-preflight")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("DISABLED"))
                .andExpect(jsonPath("$.data.ready").value(false))
                .andExpect(jsonPath("$.data.enabledRunnerCount").value(0))
                .andExpect(jsonPath("$.data.failedCheckCount").value(0))
                .andExpect(jsonPath("$.data.checks[*].id", hasItem("dry-run")))
                .andExpect(jsonPath("$.data.checks[*].id", hasItem("apply")))
                .andExpect(jsonPath("$.data.checks[*].id", hasItem("rollback")))
                .andExpect(jsonPath("$.data.checks[*].id", hasItem("gitops-pr")))
                .andExpect(jsonPath("$.data.checks[*].remediation", hasItem(org.hamcrest.Matchers.containsString("Set OSMU_STORAGE_EXPANSION_RUNNER_ENABLED=true"))))
                .andExpect(jsonPath("$.data.checks[*].remediation", hasItem(org.hamcrest.Matchers.containsString("OSMU_STORAGE_EXPANSION_GITOPS_REPOSITORY_PATH"))))
                .andExpect(jsonPath("$.data.checks[*].status", hasItem("DISABLED")));

        mockMvc.perform(get("/api/admin/storage-expansion/execution-log-retention/status")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.enabled").value(true))
                .andExpect(jsonPath("$.data.retentionDays").value(90))
                .andExpect(jsonPath("$.data.batchSize").value(100))
                .andExpect(jsonPath("$.data.pendingOutputCount").exists());

        mockMvc.perform(post("/api/admin/storage-expansion/execution-log-retention/run")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.redactedOutputCount").exists())
                .andExpect(jsonPath("$.data.status.enabled").value(true));

        String response = mockMvc.perform(post("/api/admin/storage-expansion/requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "requestedCapacityBytes": 107374182400,
                                  "serverCount": 4,
                                  "volumesPerServer": 1,
                                  "reason": "media archive growth"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.poolName").value("pool-1"))
                .andExpect(jsonPath("$.data.requestedCapacityBytes").value(107374182400L))
                .andExpect(jsonPath("$.data.serverCount").value(4))
                .andExpect(jsonPath("$.data.volumesPerServer").value(1))
                .andExpect(jsonPath("$.data.volumeSizeBytes").value(53687091200L))
                .andExpect(jsonPath("$.data.estimatedRawCapacityBytes").value(214748364800L))
                .andExpect(jsonPath("$.data.estimatedUsableCapacityBytes").value(107374182400L))
                .andExpect(jsonPath("$.data.status").value("PLANNED"))
                .andExpect(jsonPath("$.data.reason").value("media archive growth"))
                .andExpect(jsonPath("$.data.createdBy").value("admin"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        int requestId = JsonPath.read(response, "$.data.id");

        mockMvc.perform(get("/api/admin/storage-expansion/requests")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].id", hasItem(requestId)))
                .andExpect(jsonPath("$.items[*].status", hasItem("PLANNED")));

        mockMvc.perform(get("/api/admin/storage-expansion/summary")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestCount").value(1))
                .andExpect(jsonPath("$.data.openRequestCount").value(1))
                .andExpect(jsonPath("$.data.plannedRequestCount").value(1))
                .andExpect(jsonPath("$.data.approvedRequestCount").value(0))
                .andExpect(jsonPath("$.data.totalRequestedCapacityBytes").value(107374182400L))
                .andExpect(jsonPath("$.data.openRequestedCapacityBytes").value(107374182400L))
                .andExpect(jsonPath("$.data.executionCount").value(0))
                .andExpect(jsonPath("$.data.latestRequest.id").value(requestId))
                .andExpect(jsonPath("$.data.recentExecutions").isArray())
                .andExpect(jsonPath("$.data.recentExecutions").isEmpty());

        mockMvc.perform(get("/api/admin/storage-expansion/requests/{requestId}/manifest", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestId").value(requestId))
                .andExpect(jsonPath("$.data.poolName").value("pool-1"))
                .andExpect(jsonPath("$.data.referenceOnly").value(true))
                .andExpect(jsonPath("$.data.tenantPatchYaml").value(org.hamcrest.Matchers.containsString("kind: Tenant")))
                .andExpect(jsonPath("$.data.tenantPatchYaml").value(org.hamcrest.Matchers.containsString("servers: 4")))
                .andExpect(jsonPath("$.data.tenantPatchYaml").value(org.hamcrest.Matchers.containsString("storage: 50Gi")))
                .andExpect(jsonPath("$.data.helmValuesPatchYaml").value(org.hamcrest.Matchers.containsString("minio:")))
                .andExpect(jsonPath("$.data.helmValuesPatchYaml").value(org.hamcrest.Matchers.containsString("enabled: true")))
                .andExpect(jsonPath("$.data.helmValuesPatchYaml").value(org.hamcrest.Matchers.containsString("size: 50Gi")));

        mockMvc.perform(get("/api/admin/storage-expansion/requests/{requestId}/manifest/tenant", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.containsString("osmu-storage-expansion-pool-1-tenant.yaml")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("kind: Tenant")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("storage: 50Gi")));

        mockMvc.perform(get("/api/admin/storage-expansion/requests/{requestId}/manifest/helm", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.containsString("osmu-storage-expansion-pool-1-helm-values.yaml")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("minio:")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("size: 50Gi")));

        mockMvc.perform(get("/api/admin/storage-expansion/requests/{requestId}/manifest/bundle", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("OSMU storage expansion manifest bundle")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("kind: Tenant")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("size: 50Gi")));

        mockMvc.perform(get("/api/admin/storage-expansion/requests/{requestId}/manifest/script", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/execution-plan", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/dry-run-execution", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "executionType": "KUBECTL_DIFF",
                                  "result": "SUCCESS",
                                  "output": "server-side diff clean"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/dry-run-runner", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "executionType": "KUBECTL_DIFF"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/apply-runner", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "applyType": "KUBECTL_APPLY"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/rollback-runner", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "rollbackType": "HELM_ROLLBACK"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/gitops-plan", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/gitops-pr-execution", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "externalUrl": "https://git.example/osmu/pull/42"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/gitops-pr-runner", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());

        mockMvc.perform(get("/api/admin/storage-expansion/requests/{requestId}/gitops-artifacts/bundle", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/executions", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "executionType": "HELM_DIFF",
                                  "result": "SUCCESS"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(patch("/api/admin/storage-expansion/requests/{requestId}/status", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "APPLIED",
                                  "appliedEvidence": "direct apply should fail"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(patch("/api/admin/storage-expansion/requests/{requestId}/status", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "APPROVED"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(requestId))
                .andExpect(jsonPath("$.data.status").value("APPROVED"));

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/execution-plan", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestId").value(requestId))
                .andExpect(jsonPath("$.data.poolName").value("pool-1"))
                .andExpect(jsonPath("$.data.ready").value(true))
                .andExpect(jsonPath("$.data.referenceOnly").value(true))
                .andExpect(jsonPath("$.data.artifactSha256").value(org.hamcrest.Matchers.matchesPattern("[0-9a-f]{64}")))
                .andExpect(jsonPath("$.data.evidenceTemplate").value(org.hamcrest.Matchers.containsString("sha256:")))
                .andExpect(jsonPath("$.data.preflightChecks[*]", hasItem(org.hamcrest.Matchers.containsString("StorageClass"))))
                .andExpect(jsonPath("$.data.suggestedCommands[*]", hasItem(org.hamcrest.Matchers.containsString("kubectl"))))
                .andExpect(jsonPath("$.data.suggestedCommands[*]", hasItem(org.hamcrest.Matchers.containsString("helm diff"))))
                .andExpect(jsonPath("$.data.suggestedCommands[*]", hasItem(org.hamcrest.Matchers.containsString("helm upgrade"))));

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/dry-run-runner", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "executionType": "KUBECTL_DIFF"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestId").value(requestId))
                .andExpect(jsonPath("$.data.executionType").value("KUBECTL_DIFF"))
                .andExpect(jsonPath("$.data.result").value("SKIPPED"))
                .andExpect(jsonPath("$.data.command").value(org.hamcrest.Matchers.containsString("kubectl")))
                .andExpect(jsonPath("$.data.output").value(org.hamcrest.Matchers.containsString("runner disabled")))
                .andExpect(jsonPath("$.data.artifactSha256").value(org.hamcrest.Matchers.matchesPattern("[0-9a-f]{64}")))
                .andExpect(jsonPath("$.data.timedOut").value(false))
                .andExpect(jsonPath("$.data.notes").value(org.hamcrest.Matchers.containsString("runner=SKIPPED")));

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/apply-runner", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "applyType": "KUBECTL_APPLY"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.execution.requestId").value(requestId))
                .andExpect(jsonPath("$.data.execution.executionType").value("APPLY"))
                .andExpect(jsonPath("$.data.execution.result").value("SKIPPED"))
                .andExpect(jsonPath("$.data.execution.command").value(org.hamcrest.Matchers.containsString("kubectl")))
                .andExpect(jsonPath("$.data.execution.output").value(org.hamcrest.Matchers.containsString("apply runner disabled")))
                .andExpect(jsonPath("$.data.execution.artifactSha256").value(org.hamcrest.Matchers.matchesPattern("[0-9a-f]{64}")))
                .andExpect(jsonPath("$.data.execution.timedOut").value(false))
                .andExpect(jsonPath("$.data.execution.notes").value(org.hamcrest.Matchers.containsString("applyType=KUBECTL_APPLY")))
                .andExpect(jsonPath("$.data.request.id").value(requestId))
                .andExpect(jsonPath("$.data.request.status").value("APPROVED"));

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/dry-run-execution", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "executionType": "APPLY",
                                  "result": "SUCCESS",
                                  "output": "should fail"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/dry-run-execution", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "executionType": "KUBECTL_DIFF",
                                  "result": "SUCCESS",
                                  "output": "server-side diff clean",
                                  "externalUrl": "https://ci.example/osmu/storage-expansion/pool-1/dry-run",
                                  "notes": "operator checked diff"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestId").value(requestId))
                .andExpect(jsonPath("$.data.executionType").value("KUBECTL_DIFF"))
                .andExpect(jsonPath("$.data.result").value("SUCCESS"))
                .andExpect(jsonPath("$.data.command").value(org.hamcrest.Matchers.containsString("kubectl -n osmu diff")))
                .andExpect(jsonPath("$.data.output").value(org.hamcrest.Matchers.containsString("server-side diff clean")))
                .andExpect(jsonPath("$.data.output").value(org.hamcrest.Matchers.containsString("Artifact sha256")))
                .andExpect(jsonPath("$.data.externalUrl").value("https://ci.example/osmu/storage-expansion/pool-1/dry-run"))
                .andExpect(jsonPath("$.data.artifactSha256").value(org.hamcrest.Matchers.matchesPattern("[0-9a-f]{64}")))
                .andExpect(jsonPath("$.data.timedOut").value(false))
                .andExpect(jsonPath("$.data.createdBy").value("admin"));

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/gitops-plan", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestId").value(requestId))
                .andExpect(jsonPath("$.data.poolName").value("pool-1"))
                .andExpect(jsonPath("$.data.ready").value(true))
                .andExpect(jsonPath("$.data.referenceOnly").value(true))
                .andExpect(jsonPath("$.data.branchName").value("storage-expansion/pool-1"))
                .andExpect(jsonPath("$.data.commitMessage").value(org.hamcrest.Matchers.containsString("[Feat][I]")))
                .andExpect(jsonPath("$.data.pullRequestTitle").value(org.hamcrest.Matchers.containsString("pool-1")))
                .andExpect(jsonPath("$.data.pullRequestBody").value(org.hamcrest.Matchers.containsString("sha256")))
                .andExpect(jsonPath("$.data.manifestPath").value("infra/gitops/storage-expansion/pool-1/tenant-patch.yaml"))
                .andExpect(jsonPath("$.data.valuesPath").value("infra/gitops/storage-expansion/pool-1/helm-values.yaml"))
                .andExpect(jsonPath("$.data.artifactSha256").value(org.hamcrest.Matchers.matchesPattern("[0-9a-f]{64}")))
                .andExpect(jsonPath("$.data.changedFiles[*]", hasItem("infra/gitops/storage-expansion/pool-1/tenant-patch.yaml")))
                .andExpect(jsonPath("$.data.changedFiles[*]", hasItem("infra/gitops/storage-expansion/pool-1/helm-values.yaml")))
                .andExpect(jsonPath("$.data.reviewChecklist[*]", hasItem(org.hamcrest.Matchers.containsString("helm diff"))));

        byte[] gitOpsBundle = mockMvc.perform(get("/api/admin/storage-expansion/requests/{requestId}/gitops-artifacts/bundle", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.parseMediaType("application/zip")))
                .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.containsString("osmu-storage-expansion-pool-1-gitops.zip")))
                .andReturn()
                .getResponse()
                .getContentAsByteArray();
        Set<String> gitOpsEntries = zipEntryNames(gitOpsBundle);
        assertTrue(gitOpsEntries.contains("infra/gitops/storage-expansion/pool-1/tenant-patch.yaml"));
        assertTrue(gitOpsEntries.contains("infra/gitops/storage-expansion/pool-1/helm-values.yaml"));
        assertTrue(gitOpsEntries.contains("infra/gitops/storage-expansion/pool-1/README.md"));

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/gitops-pr-runner", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestId").value(requestId))
                .andExpect(jsonPath("$.data.executionType").value("GITOPS_PR"))
                .andExpect(jsonPath("$.data.result").value("SKIPPED"))
                .andExpect(jsonPath("$.data.command").value(org.hamcrest.Matchers.containsString("gh pr create")))
                .andExpect(jsonPath("$.data.output").value(org.hamcrest.Matchers.containsString("GitOps PR runner disabled")))
                .andExpect(jsonPath("$.data.artifactSha256").value(org.hamcrest.Matchers.matchesPattern("[0-9a-f]{64}")))
                .andExpect(jsonPath("$.data.timedOut").value(false))
                .andExpect(jsonPath("$.data.failureReason").value(org.hamcrest.Matchers.nullValue()))
                .andExpect(jsonPath("$.data.notes").value(org.hamcrest.Matchers.containsString("gitOpsPrRunner=SKIPPED")));

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/gitops-pr-execution", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "externalUrl": "not-a-url"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/gitops-pr-execution", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "externalUrl": "https://git.example/osmu/pull/42",
                                  "mergeSha": "abcdef1234567890",
                                  "pipelineUrl": "https://ci.example/osmu/storage-expansion/pool-1",
                                  "notes": "ready for operator merge"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestId").value(requestId))
                .andExpect(jsonPath("$.data.executionType").value("GITOPS_PR"))
                .andExpect(jsonPath("$.data.result").value("SUCCESS"))
                .andExpect(jsonPath("$.data.command").value(org.hamcrest.Matchers.containsString("gh pr create")))
                .andExpect(jsonPath("$.data.output").value(org.hamcrest.Matchers.containsString("tenant-patch.yaml")))
                .andExpect(jsonPath("$.data.externalUrl").value("https://git.example/osmu/pull/42"))
                .andExpect(jsonPath("$.data.artifactSha256").value(org.hamcrest.Matchers.matchesPattern("[0-9a-f]{64}")))
                .andExpect(jsonPath("$.data.notes").value(org.hamcrest.Matchers.containsString("abcdef1234567890")))
                .andExpect(jsonPath("$.data.notes").value(org.hamcrest.Matchers.containsString("https://ci.example/osmu/storage-expansion/pool-1")))
                .andExpect(jsonPath("$.data.createdBy").value("admin"));

        String helmDiffExecutionResponse = mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/executions", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "executionType": "HELM_DIFF",
                                  "result": "SUCCESS",
                                  "command": "helm diff upgrade osmu-minio ./infra/helm/osmu -f helm-values.yaml",
                                  "output": "No drift detected",
                                  "externalUrl": "https://git.example/osmu/pull/42",
                                  "artifactSha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                                  "notes": "operator approved dry-run"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestId").value(requestId))
                .andExpect(jsonPath("$.data.executionType").value("HELM_DIFF"))
                .andExpect(jsonPath("$.data.result").value("SUCCESS"))
                .andExpect(jsonPath("$.data.command").value(org.hamcrest.Matchers.containsString("helm diff")))
                .andExpect(jsonPath("$.data.output").value("No drift detected"))
                .andExpect(jsonPath("$.data.externalUrl").value("https://git.example/osmu/pull/42"))
                .andExpect(jsonPath("$.data.artifactSha256").value("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
                .andExpect(jsonPath("$.data.createdBy").value("admin"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        int helmDiffExecutionId = JsonPath.read(helmDiffExecutionResponse, "$.data.id");

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/executions", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "executionType": "KUBECTL_DIFF",
                                  "result": "FAILED",
                                  "command": "kubectl diff --token=raw-command-token",
                                  "output": "OSMU_STORAGE_SECRET_KEY=raw-output-secret\\nAuthorization: Bearer raw-bearer-token",
                                  "notes": "accessKey=raw-note-key"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.command").value(org.hamcrest.Matchers.containsString("--token=[masked]")))
                .andExpect(jsonPath("$.data.command").value(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("raw-command-token"))))
                .andExpect(jsonPath("$.data.output").value(org.hamcrest.Matchers.containsString("OSMU_STORAGE_SECRET_KEY=[masked]")))
                .andExpect(jsonPath("$.data.output").value(org.hamcrest.Matchers.containsString("Authorization: Bearer [masked]")))
                .andExpect(jsonPath("$.data.output").value(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("raw-output-secret"))))
                .andExpect(jsonPath("$.data.output").value(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("raw-bearer-token"))))
                .andExpect(jsonPath("$.data.notes").value(org.hamcrest.Matchers.containsString("accessKey=[masked]")))
                .andExpect(jsonPath("$.data.notes").value(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("raw-note-key"))));

        mockMvc.perform(get("/api/admin/storage-expansion/requests/{requestId}/executions", requestId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].executionType", hasItem("HELM_DIFF")))
                .andExpect(jsonPath("$.items[*].executionType", hasItem("KUBECTL_DIFF")))
                .andExpect(jsonPath("$.items[*].executionType", hasItem("GITOPS_PR")))
                .andExpect(jsonPath("$.items[*].executionType", hasItem("APPLY")))
                .andExpect(jsonPath("$.items[*].result", hasItem("SKIPPED")))
                .andExpect(jsonPath("$.items[*].result", hasItem("SUCCESS")))
                .andExpect(jsonPath("$.items[*].externalUrl", hasItem("https://git.example/osmu/pull/42")));

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/executions", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "executionType": "SHELL",
                                  "result": "SUCCESS"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/executions/{executionId}/apply", requestId, helmDiffExecutionId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());

        mockMvc.perform(patch("/api/admin/storage-expansion/requests/{requestId}/status", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "APPLIED"
                                }
                """))
                .andExpect(status().isBadRequest());

        String applyExecutionResponse = mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/executions", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "executionType": "APPLY",
                                  "result": "SUCCESS",
                                  "command": "helm upgrade osmu-minio --values pool-1.yaml",
                                  "externalUrl": "https://ci.example/osmu/storage-expansion/pool-1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.executionType").value("APPLY"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        int applyExecutionId = JsonPath.read(applyExecutionResponse, "$.data.id");

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/executions/{executionId}/apply", requestId, applyExecutionId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(requestId))
                .andExpect(jsonPath("$.data.status").value("APPLIED"))
                .andExpect(jsonPath("$.data.appliedBy").value("admin"))
                .andExpect(jsonPath("$.data.appliedEvidence").value(org.hamcrest.Matchers.containsString("execution APPLY")))
                .andExpect(jsonPath("$.data.appliedEvidence").value(org.hamcrest.Matchers.containsString("https://ci.example/osmu/storage-expansion/pool-1")));

        mockMvc.perform(post("/api/admin/storage-expansion/requests/{requestId}/rollback-runner", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "rollbackType": "HELM_ROLLBACK",
                                  "helmRevision": 1
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.execution.requestId").value(requestId))
                .andExpect(jsonPath("$.data.execution.executionType").value("ROLLBACK"))
                .andExpect(jsonPath("$.data.execution.result").value("SKIPPED"))
                .andExpect(jsonPath("$.data.execution.command").value(org.hamcrest.Matchers.containsString("helm rollback")))
                .andExpect(jsonPath("$.data.execution.output").value(org.hamcrest.Matchers.containsString("rollback runner disabled")))
                .andExpect(jsonPath("$.data.execution.artifactSha256").value(org.hamcrest.Matchers.matchesPattern("[0-9a-f]{64}")))
                .andExpect(jsonPath("$.data.execution.timedOut").value(false))
                .andExpect(jsonPath("$.data.execution.notes").value(org.hamcrest.Matchers.containsString("rollbackType=HELM_ROLLBACK")))
                .andExpect(jsonPath("$.data.request.id").value(requestId))
                .andExpect(jsonPath("$.data.request.status").value("APPLIED"));

        mockMvc.perform(get("/api/admin/storage-expansion/summary")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requestCount").value(1))
                .andExpect(jsonPath("$.data.openRequestCount").value(0))
                .andExpect(jsonPath("$.data.appliedRequestCount").value(1))
                .andExpect(jsonPath("$.data.rejectedRequestCount").value(0))
                .andExpect(jsonPath("$.data.openRequestedCapacityBytes").value(0))
                .andExpect(jsonPath("$.data.totalEstimatedUsableCapacityBytes").value(107374182400L))
                .andExpect(jsonPath("$.data.executionCount").value(9))
                .andExpect(jsonPath("$.data.successExecutionCount").value(4))
                .andExpect(jsonPath("$.data.failedExecutionCount").value(1))
                .andExpect(jsonPath("$.data.skippedExecutionCount").value(4))
                .andExpect(jsonPath("$.data.timedOutExecutionCount").value(0))
                .andExpect(jsonPath("$.data.latestRequest.status").value("APPLIED"))
                .andExpect(jsonPath("$.data.latestExecution.executionType").value("ROLLBACK"))
                .andExpect(jsonPath("$.data.recentExecutions[0].executionType").value("ROLLBACK"))
                .andExpect(jsonPath("$.data.recentExecutions[*].result", hasItem("SKIPPED")));

        mockMvc.perform(patch("/api/admin/storage-expansion/requests/{requestId}/status", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "RUNNING"
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/admin/storage-expansion/requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "requestedCapacityBytes": 0
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + token)
                        .param("targetType", "STORAGE_EXPANSION_REQUEST")
                        .param("targetId", String.valueOf(requestId))
                        .param("limit", "20"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_REQUEST_CREATE")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_REQUEST_MANIFEST")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_REQUEST_MANIFEST_DOWNLOAD")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_REQUEST_EXECUTION_PLAN")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_DRY_RUN_EXECUTION")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_DRY_RUN_RUNNER")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_APPLY_RUNNER")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_ROLLBACK_RUNNER")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_REQUEST_GITOPS_PLAN")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_REQUEST_GITOPS_ARTIFACT_DOWNLOAD")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_GITOPS_PR_EXECUTION")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_EXECUTION_RECORD_CREATE")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_EXECUTION_APPLY")))
                .andExpect(jsonPath("$.items[*].eventType", hasItem("STORAGE_EXPANSION_REQUEST_STATUS")));
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

    private Set<String> zipEntryNames(byte[] content) throws Exception {
        Set<String> entries = new HashSet<>();
        try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(content), StandardCharsets.UTF_8)) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                entries.add(entry.getName());
            }
        }
        return entries;
    }
}
