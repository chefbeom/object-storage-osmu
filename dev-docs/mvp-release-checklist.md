# OSMU MVP v0.1 Release Checklist

This checklist turns the current prototype evidence into a repeatable MVP release decision.

## Release Target

- Product: OSMU private object storage prototype.
- Version target: MVP v0.1.
- Current candidate type: durable local MVP demo candidate.
- Durable pilot status: local durable gate/readiness evidence is ready from `.osmu-run/latest-durable-demo-gate.json` and `.osmu-run/latest-demo-readiness.json`; GitHub-hosted and production/B2B evidence remain separate gates.
- Latest completion status: run `scripts/verify-mvp-completion.ps1` without `-FailIfLocalMvpNotReady` for the current status report; because the latest durable finalizer path is plan-only, `-FailIfLocalMvpNotReady` is reserved for the post-Docker-ready finalizer hard gate.

## Current Evidence Snapshot

- Latest release report: `.osmu-run/latest-release.json`
- Latest audit report: `.osmu-run/latest-mvp-audit.md`
- Latest decision report: `.osmu-run/latest-release-decision.md`
- Latest release notes: `.osmu-run/latest-release-notes.md`
- Latest demo package notes: `.osmu-run/latest-demo-package-notes.md`
- Latest MVP completion report: `.osmu-run/latest-mvp-completion.json` and `.osmu-run/latest-mvp-completion.md`
- Latest operations readiness report: `.osmu-run/latest-operations-readiness.json` and `.osmu-run/latest-operations-readiness.md`
- Current operations bottleneck: `confirm-input-free-blockers`; confirm input-free blocked actions, fill required inputs, confirm operator/kubeconfig readiness, then dispatch the selected operations evidence workflows.
- MVP completion latest verification: result=pending, classification=local-durable-mvp-pending, localDurableMvpReady=false.
- Durable preflight latest handoff: result=pending, blockingActions=Docker daemon/Selected real S3 client path, nextAction=Start Docker Desktop and wait until docker info succeeds, then rerun durable preflight.
- Operations readiness latest verification: result=pending, passed=83, pending=19, total=102.
- Operations readiness pending categories: chargeback-closeout=1, commercial-approval=1, commercial-integration=1, data-flow=3, enterprise-auth=2, ha-dr=2, monitoring=1, operations-handoff-package=1, security-hardening=5, storage-backend=1, storage-expansion=1.
- Operations readiness pending remediation entries: 19.
- Operations evidence plan remediation coverage: source=19, entries=19, actions=19, missing=0, ready=true.
- Operations workflow run-id latest verification: result=query-required, selectedActions=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19, missingWorkflowCount=19.
- Operations workflow run-id security finalizer hints: count=2, inputs=ImageSigningRunId/ContainerSecurityRunId, supplemental=ContainerSecurityRunId.
- Operations artifact collection latest verification: result=action-required, selectedActions=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19, securityEvidenceFinalizerReady=false, securityFinalizerInputRows=2, missingSecurityFinalizerInputs=ImageSigningRunId/ContainerSecurityRunId.
- Operations evidence handoff latest verification: result=blocked, bottleneck=confirm-input-free-blockers, missingWorkflowRunCount=19.
- Operations evidence handoff run-id query: mode=plan-only, executed=false, executedWorkflows=0, succeeded=19/19, errors=0, candidates=0.
- Operations evidence handoff input-free review: exists=true, result=blocked, actionOrders=1,2,5, selected=3, blocked=3, stale=false, scopeMismatch=false.
- Operations evidence handoff browser dispatch checklist: count=0, actionOrders=none, workflows=none, runIdParameters=none.
- Operations readiness convergence latest verification: result=action-required, readinessResult=pending, bottleneck=confirm-input-free-blockers, missingWorkflowRunCount=19, kubernetesReportSyncStale=false.
- Operations readiness convergence run-id query: mode=github-api, executed=true, executedWorkflows=19, succeeded=19/19, errors=0, candidates=0.
- Operations readiness convergence input-free review: exists=true, result=blocked, actionOrders=1,2,5, selected=3, blocked=3, stale=false, scopeMismatch=false.
- Latest operations evidence plan: `.osmu-run/latest-operations-evidence-plan.json` and `.osmu-run/latest-operations-evidence-plan.md`
- Latest operations evidence plan invocation: `.osmu-run/latest-operations-evidence-plan-invocation.json` and `.osmu-run/latest-operations-evidence-plan-invocation.md`
- Latest operations invocation unblock plan: `.osmu-run/latest-operations-invocation-unblock-plan.json` and `.osmu-run/latest-operations-invocation-unblock-plan.md`
- Latest operations dispatch preflight: `.osmu-run/latest-operations-dispatch-preflight.json` and `.osmu-run/latest-operations-dispatch-preflight.md`
- Latest operations workflow run-id plan: `.osmu-run/latest-operations-workflow-run-ids.json` and `.osmu-run/latest-operations-workflow-run-ids.md`
- Latest operations artifact collection plan: `.osmu-run/latest-operations-artifact-collection-plan.json` and `.osmu-run/latest-operations-artifact-collection-plan.md`
- Latest operations readiness finalizer report: `.osmu-run/latest-operations-readiness-finalize.json` and `.osmu-run/latest-operations-readiness-finalize.md`
- Latest operations readiness artifact import report: `.osmu-run/latest-operations-readiness-artifact-import.json` and `.osmu-run/latest-operations-readiness-artifact-import.md`
- Latest operations evidence handoff report: `.osmu-run/latest-operations-evidence-handoff.json` and `.osmu-run/latest-operations-evidence-handoff.md`
- Latest operations readiness convergence report: `.osmu-run/latest-operations-readiness-convergence.json` and `.osmu-run/latest-operations-readiness-convergence.md`
- Latest Kubernetes operations report sync evidence: `.osmu-run/latest-kubernetes-operations-report-sync.json`
- Latest IAM/RBAC finalizer report: `.osmu-run/latest-iam-rbac-finalize.json` and `.osmu-run/latest-iam-rbac-finalize.md`
- Latest storage expansion finalizer report: `.osmu-run/latest-storage-expansion-finalize.json` when live Kubernetes expansion evidence has been collected.
- Latest storage backend telemetry evidence: `.osmu-run/latest-storage-backend-telemetry.json` when target MinIO `mc admin info --json` pool/node evidence has been summarized by the local writer, storage expansion finalizer, or `.github/workflows/manual-storage-backend-telemetry-evidence.yml`.
- Latest data-flow query/retention budget evidence: `.osmu-run/latest-data-flow-query-retention-budget-evidence.json` and `.md` when target p95 query latency and retention dry-run durations have been captured by `scripts/write-data-flow-query-retention-budget-evidence.ps1`.
- Latest enterprise auth JIT rollback evidence: `.osmu-run/latest-enterprise-auth-jit-rollback-evidence.json` and `.md` when admin-approved JIT rollback/runbook evidence has been captured by `scripts/write-enterprise-auth-jit-rollback-evidence.ps1`.
- Latest chargeback closeout evidence: `.osmu-run/latest-chargeback-closeout-evidence.json` and `.md` when target billing period pricing, usage, invoice, payment handoff, notification, retry, reconciliation, commercial integration, and commercial approval references have been captured by `scripts/write-chargeback-closeout-evidence.ps1`.
- Latest cluster network access review evidence: `.osmu-run/latest-cluster-network-access-review-evidence.json` and `.md` when Kubernetes/Helm NetworkPolicy hashes, access review references, and operator confirmations have been captured by `scripts/write-cluster-network-access-review-evidence.ps1` or `.github/workflows/manual-cluster-network-access-review-evidence.yml`.
- Latest Helm values hardening evidence: `.osmu-run/latest-helm-values-hardening-evidence.json` and `.md` when externalized secrets, HA/resource/security/network/TLS/read-only mount, and storage expansion RBAC defaults have been captured by `scripts/write-helm-values-hardening-evidence.ps1` or `.github/workflows/manual-helm-values-hardening-evidence.yml`.
- Latest support escalation handoff evidence: `.osmu-run/latest-support-escalation-handoff-evidence.json` and `.md` when runbook, troubleshooting, rollback, support escalation, support SLA, known-gap, and operations handoff package references have been reviewed by `scripts/write-support-escalation-handoff-evidence.ps1` or `.github/workflows/manual-support-escalation-handoff-evidence.yml`.
- Latest Kubernetes DR finalizer report: `.osmu-run/latest-kubernetes-dr-finalize.json` when live Kubernetes DR evidence has been collected.
- Latest security evidence finalizer report: `.osmu-run/latest-security-evidence-finalize.json` when signed image and container scan/SBOM CI evidence has been collected and promoted.
- Latest durable demo gate report: `.osmu-run/latest-durable-demo-gate.json`
- Latest demo readiness report: `.osmu-run/latest-demo-readiness.json`
- Latest current-machine demo readiness: `docker-durable-demo-verified` on 2026-06-15 22:12 KST.
- Latest known release gate: passed on 2026-06-14 05:14 KST.
- CI workflow draft: `.github/workflows/prototype-ci.yml` verified, release report `scope.ciWorkflow=included`.
- Durable Docker CI workflow draft: `.github/workflows/durable-docker-ci.yml` verified. The manual workflow runs `finalize-durable-mvp-demo.ps1 -EnableRealMultipartEvidence`, uploads durable reports/release artifacts/finalize/readiness reports plus browser multipart resume evidence JSON/Markdown, and release report records `scope.durableDockerCiWorkflow=included`.
- Real S3 client CI workflow draft: `.github/workflows/real-s3-client-ci.yml` verified, release report `scope.realS3ClientCiWorkflow=included`.
- Container security CI workflow draft: `.github/workflows/container-security-ci.yml` verified, release report `scope.containerSecurityCiWorkflow=included`.
- Browser E2E CI workflow draft: `.github/workflows/browser-e2e-ci.yml` verified, release report `scope.browserE2ECiWorkflow=included`.
- Storage Expansion Finalizer CI workflow draft: `.github/workflows/storage-expansion-finalizer-ci.yml` verified. The manual workflow runs the finalizer in plan-only mode by default and can collect live Kubernetes evidence only when `run_live=true` and `OSMU_KUBECONFIG_BASE64` is provided.
- Kubernetes HA/DR Readiness CI workflow draft: `.github/workflows/kubernetes-ha-dr-readiness-ci.yml` verified. The manual workflow runs the readiness checker in plan-only mode by default and can collect live target-cluster HA/DR evidence only when `run_live=true` and `OSMU_KUBECONFIG_BASE64` is provided.
- Kubernetes DR Finalizer CI workflow draft: `.github/workflows/kubernetes-dr-finalizer-ci.yml` verified. The manual workflow runs the DR finalizer in plan-only mode by default, supports server-side dry-run live evidence, and requires explicit `confirm_restore=true` before a confirmed restore or evidence submit path can run.
- Kubernetes Operations Report Sync CI workflow draft: `.github/workflows/kubernetes-operations-report-sync-ci.yml` verified. The manual workflow writes the convergence report, can restore optional base64-encoded data-flow storage plan evidence into `.osmu-run/latest-data-flow-storage-plan.json`, optional data-flow query/retention budget evidence into `.osmu-run/latest-data-flow-query-retention-budget-evidence.json`, and optional data-flow storage transition runbook evidence into `.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json`, rejects MariaDB partition/dual-write plan input that omits the sanitized query-plan evidence summary or contains raw SQL/raw EXPLAIN/credential-shaped content, rejects query/retention budget input that is not `result=passed`, is outside typed query/retention budget booleans, lacks typed confirmations, or contains raw SQL/raw EXPLAIN/object keys/raw event messages/credential-shaped content, rejects runbook input that is not `result=passed`, lacks typed boolean confirmations, or contains raw SQL/raw EXPLAIN/object keys/raw event messages/credential-shaped content, emits ConfigMap sync plan evidence by default, uses `OSMU_KUBECONFIG_BASE64` only when `run_live=true`, and requires `apply=true` before it updates `osmu-operations-reports`.
- Operations Readiness Finalizer CI workflow draft: `.github/workflows/operations-readiness-finalizer-ci.yml` verified. The manual workflow plans or runs the selected storage expansion, HA/DR, DR, IAM/RBAC, and security evidence finalizers, can restore optional `data_flow_storage_plan_json_base64`, `data_flow_query_retention_budget_json_base64`, and `data_flow_storage_transition_runbook_json_base64` inputs through the same sanitized evidence validation path, then uploads the combined readiness artifact set.
- Operations Readiness Artifact Finalizer CI workflow draft: `.github/workflows/operations-readiness-artifact-finalizer-ci.yml` verified. The manual workflow downloads previous evidence artifacts by run id and artifact name, including manual storage backend telemetry, manual data-flow storage plan, manual data-flow query/retention budget, manual data-flow storage transition runbook, manual secret rotation, manual cluster network access review, manual Helm values hardening, manual commercial integration, manual commercial approval, manual chargeback closeout, enterprise auth smoke, manual enterprise auth JIT rollback, manual support escalation handoff, manual operations handoff package, and optional Kubernetes operations report sync evidence, imports only passing evidence to standard latest paths after typed handoff snapshot validation, writes operations readiness, and uploads the combined artifact set.
- IAM/RBAC Finalizer CI workflow draft: `.github/workflows/iam-rbac-finalizer-ci.yml` verified. The manual workflow runs static IAM/RBAC finalizer evidence, can add focused backend RBAC tests with Java 17, and collects live `kubectl auth can-i` evidence only when `run_live=true` and `OSMU_KUBECONFIG_BASE64` is provided.
- Security Evidence Finalizer CI workflow draft: `.github/workflows/security-evidence-finalizer-ci.yml` verified. The manual workflow downloads successful image signing and container security artifacts from previous workflow runs, promotes them through `scripts/finalize-security-evidence.ps1`, and uploads the finalized evidence bundle.
- Image signing policy/workflow draft: `dev-docs/image-signing-policy.md` and `.github/workflows/image-publish-sign-ci.yml` verified, release report `scope.imageSigningPolicy=included`.
- Release notes generation: `.osmu-run/latest-release-notes.md` generated, release report `scope.releaseNotes=included`.
- Demo package notes generation: `.osmu-run/latest-demo-package-notes.md` generated by `scripts/write-mvp-demo-package-notes.ps1`, preserving local durable evidence paths, pilot attachment checklist, and the S3 replacement-use boundary.
- Commercial readiness draft: `dev-docs/commercial-readiness.md` verified, release report `scope.commercialReadiness=included`.
- OpenAPI MVP contract: current local verifier reports 199 operations and 152 frontend API functions checked.
- Kubernetes manifest draft: `infra/k8s` verified, release report `scope.kubernetesManifests=included`.
- Helm chart draft: `infra/helm/osmu` verified, release report `scope.helmChart=included`.
- Deployment resource profiles: backend, frontend, MariaDB, and MinIO requests/limits verified through Kubernetes and Helm checks.
- Kubernetes HA safety rails: backend/frontend two-replica defaults, topology spread constraints, and PodDisruptionBudget drafts are covered by Kubernetes/Helm static verification.
- Kubernetes HA/DR live evidence path: `scripts/verify-kubernetes-ha-dr-readiness.ps1` can record target-cluster Deployment, StatefulSet, PDB, backup PVC/CronJob, and restore Job server-side dry-run evidence.
- Kubernetes HA/DR Readiness CI uploads `.osmu-run/latest-kubernetes-ha-dr-readiness.json` as `kubernetes-ha-dr-readiness-<run_id>` when live evidence is collected.
- Kubernetes backup drill evidence path: `scripts/run-kubernetes-backup-drill.ps1` can create one-off Jobs from the MariaDB/MinIO backup CronJobs and record completion/log evidence.
- Kubernetes restore target preparation evidence path: `scripts/prepare-kubernetes-restore-namespace.ps1` can dry-run or apply a disposable restore namespace and verify core resources without reading secret values.
- Kubernetes backup artifact preflight evidence path: `scripts/verify-kubernetes-backup-artifacts.ps1` can run a read-only Job to verify `metadata.sql`, optional checksum, and MinIO mirror count/bytes before restore.
- Kubernetes isolated restore drill evidence path: `scripts/run-kubernetes-restore-drill.ps1` can validate the restore Job with `-ServerDryRunOnly` and execute it only in an explicitly confirmed restore namespace.
- Kubernetes DR drill orchestration evidence path: `scripts/run-kubernetes-dr-drill.ps1` can run the ordered backup/restore validation or confirmed restore sequence and write a wrapper evidence report.
- Kubernetes DR bucket bootstrap evidence path: `scripts/bootstrap-kubernetes-dr-bucket.ps1` can create or reuse the external DR bucket with object locking, enable versioning, set default retention, verify the result, and write `.osmu-run/latest-kubernetes-dr-bucket-bootstrap.json`.
- Kubernetes DR bucket immutability evidence path: `scripts/verify-kubernetes-dr-bucket-immutability.ps1` can verify external DR bucket reachability, versioning, and default object-lock retention through `osmu-dr-transfer-secret` and write `.osmu-run/latest-kubernetes-dr-bucket-immutability.json`.
- Kubernetes backup artifact transfer evidence path: `scripts/transfer-kubernetes-backup-artifacts.ps1` can export/import a selected timestamp through external S3-compatible DR storage using `osmu-dr-transfer-secret` and write `.osmu-run/latest-kubernetes-backup-artifact-transfer.json`.
- Kubernetes restore smoke evidence path: `scripts/verify-kubernetes-restore-smoke.ps1` can verify restored API health/login/bucket/object access plus optional real S3 client smoke and write `.osmu-run/latest-kubernetes-restore-smoke.json`.
- Kubernetes DR evidence API request path: `scripts/write-kubernetes-dr-evidence-request.ps1` can convert wrapper/artifact evidence into `.osmu-run/latest-kubernetes-dr-evidence-request.json` and optionally submit it to `POST /api/admin/backup/restore-drill-evidence`.
- Kubernetes DR finalize evidence path: `scripts/finalize-kubernetes-dr-drill.ps1` can run the DR wrapper, restore smoke, and evidence request sequence in one operator command and write `.osmu-run/latest-kubernetes-dr-finalize.json` plus `.md`. It accepts `-PowerShellCommand` for Linux CI runners and records the selected command in the evidence report.
- Kubernetes storage expansion finalize evidence path: `scripts/finalize-storage-expansion.ps1` can run storage expansion runner RBAC authorization evidence, MinIO Tenant server-side dry-run evidence, optional backend dry-run/apply runner calls, and optional storage backend telemetry evidence recording in one operator command. The apply path requires explicit `-RunBackendApply -ConfirmApply`, refuses to run if RBAC/server-side dry-run evidence is skipped in the same command, records the selected PowerShell command, and writes `.osmu-run/latest-storage-expansion-finalize.json` plus `.md`.
- Storage Expansion Finalizer CI uploads `.osmu-run/latest-storage-expansion-finalize.*`, RBAC auth evidence, server-side dry-run evidence, and optional `.osmu-run/latest-storage-backend-telemetry.*` as `storage-expansion-finalizer-<run_id>` artifacts for operator review.
- Kubernetes DR Finalizer CI uploads `.osmu-run/latest-kubernetes-dr-finalize.*`, DR drill, restore smoke, evidence request, backup drill, restore namespace, artifact preflight, restore drill, DR bucket, immutability, and artifact transfer evidence as `kubernetes-dr-finalizer-<run_id>` artifacts for operator review.
- MVP audit, release decision, and release notes read `.osmu-run/latest-storage-expansion-finalize.json` and `.osmu-run/latest-kubernetes-dr-finalize.json`, then mark storage expansion and Kubernetes DR finalizer evidence as PASS or PENDING without changing the lightweight/durable MVP demo decision.
- Operations readiness gate: `scripts/write-operations-readiness.ps1` writes a separate production/B2B operations readiness report. It stays `pending` until IAM/RBAC finalizer, storage expansion finalizer, storage backend telemetry target evidence, data-flow storage transition target evidence, Kubernetes HA/DR readiness, Kubernetes DR finalizer, signed image, container scan/SBOM, secret/certificate rotation target evidence, cluster network access review target evidence, Helm values hardening target evidence, commercial integration target evidence, chargeback closeout target evidence, commercial approval target evidence, enterprise auth target smoke evidence, and operations handoff package target evidence are all present and passing. The operations handoff package target evidence must carry typed boolean confirmations plus strict typed operations readiness/convergence snapshots with readiness `ready`, finalizer failed/gap counts at zero, Kubernetes report sync boolean `true`, failed sync count `0`, and source report result `ready`, plus preserved handoff post-dispatch command count/list. Pending checks include `remediation` command/workflow/workflow-command metadata when a workflow exists so operators can move directly from the report to the needed evidence run.
- Operations evidence plan: `scripts/write-operations-evidence-plan.ps1` converts pending operations readiness checks into an ordered operator plan with local commands, `gh workflow run` commands, placeholder inputs, operator approval flags, and kubeconfig-secret requirements only for Kubernetes-scoped live actions. Enterprise auth and other non-Kubernetes live workflows keep their own workflow secret guidance without being mislabeled as kubeconfig-required. `scripts/verify-operations-evidence-plan.ps1` covers the schema and fixture behavior.
- Operations evidence plan invocation: `scripts/invoke-operations-evidence-plan.ps1` converts the ordered evidence plan into a guarded plan-only or explicit `-Execute` run list. It blocks unresolved placeholders, missing operator approval, missing kubeconfig-secret confirmation, and commands outside the allowlist, then writes `.osmu-run/latest-operations-evidence-plan-invocation.json` plus `.md`. When `gh` is unavailable, reviewed workflow dispatch commands can use `-UseGitHubApi` with `GH_TOKEN` or `GITHUB_TOKEN`, without writing token values to reports. `scripts/verify-operations-evidence-plan-invocation.ps1` covers blocked, confirmed, selected-action plan-only, and missing-token API dispatch behavior.
- Operations invocation unblock plan: `scripts/write-operations-invocation-unblock-plan.ps1` converts a blocked guarded invocation report into required confirmations, placeholder values, per-action plan commands, currently planned action commands, and repeated-placeholder warnings before any live workflow dispatch. `scripts/verify-operations-invocation-unblock-plan.ps1` covers blocked and ready invocation fixtures.
- Operations dispatch preflight: `scripts/write-operations-dispatch-preflight.ps1` converts the unblock plan into a final no-execute readiness check for live workflow dispatch. It checks selected action orders, confirmation flags, placeholder values, workflow file presence, selected-command GitHub secret names, optional GitHub CLI availability, records the GitHub repository plus per-action workflow web dispatch URLs when a repository slug can be resolved, and emits ready plan/execute command previews only when required checks pass. It also emits full-selection and ready-subset API execute command previews with `-UseGitHubApi` when a repository slug is resolved, so GitHub CLI absence does not hide the reviewed dispatch path. Optional workflow secrets are not listed as required unless the selected action flags need them. `scripts/verify-operations-dispatch-preflight.ps1` covers missing-input, workflow dispatch URL, and ready fixtures.
- Operations workflow run id plan: `scripts/write-operations-workflow-run-id-plan.ps1` converts the invocation report into `gh run list` query commands plus GitHub REST API query URLs/`-UseGitHubApi` collection command and browser workflow runs URLs and, when run list JSON, GitHub REST API, or `-Execute` is used, recommends latest successful run ids plus the next Security Evidence Finalizer and artifact collection plan commands, including manual storage backend telemetry, optional manual MinIO bucket CORS verification, manual data-flow storage plan, manual data-flow query/retention budget, manual data-flow storage transition runbook, manual secret rotation, manual cluster network access review, manual Helm values hardening, manual commercial integration, manual commercial approval, manual chargeback closeout, enterprise auth smoke, manual enterprise auth JIT rollback, manual support escalation handoff, manual operations handoff package, and optional Kubernetes operations report sync run ids. The MinIO bucket CORS mapping is dashboard evidence for OSMU browser multipart upload readiness, not an operations readiness gate or AWS S3 parity work. `scripts/verify-operations-workflow-run-id-plan.ps1` covers plan-only and fixture-backed ready behavior.
- Operations artifact collection plan: `scripts/write-operations-artifact-collection-plan.ps1` converts an invocation report plus GitHub workflow run ids into expected artifact names, `gh run download` commands, Security Evidence Finalizer dispatch input, structured `securityEvidenceFinalizerInputs[]` checklist, Operations Readiness Artifact Finalizer dispatch input, manual storage backend telemetry, optional MinIO bucket CORS verification input, manual data-flow storage plan, manual data-flow query/retention budget, manual data-flow storage transition runbook, manual secret rotation, manual cluster network access review, manual Helm values hardening, manual commercial integration, manual commercial approval, manual chargeback closeout, enterprise auth smoke or scope-out, enterprise auth JIT rollback, manual support escalation handoff, manual operations handoff package, optional Kubernetes operations report sync artifact input, optional direct `data_flow_query_retention_budget_json_base64`, and a local import command. It recognizes both local evidence writer commands and direct `gh workflow run manual-*.yml` dispatches. MinIO bucket CORS artifacts stay `requiredForReadiness=false`, are imported only for dashboard browser upload visibility, and are not AWS S3 parity work. Its Kubernetes sync artifact note preserves the data-flow plan query-plan summary requirement, the query/retention budget `result=passed`/typed budget requirement, and the runbook `result=passed`/sanitization requirement. `scripts/verify-operations-artifact-collection-plan.ps1` covers missing-run-id, direct manual workflow dispatch, and ready collection behavior.
- Operations readiness finalizer: `scripts/finalize-operations-readiness.ps1` is the combined operator wrapper that plans or runs the selected evidence finalizers and writes `.osmu-run/latest-operations-readiness-finalize.json` plus `.md`. GitHub Actions passes `-PowerShellCommand pwsh`, and the wrapper propagates that command to child finalizers.
- Operations readiness artifact importer: `scripts/import-operations-readiness-artifacts.ps1` promotes previously collected workflow or manual evidence, including storage backend telemetry, data-flow storage plan, data-flow query/retention budget, data-flow storage transition runbook, secret rotation, commercial integration, commercial approval, chargeback closeout, enterprise auth smoke or scope-out, enterprise auth JIT rollback, operations handoff package evidence, support escalation handoff evidence, and optional Kubernetes data-flow storage plan/query-retention budget/runbook evidence, only when required JSON results are passing, ready, scope-out, or applied as expected. Operations handoff package import also rejects string booleans, missing integer counts, non-ready convergence source reports, and missing typed confirmation booleans before promotion. MariaDB partition/dual-write data-flow plans must carry a sanitized query-plan evidence summary, query/retention budget evidence must be `result=passed` with typed latency/retention budget booleans and confirmations, transition runbook evidence must be `result=passed` with a passed storage-plan snapshot, chargeback closeout evidence must prove sanitized invoice/payment/reconciliation counts without raw customer/payment/provider data, and JIT rollback evidence must exclude raw identity claims and credentials before promotion. The importer writes `.osmu-run/latest-operations-readiness-artifact-import.json` plus `.md`.
- Operations evidence handoff: `scripts/write-operations-evidence-handoff.ps1` stitches the latest readiness, evidence plan, invocation, dispatch preflight, workflow run id, artifact collection, artifact import, and operations readiness finalizer reports into one current bottleneck plus next operator command, preserving workflow-run browser runs URL hints in stage notes for handoff/convergence, emitting trusted input-free blocked review report status/count/action-order/stale/scope metadata, emitting `browserDispatchChecklist[]` with action order, workflow, dispatch/runs URLs, run-id parameter, artifact name, run-list JSON path, and manual artifact command, including the ready-subset API dispatch command in the next-step note when GitHub CLI is unavailable, emitting `postDispatchCommands[]` with saved run-list JSON, GitHub REST API, GitHub CLI, direct browser run-id/run-URL, and post-run-id artifact collection paths, forcing dispatch preflight refresh when selected action orders drift from the planned invocation, and forcing workflow-run-id or artifact-collection refresh when their source action orders are stale or scoped to a different invocation selection. `scripts/verify-operations-evidence-handoff.ps1` covers missing-report, stale-report, dispatch-preflight/workflow-run-id/artifact selected-action scope mismatch, blocked-invocation, browser-dispatch preflight, workflow-run URL hint, artifact-finalizer-ready, operations-finalizer-missing, and operations-finalizer-pending states.
- Operations readiness convergence: `scripts/write-operations-readiness-convergence.ps1` summarizes the latest handoff, readiness, operations readiness finalizer, and Kubernetes operations report sync reports into a no-execute ready/action-required decision with current bottleneck, structured handoff stale/timestamp freshness, mirrored handoff input-free blocked review report status/count/action-order/stale/scope metadata, mirrored handoff required GitHub secret count/list/summaries, stage counts, finalizer failed/gap counts, Kubernetes report sync readiness/result/source result, recommended local command chain, and the equivalent workflow command carrying optional `data_flow_storage_plan_json_base64`, `data_flow_query_retention_budget_json_base64`, and `data_flow_storage_transition_runbook_json_base64` when data-flow storage plan/query-retention/runbook evidence should be delivered with the ConfigMap. The final result is `ready` only when the operations readiness finalizer report exists with `result=ready`, `readinessResult=ready`, typed JSON integer `failedCount=0`, no gaps, and sync evidence is `applied` with typed JSON integer `failedCount=0` and `sourceReportResult=ready`; string or missing failed-count fields keep convergence at `action-required`. `scripts/verify-operations-readiness-convergence.ps1` covers missing-handoff, stale-handoff, finalizer-required, sync-required, string/missing finalizer or sync failed counts, not-ready source sync, and ready states.
- Operations readiness dashboard visibility: `GET /api/admin/dashboard/readiness` surfaces pending operations readiness report checks, the operations evidence plan, the guarded operations evidence invocation report, the invocation unblock plan, the dispatch preflight report, the workflow run id plan, the operations artifact collection plan, the operations readiness artifact import report, the operations readiness finalizer report, the operations evidence handoff, the operations handoff package report, storage expansion/Kubernetes HA/DR/Kubernetes DR evidence reports, the IAM/RBAC evidence report, the security evidence report, the secret rotation evidence report, the support escalation handoff evidence report, MinIO bucket CORS verification, the data-flow storage plan, the data-flow query/retention budget evidence, the data-flow storage transition runbook evidence, the operations readiness convergence report, Kubernetes operations report sync evidence, artifact import failures, pending finalizer status, action-required convergence status, convergence-level sync-required status, planned/server-dry-run sync status, and applied sync evidence whose source report is not yet ready as `OPERATIONS` items for the dashboard readiness panel, including evidence path and remediation command/workflow/workflow-command metadata for individual pending checks plus structured `operationsEvidencePlan.actions`, `operationsEvidencePlan.actions[].dispatchUrl`, `operationsEvidenceInvocation.actions`, `operationsInvocationUnblockPlan.actions`, `operationsDispatchPreflight.checks`, `operationsDispatchPreflight.requiredInputs`, `operationsDispatchPreflight.inputTemplates`, `operationsDispatchPreflight.workflowFiles`, `operationsDispatchPreflight.githubRepository`, `operationsDispatchPreflight.workflowFiles[].dispatchUrl`, `operationsWorkflowRunIdPlan.githubRepository`, `operationsWorkflowRunIdPlan.githubApiRunListCommand`, `operationsWorkflowRunIdPlan.workflows`, `operationsWorkflowRunIdPlan.workflows[].runsUrl`, `operationsWorkflowRunIdPlan.workflows[].gitHubApiQueryUrl`, `operationsArtifactCollectionPlan.artifacts`, `operationsArtifactCollectionPlan.securityEvidenceFinalizerInputs`, `operationsReadinessArtifactImport.entries`, `operationsReadinessFinalize.commands`, `operationsReadinessFinalize.steps`, `operationsReadinessFinalize.gaps`, `operationsEvidenceHandoff.stages`, `operationsEvidenceHandoff.stages[].note`, `operationsEvidenceHandoff.postDispatchCommands`, `operationsEvidenceHandoff.operatorInputValuesCheckNonReadyActionSummaries`, `operationsEvidenceHandoff.nextStep.code`, `operationsEvidenceHandoff.dispatchGithubRepository`, `operationsEvidenceHandoff.readyDispatchWorkflows[].dispatchUrl`, `operationsEvidenceHandoff.blockedDispatchWorkflows[].dispatchUrl`, `operationsHandoffPackage.checks`, `operationsHandoffPackage.operationsConvergenceSnapshot.handoffPostDispatchCommands`, `operationsHandoffPackage.dataFlowStoragePlanSnapshot`, `operationsHandoffPackage.dataFlowQueryRetentionBudgetSnapshot`, `operationsHandoffPackage.dataFlowStorageTransitionRunbookSnapshot`, `operationsHandoffPackage.secretRotationSnapshot`, `operationsHandoffPackage.monitoringThresholdSnapshot`, `operationsHandoffPackage.commercialIntegrationSnapshot`, `operationsHandoffPackage.commercialApprovalSnapshot`, `operationsHandoffPackage.chargebackCloseoutSnapshot`, `operationsHandoffPackage.enterpriseAuthSmokeSnapshot`, `operationsHandoffPackage.enterpriseAuthJitRollbackSnapshot`, `operationsHandoffPackage.clusterNetworkAccessReviewSnapshot`, `operationsHandoffPackage.helmValuesHardeningSnapshot`, `storageExpansionFinalize.steps`, `storageExpansionFinalize.gaps`, `kubernetesHaDrReadiness.checks`, `kubernetesDrFinalize.commands`, `kubernetesDrFinalize.steps`, `kubernetesDrFinalize.gaps`, `iamRbacEvidence.commands`, `iamRbacEvidence.steps`, `iamRbacEvidence.gaps`, `securityEvidence.checks`, `securityEvidence.imageSigning`, `securityEvidence.containerSecurity`, `secretRotationEvidence.rotations`, `secretRotationEvidence.checks`, `clusterNetworkAccessReviewEvidence.staticSnapshot`, `clusterNetworkAccessReviewEvidence.confirmations`, `clusterNetworkAccessReviewEvidence.checks`, `helmValuesHardeningEvidence.staticSnapshot`, `helmValuesHardeningEvidence.confirmations`, `helmValuesHardeningEvidence.checks`, `supportEscalationHandoffEvidence.confirmations`, `supportEscalationHandoffEvidence.checks`, `minioBucketCorsVerification.checks`, `dataFlowStoragePlan.checks`, `dataFlowStoragePlan.candidateDecision`, `dataFlowStoragePlan.queryPlanEvidence`, `dataFlowStorageTransitionRunbook.confirmations`, `dataFlowStorageTransitionRunbook.topFailedChecks`, `operationsReadinessConvergence.currentBottleneck.note`, `operationsReadinessConvergence.handoffOperatorInputValuesCheckNonReadyActionSummaries`, `operationsReadinessConvergence.recommendedCommands`, `operationsReadinessConvergence.recommendedCommands[].note`, `operationsReadinessConvergence.kubernetesReportSyncWorkflowCommand`, `operationsReadinessConvergence.kubernetesReportSyncReady`, `kubernetesOperationsReportSync.sourceReportResult`, `kubernetesOperationsReportSync.dataFlowQueryRetentionBudgetResult`, `kubernetesOperationsReportSync.dataFlowStorageTransitionRunbookResult`, and `kubernetesOperationsReportSync.checks`. Post-deploy validation should run `scripts/verify-kubernetes-operations-report-sync-live.ps1` against the deployed API to prove Kubernetes report sync evidence and ConfigMap-backed data-flow storage plan/query-retention budget/runbook fields are visible from the running dashboard service.
- Operations readiness frontend visibility: the readiness panel shows an operations evidence gaps summary, evidence plan summary line, invocation summary line, invocation unblock summary line, dispatch preflight summary line, workflow run id summary line, artifact collection summary line, artifact import summary line, operations finalizer summary line, evidence handoff summary line, browser-dispatch handoff and browser checklist rows when only GitHub CLI availability blocks preflight, handoff package summary line with convergence post-dispatch count, handoff package data-flow plan candidate-decision/query-retention budget/runbook/secret rotation/monitoring threshold/commercial/chargeback closeout/enterprise-auth/JIT rollback snapshot summary lines, storage expansion finalizer summary line, Kubernetes HA/DR summary line, Kubernetes DR finalizer summary line, IAM/RBAC evidence summary line, security evidence summary line, secret rotation evidence summary line, cluster network access review summary/static/confirmation lines, Helm values hardening summary/static/confirmation lines, support escalation handoff evidence summary/review/ref/document/confirmation lines, enterprise auth JIT rollback evidence summary line, data-flow storage plan summary line, data-flow query/retention budget summary line, data-flow transition runbook summary line, storage backend telemetry summary line, convergence summary line with bottleneck browser dispatch links, Kubernetes report sync summary line, Kubernetes sync query-retention/runbook summary lines, ordered evidence plan actions with dispatch links, invocation planned/blocked action rows, unblock action input rows, dispatch preflight check/input/input-template/workflow rows, workflow query command rows with browser runs links and GitHub REST API run-id copy command, artifact download command rows, security finalizer input rows, artifact import entry rows, finalizer command rows, finalizer step rows, handoff stage rows with notes, handoff package check rows, storage expansion step/gap rows, Kubernetes HA/DR check rows, Kubernetes DR step/gap rows, IAM/RBAC evidence step/gap rows, security evidence check rows, secret rotation rotation/check rows, cluster network access review check rows, Helm values hardening check rows, support escalation handoff check rows, data-flow storage plan check rows, data-flow query/retention budget check rows, data-flow transition runbook check rows, convergence command rows, Kubernetes report sync check rows, quick `Operations` filter, inline remediation command/workflow-command/evidence details, and command copy controls when those items are present.
- Operations handoff package nested visibility also includes `operationsHandoffPackage.secretRotationSnapshot`, `operationsHandoffPackage.enterpriseAuthSmokeSnapshot`, and `operationsHandoffPackage.confirmations.enterpriseAuthSmokeSnapshotReviewed`, so the dashboard can show core secret/certificate rotation status plus reviewed enterprise auth `passed` smoke or accepted `scope-out` evidence inside the final handoff bundle.
- Docker local demo operations report mount: backend container mounts project `.osmu-run` read-only at `/app/.osmu-run`, and `verify-browser-e2e-local-demo.ps1` can seed a Docker-local convergence fixture plus enable the Browser E2E convergence dashboard check through `OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH`.
- Kubernetes/Helm operations report mount: backend Pods mount an optional read-only `osmu-operations-reports` ConfigMap at `/app/.osmu-run`, set `OSMU_OPERATIONS_READINESS_CONVERGENCE_REPORT_PATH`, `OSMU_OPERATIONS_READINESS_KUBERNETES_REPORT_SYNC_REPORT_PATH`, `OSMU_OPERATIONS_READINESS_DATA_FLOW_STORAGE_PLAN_REPORT_PATH`, `OSMU_OPERATIONS_READINESS_DATA_FLOW_QUERY_RETENTION_BUDGET_REPORT_PATH`, and `OSMU_OPERATIONS_READINESS_DATA_FLOW_STORAGE_TRANSITION_RUNBOOK_REPORT_PATH`, and can switch the Helm mount to a PVC for larger evidence sets. `scripts/verify-kubernetes-operations-report-mount.ps1` verifies convergence/sync ConfigMap keys plus the data-flow storage plan key/query-plan summary, data-flow query/retention budget key/budget summary, and data-flow transition runbook key/result summary when local evidence exists, and verifies backend Pod mounted file visibility after apply.
- Kubernetes operations report sync: `scripts/sync-kubernetes-operations-reports.ps1` validates `.osmu-run/latest-operations-readiness-convergence.json`, includes valid `.osmu-run/latest-data-flow-storage-plan.json`, `.osmu-run/latest-data-flow-query-retention-budget-evidence.json`, and `.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json` when present, records byte count/SHA256 plus sanitized query-plan/query-retention/runbook summaries, rejects raw SQL/raw EXPLAIN/credential-shaped plan summary content and raw SQL/raw EXPLAIN/object key/raw event message/credential-shaped query-retention or runbook content, emits plan/server-dry-run/apply commands, supports `-SkipDataFlowQueryRetentionBudgetConfigMapPublish` for refreshing sync freshness while a present query/retention budget report is still not publishable, and requires explicit `-Apply` before updating the `osmu-operations-reports` ConfigMap. `scripts/verify-kubernetes-operations-report-sync.ps1` covers plan, query-retention publish skip, fake server dry-run, fake apply, data-flow storage plan/query-plan summary ConfigMap inclusion, and data-flow query-retention budget and runbook validation/inclusion behavior.
- Kubernetes Operations Report Sync CI uploads `.osmu-run/latest-operations-readiness-convergence.*`, optional `.osmu-run/latest-data-flow-storage-plan.json`, optional `.osmu-run/latest-data-flow-query-retention-budget-evidence.json`, optional `.osmu-run/latest-data-flow-storage-transition-runbook-evidence.json`, `.osmu-run/latest-kubernetes-operations-report-sync-plan.json`, optional server dry-run evidence, and optional apply evidence as `kubernetes-operations-report-sync-<run_id>` artifacts. The operations readiness artifact importer promotes the optional data-flow plan/query-retention budget/runbook into the standard dashboard path when the artifact contains them and the MariaDB/dual-write query-plan summary plus query-retention budget and transition runbook sanitization contracts are present.
- IAM/RBAC finalizer: `scripts/finalize-iam-rbac-readiness.ps1` runs the application IAM/RBAC matrix verifier and Kubernetes RBAC matrix verifier by default, with optional backend focused RBAC tests and live `kubectl auth can-i` evidence.
- IAM/RBAC Finalizer CI uploads `.osmu-run/latest-iam-rbac-finalize.*`, optional storage expansion RBAC auth evidence, and backend RBAC JUnit test reports as `iam-rbac-finalizer-<run_id>` artifacts for operator review.
- Container security evidence writer: `scripts/write-container-security-evidence.ps1` records successful Trivy high/critical scan flags plus backend/frontend SPDX SBOM metadata, byte sizes, and SHA256 hashes into `.osmu-run/latest-container-security-evidence.json`.
- Image signing evidence writer: `scripts/write-image-signing-evidence.ps1` records Cosign verification for backend/frontend version and commit-SHA tags plus backend/frontend image manifest digests into `.osmu-run/latest-image-signing-evidence.json`.
- Security evidence finalizer: `scripts/finalize-security-evidence.ps1` validates those two CI evidence files, rejects synthetic/self-test evidence by default, requires image digests and SBOM hashes, promotes passing files to the standard latest evidence paths, and writes `.osmu-run/latest-security-evidence-finalize.json` plus `.md`.
- Security Evidence Finalizer CI uploads `.osmu-run/latest-security-evidence-finalize.*`, promoted image signing evidence, promoted container security evidence, and the downloaded source evidence bundle as `security-evidence-finalizer-<run_id>` artifacts for operator review.
- NetworkPolicy draft: backend egress to MariaDB/MinIO/DNS and MariaDB/MinIO ingress from backend verified, release report `scope.networkPolicies=included`.
- Container hardening draft: backend image non-root UID 10001, frontend nginx non-root UID 101 on port 8080, and Kubernetes/Helm security contexts verified, release report `scope.containerHardening=included`.
- TLS ingress draft: `osmu-tls` secret reference and NGINX SSL redirect annotations verified, release report `scope.tlsIngress=included`.
- Secret rotation policy draft: admin/JWT/access-key/DB/MinIO/TLS rotation inventory and runbook verified, release report `scope.secretRotationPolicy=included`.
- Backup restore drill draft: MariaDB/MinIO restore runbook and acceptance criteria verified, release report `scope.backupRestoreDrill=included`.
- Backup readiness API/UI: admin status endpoint and dashboard panel expose durable restore pending gates.
- Storage backend status API/UI: `GET /api/admin/storage/backend-status`, mock API, frontend API wrapper, dashboard health widget line, RBAC matrix, and OpenAPI contract expose object storage health, access-key provisioner health, bucket/object metadata counts, optional MinIO Prometheus capacity metrics, and metadata-usage fallback when direct metrics are disabled or unavailable.
- Admin data-flow monitoring API/UI: `GET /api/admin/monitoring/data-flow`, `GET /api/admin/monitoring/data-flow/daily-rollup`, `POST /api/admin/monitoring/data-flow/daily-rollup/materialize`, `GET /api/admin/monitoring/data-flow/daily-rollup/materialized`, `GET /api/admin/monitoring/data-flow/monthly-rollup`, `POST /api/admin/monitoring/data-flow/monthly-rollup/materialize`, `GET /api/admin/monitoring/data-flow/monthly-rollup/materialized`, `GET /api/admin/monitoring/data-flow/storage-status`, `GET /api/admin/monitoring/data-flow/export.csv`, `GET /api/admin/monitoring/data-flow/daily-rollup/export.csv`, `GET /api/admin/monitoring/data-flow/daily-rollup/materialized/export.csv`, `GET /api/admin/monitoring/data-flow/monthly-rollup/export.csv`, `GET /api/admin/monitoring/data-flow/monthly-rollup/materialized/export.csv`, dashboard summary `dataFlow`, and admin data flow panel expose upload/download/internal-copy traffic, operation counts, failure/cancel counts, source/operation trend chart, daily/monthly rollup rows, daily/monthly store refresh/read/export, storage readiness/row counts with `partitionedOrTimeSeriesStoreEnabled=false`, detailed CSV export, daily/monthly rollup CSV export, top buckets, recent flow events, filter controls, MariaDB `data_flow_events` persistence, MariaDB `data_flow_daily_rollups` aggregate storage with actor/status filter dimensions, MariaDB `data_flow_monthly_rollups` aggregate storage with actor/status filter dimensions, detailed event scheduled retention cleanup, and materialized daily/monthly rollup scheduled retention cleanup.
- Prometheus observability draft: `/actuator/prometheus` and backend scrape annotations verified, release report `scope.prometheusObservability=included`.
- Monitoring artifacts draft: Prometheus alert rules and Grafana overview dashboard verified, including data-flow failure/cancel/egress/bucket anomaly and retention failure starter alerts; release report `scope.monitoringArtifacts=included`.
- Prometheus Operator draft: optional ServiceMonitor and PrometheusRule resources verified, release report `scope.prometheusOperatorDraft=included`.
- Frontend unit coverage: current local run reports 115 passing tests.
- Frontend multipart upload tuning: `VITE_MULTIPART_UPLOAD_THRESHOLD_BYTES`, `VITE_MULTIPART_UPLOAD_PART_SIZE_BYTES`, `VITE_MULTIPART_UPLOAD_CONCURRENCY`, `VITE_MULTIPART_UPLOAD_PART_RETRIES`, `VITE_MULTIPART_UPLOAD_RETRY_BASE_DELAY_MS`, and `VITE_MULTIPART_UPLOAD_RETRY_JITTER_RATIO` keep production defaults while allowing small Browser/CI multipart resume fixtures.
- Backend tests: included in release gate when JDK 17+ is available through `-JavaHome`, `JAVA_HOME`, `PATH`, or a known local JDK install path; the local gate passes the resolved Java home into Gradle Java toolchain resolution so stale temp JDK caches do not override an explicit JDK.
- Backend-backed Browser E2E: current local Java prototype path passed with 3 Playwright scenarios on 2026-06-15 19:49 KST.
- Runtime smoke: backend, frontend, health, lightweight API, seeded demo, built-in SigV4 smoke.
- Object share link smoke/tests: global share policy save/enforcement, password/IP-restricted create, missing/wrong password denial, blocked-IP denial, public download, list, password-protected/IP-restricted flags, download count/last access, admin analytics, manual cleanup, scheduled cleanup, revoke, and revoked-token denial.
- External pending gates: GitHub-hosted durable Docker, real S3 client, Browser/Chrome E2E, image signing, and container security evidence. Host `aws`/`mc` S3 smoke remains optional because Dockerized MinIO Client already passed.

## Lightweight Demo Candidate Gate

Required before calling the current prototype demo-ready:

- [x] Java 17+, Node.js, npm available.
- [x] Backend runtime health returns HTTP 200.
- [x] Frontend runtime returns HTTP 200.
- [x] Flyway migration version check passes.
- [x] Local static/unit/build verification passes.
- [x] CI workflow draft verifier passes.
- [x] Durable Docker CI workflow draft verifier passes.
- [x] Real S3 client CI workflow draft verifier passes.
- [x] Container security CI workflow draft verifier passes.
- [x] Browser E2E CI workflow draft verifier passes.
- [x] Kubernetes DR Finalizer CI workflow draft verifier passes.
- [x] Kubernetes Operations Report Sync CI workflow draft verifier passes.
- [x] Image signing policy/workflow draft verifier passes.
- [x] Security evidence writer self-test passes.
- [x] Security evidence finalizer self-test passes.
- [x] IAM/RBAC finalizer self-test passes.
- [x] Release notes generation passes.
- [x] Demo package notes generation passes.
- [x] Commercial readiness draft verifier passes.
- [x] OpenAPI MVP contract verifier passes.
- [x] Kubernetes manifest draft verifier passes.
- [x] Helm chart draft verifier passes.
- [x] Deployment resource profile checks pass.
- [x] NetworkPolicy draft verifier passes.
- [x] Container hardening draft verifier passes.
- [x] TLS ingress draft verifier passes.
- [x] Secret rotation policy draft verifier passes.
- [x] Backup restore drill draft verifier passes.
- [x] Prometheus observability draft verifier passes.
- [x] Monitoring artifacts draft verifier passes.
- [x] Prometheus Operator draft verifier passes.
- [x] Backup readiness status API test and admin dashboard selector contract pass.
- [x] Frontend unit tests pass.
- [x] Frontend stable selector contract test passes.
- [x] Backend Gradle tests pass.
- [x] Backend-backed Browser E2E prototype passes.
- [x] Mock and backend-backed Browser E2E cover operations readiness convergence dashboard summary and recommended command rows.
- [x] Kubernetes/Helm backend Pods mount the operations readiness convergence report path for deployed dashboard checks.
- [x] Lightweight API smoke passes.
- [x] Seeded demo smoke passes.
- [x] Built-in manual SigV4 probes pass.
- [x] MVP audit report generated.
- [x] MVP release decision script self-test passes.
- [x] MVP release artifact consistency check passes.
- [x] Operations readiness artifact shape verifier passes.
- [x] Operations evidence plan verifier passes.
- [x] Operations invocation unblock plan verifier passes.
- [x] Operations dispatch preflight verifier passes.
- [x] Operations workflow run id plan verifier passes.
- [x] Operations artifact collection plan verifier passes.
- [x] Operations evidence handoff verifier passes.
- [x] Operations readiness convergence verifier passes, including stale handoff refresh routing when readiness is newer than the handoff report.
- [x] MVP release checklist verifier passes.
- [x] Kubernetes operations report sync verifier passes.
- [x] Operations readiness finalizer plan self-test passes.
- [x] Operations readiness dashboard API visibility test passes.
- [x] Operations readiness frontend selector visibility test passes.
- [x] Durable release artifact generator synthetic test passes.
- [x] Test case evidence map separates PASS, PARTIAL, and PENDING items.
- [x] S3 replacement boundary verifier passes and keeps English/Korean compatibility claims in README, API spec, feature inventory, status, and release-facing docs scoped to `dev-docs/s3-compatibility.md`.
- [x] Data-flow query/retention budget evidence writer self-test passes.
- [x] Chargeback closeout evidence writer self-test passes.
- [x] Enterprise auth JIT rollback evidence writer self-test passes.
- [x] Cluster network access review evidence writer self-test passes.
- [x] Helm values hardening evidence writer self-test passes.
- [x] Manual cluster network access review evidence workflow check passes.
- [x] Manual Helm values hardening evidence workflow check passes.
- [x] Support escalation handoff evidence writer self-test passes.
- [x] Manual support escalation handoff evidence workflow check passes.

Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-prototype-release.ps1 -JavaHome "<jdk17>"
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-audit.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-release-decision.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-release-notes.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json
powershell -ExecutionPolicy Bypass -File .\scripts\write-mvp-demo-package-notes.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-release-decision.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-release-artifacts.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-demo-package-notes.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-s3-compatibility-boundary.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-completion.ps1
```

Decision: GO for local lightweight demo. Local durable MVP evidence is also ready when `.osmu-run/latest-durable-demo-gate.json` and `.osmu-run/latest-demo-readiness.json` both show `result=ready`.

## Durable MVP Pilot Gate

Required before calling MVP v0.1 durable/pilot-ready:

- [x] Docker Desktop daemon running.
- [x] MariaDB + MinIO docker compose starts cleanly.
- [x] Docker integration smoke passes.
- [x] MariaDB object tag index smoke passes.
- [x] MinIO-backed multipart checksum smoke passes.
- [x] S3 replacement boundary verifier passes.
- [x] Real S3 client smoke passes with Dockerized MinIO Client.
- [x] Durable demo gate `scripts/verify-durable-demo-gate.ps1` passes and records `docker-durable-demo-verified`.
- [ ] Real S3 client CI workflow has a successful GitHub-hosted run.
- [x] Browser/Chrome UI click-path E2E passes.
- [ ] Browser E2E CI workflow has a successful GitHub-hosted run.
- [ ] Image publish/sign workflow has a successful GitHub-hosted run with `publish=true`.
- [x] Release report records Docker integration as included.
- [ ] Durable Docker CI workflow has a successful GitHub-hosted run.
- [x] Release report records Browser E2E as verified.
- [x] Durable release artifacts are generated by `scripts/write-durable-release-artifacts.ps1` from a ready durable gate report and backend test evidence, preserving the gate report's selected S3 client and durable preflight report path.
- [x] Durable release artifacts include demo package notes through `scripts/write-mvp-demo-package-notes.ps1`.
- [x] Durable finalize wrapper `scripts/finalize-durable-mvp-demo.ps1` passes on a Docker-ready machine and writes `.osmu-run/latest-durable-mvp-finalize.json` plus `.md`.
- [x] Durable finalize PlanOnly verifier `scripts/verify-durable-mvp-finalize-plan.ps1` passes and proves default plan-only runs preserve latest ready finalizer evidence.
- [x] Durable finalize and Durable Docker CI can request real MinIO browser multipart pause/resume evidence with `-EnableRealMultipartEvidence` and publish `.osmu-run/latest-browser-multipart-resume-evidence.json` plus `.md`.
- [x] Durable preflight next commands include the same `-EnableRealMultipartEvidence` gate/finalize follow-up path, so pending prerequisite reports point operators at the evidence-producing run.
- [ ] Operations readiness finalizer workflow has a successful live run with selected Kubernetes/security evidence steps.
- [x] MVP audit report has no PENDING durable gate. `latest-durable-demo-gate.json` has `result=ready` and `currentDemoStatus=docker-durable-demo-verified`; remaining audit PENDING lines are production operations evidence, not durable demo blockers.

Commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-gate.ps1 -EnableRealMultipartEvidence
powershell -ExecutionPolicy Bypass -File .\scripts\verify-durable-mvp-finalize-plan.ps1
Push-Location .\osmu-backend
.\gradlew test
Pop-Location
powershell -ExecutionPolicy Bypass -File .\scripts\write-durable-release-artifacts.ps1 -DurableGateReportPath .\.osmu-run\latest-durable-demo-gate.json -BackendTestsIncluded
powershell -ExecutionPolicy Bypass -File .\scripts\finalize-durable-mvp-demo.ps1 -S3Client docker-mc -EnableRealMultipartEvidence
powershell -ExecutionPolicy Bypass -File .\scripts\verify-s3-compatibility-boundary.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-completion.ps1
```

Hard ready gate after Docker-ready finalizer refresh:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mvp-completion.ps1 -FailIfLocalMvpNotReady
```

Decision: GO for local durable MVP demo when using the latest local evidence. NO-GO for hosted/production pilot until GitHub-hosted workflow evidence and operations readiness finalizers pass.

## Browser E2E Checklist

Run when Browser/Chrome automation works again:

- [x] Manual Browser E2E CI workflow draft exists and is checked by `scripts/verify-ci-workflow.ps1`.
- [x] Browser E2E spec includes developer mode login to `/developer`, S3 endpoint/snippet visibility, Admin nav hiding, and Access Key create UI contract.
- [x] Browser E2E spec includes stored session restore without login plus stale stored session redirect cleanup.
- [x] Browser E2E spec includes auth refresh retry on object download, refresh failure session cleanup, and logout token cleanup.
- [x] Browser E2E spec includes Access Key scope add/remove, disabled create without scope, cancel revoke, and confirmed revoke state.
- [x] Browser E2E spec includes Access Key operational filters, cleanup candidate count, and action hint render paths.
- [x] Browser E2E spec includes Access Key cleanup preview export, candidate exclusion, and bulk disable confirm paths.
- [x] Browser E2E spec includes Admin security/audit policy panel render and Audit link navigation.
- [x] Browser E2E spec includes Admin approval workflow profile approve/apply and storage expansion approve/dry-run/apply paths.
- [x] Browser E2E spec includes Admin role-based panel visibility for ADMIN, ORG_ADMIN, and USER redirect paths.
- [x] Browser E2E spec includes Admin action failure remediation for 401, 403, 400, 404, and 409 responses.
- [x] Browser E2E spec includes error alert Request ID visibility for admin API failures.
- [x] Browser E2E spec includes destructive confirm cancel/confirm paths for bucket delete.
- [x] Browser E2E spec includes operations readiness convergence summary and recommended command row visibility.
- [x] Browser E2E spec includes bucket list name, usage, and object count cell assertions.
- [x] Browser E2E spec includes bucket-side storage profile request and request status row assertions.
- [x] Browser E2E spec includes admin storage profile approve/apply status transitions.
- [x] Browser E2E spec includes object upload followed by prefix/list refresh and object detail render.
- [x] Browser E2E spec includes single-object upload cancel/retry button flow and list refresh after retry.
- [x] Browser E2E spec includes presigned upload URL/complete handoff controls and list refresh after complete.
- [x] Browser E2E spec includes pending multipart resume panel, matching Resume enable, Expired disable, and delete confirm paths.
- [x] Browser E2E spec includes opt-in mock multipart Pause -> pending resume -> complete click path with `object-upload-pause-button`.
- [x] Browser E2E spec includes opt-in real Docker/MinIO multipart Pause -> pending resume -> complete path, enabled by `verify-browser-e2e-local-demo.ps1 -EnableRealMultipartFixture -TestGrep "real MinIO multipart"`.
- [x] Docker local Browser E2E verifier writes `.osmu-run/latest-browser-multipart-resume-evidence.json` and `.md` after a successful real MinIO multipart pause/resume run, without storing credentials, presigned URLs, object bytes, or raw request/response bodies.
- [x] Durable gate/finalize/CI path can request the same browser multipart evidence with `-EnableRealMultipartEvidence` and include it in durable demo artifacts.
- [ ] Latest durable gate records real MinIO-backed browser multipart pause/resume execution evidence.
- [x] Browser E2E spec includes object metadata drift fixture with sync-status badge and index/storage row comparison.
- [x] Browser E2E spec includes object prefix open/root breadcrumb navigation, search highlight, tag filter, tag edit, and invalid tag error paths.
- [x] Browser E2E spec includes Object Explorer page size select, first-page cursor reset, and next-page limit retention paths.
- [x] Browser E2E spec includes bucket lifecycle XML save/load/delete and bucket tags save/load/delete click paths.
- [x] Browser E2E spec includes audit filter, next-page click, CSV download filename, and reset click paths.
- [x] Backend-backed Browser E2E prototype passes locally.
- [x] Browser acceptance spec coverage is locked by `scripts/verify-ci-workflow.ps1` for seeded login, bucket list, upload progress, confirm modal, access key scope/revoke, prefix breadcrumb, search highlight, object tagging, lifecycle XML, bucket tags, and audit filter/pagination/CSV paths; fresh checkbox rows below remain execution evidence.
- [x] Latest mock Browser E2E execution `scripts/verify-browser-e2e-mock-demo.ps1` passed locally with 18 passed and 2 opt-in multipart tests skipped, covering the fresh UI smoke rows below against the stateful mock API.
- [x] Login as seeded admin/demo user.
- [x] Bucket list renders names, usage, and object counts.
- [x] Object upload shows progress and prevents duplicate submit.
- [x] Object list refreshes after upload.
- [x] Confirm modal cancel does not call destructive API.
- [x] Confirm modal confirm calls destructive/revoke API once.
- [x] Access key scope create/revoke UI paths work.
- [x] Object prefix breadcrumb navigation works.
- [x] Object search highlight renders.
- [x] Object tag edit, filter, and invalid-input UI paths work.
- [x] Object metadata detail panel shows sync status, index fields, storage fields, drift, and missing values.
- [x] Bucket lifecycle XML load/save/delete panel works.
- [x] Bucket tags load/save/delete panel works.
- [x] Audit log filter, pagination, and CSV export UI paths work.

## Real S3 Client Checklist

Run with AWS CLI, Python+boto3, Node.js with `@aws-sdk/client-s3`, or host MinIO Client available, or Dockerized MinIO Client when Docker Desktop is running:

- [x] Smoke script coverage includes bucket root listing for AWS CLI, boto3, AWS SDK JavaScript/Java, host `mc`, and Dockerized `mc` before per-bucket object operations.
- [ ] List buckets with real client.
- [ ] Upload object with real client.
- [ ] Head/stat object with real client.
- [ ] List objects with real client.
- [ ] Download/cat object with real client.
- [ ] Delete object with real client.
- [ ] Cleanup bucket with real client.
- [ ] Built-in SigV4 checksum, tagging, range, conditional, CopyObject, multi-delete, and digest mismatch probes still pass.

## Container Security Checklist

Run in GitHub Actions before pilot/customer distribution:

- [ ] Backend container image builds successfully.
- [ ] Frontend container image builds successfully.
- [ ] Trivy high/critical vulnerability scan passes for backend image.
- [ ] Trivy high/critical vulnerability scan passes for frontend image.
- [ ] Backend SPDX SBOM artifact is uploaded.
- [ ] Frontend SPDX SBOM artifact is uploaded.
- [ ] Backend and frontend SBOM SHA256 hashes are recorded in container security evidence.
- [ ] `.osmu-run/latest-container-security-evidence.json` is generated from the successful workflow and attached to operations readiness evidence.
- [x] Image signing policy and registry target are decided before production/B2B sale.
- [ ] Backend and frontend image signatures verify with Cosign.
- [ ] Backend and frontend image manifest digests are recorded in image signing evidence.
- [ ] `.osmu-run/latest-image-signing-evidence.json` is generated from the successful publish/sign workflow and attached to operations readiness evidence.
- [ ] `scripts/finalize-security-evidence.ps1` passes with non-synthetic CI artifacts and writes `.osmu-run/latest-security-evidence-finalize.json`.
- [x] Commercial positioning, pilot package, license model, and pricing tier draft exist.
- [ ] `.osmu-run/latest-commercial-approval-evidence.json` is generated with `result=passed` for final pricing, terms, support SLA, license agreement, legal approval, and pilot contract boundary references.
- [x] Chargeback closeout summary API, evidence writer, verifier, and manual workflow exist.
- [ ] `.osmu-run/latest-chargeback-closeout-evidence.json` is generated with `result=passed` for target billing period pricing, usage, invoice, payment handoff, notification, retry, reconciliation, commercial integration, and commercial approval references.

## Go/No-Go Rules

- Lightweight demo: GO when required lightweight gate and audit pass.
- Durable pilot: local demo/pilot handoff can be GO when local durable gate, demo readiness, Browser E2E, and real S3 client smoke evidence are ready; keep completion hard gate NO-GO while the latest durable finalizer report is plan-only, and keep GitHub-hosted durable Docker, real S3 client, and Browser E2E workflow evidence separate for hosted pilot promotion.
- Production/B2B sale: NO-GO until durable pilot passes plus certificate issuance/rotation, backup/restore drill, secret rotation, monitoring alerts, SSO/LDAP or enterprise auth, deployment hardening, container vulnerability/SBOM evidence, image signing, final pricing/licensing/legal approval, and support SLA work are complete.

## Release Notes Template

```md
## OSMU MVP v0.1

- Candidate:
- Release report:
- MVP audit:
- Backend:
- Frontend:
- S3 compatibility:
- Known blockers:
- Go/No-Go decision:
```
