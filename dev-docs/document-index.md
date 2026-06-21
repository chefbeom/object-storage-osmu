# OSMU Document Index

This index points to the useful project documents for the current prototype. The root `README.md` is the fastest starting point for running and verifying the project.

## Start Here

1. `../README.md` - prototype overview, run commands, verification commands.
2. `PRODUCT_REQUIREMENTS.md` - product goal, MVP scope, final target scope.
3. `PROJECT_MEMORY.md` - long-term project memory and direction.
4. `prototype-status.md` - current implemented scope, latest verification, blockers, and next work.
5. `feature-inventory.md` - current feature map, implemented scope, gaps, fixes, and next development direction.
6. `mvp-release-checklist.md` - MVP v0.1 release gate checklist and go/no-go rules.
7. `development-roadmap.md` - roadmap from MVP to product.

## Engineering Design

- `system-architecture.md` - high-level architecture.
- `api-spec.md` - REST and S3-compatible API notes.
- `s3-compatibility.md` - supported, partial, and unsupported S3-compatible API/client matrix.
- `openapi-mvp.json` - machine-readable MVP REST/S3 API contract snapshot.
- `database-design.md` - MariaDB schema and metadata design.
- `backend-design.md` - Spring Boot backend design.
- `frontend-design.md` - Vue portal design.
- `storage-profile.md` - bucket-level Performance/Standard/Durable request, approval, MariaDB, UI, and MinIO pool/parity design.
- `local-dev-env.md` - local Docker/MariaDB/MinIO environment.

## Operations

- `security-design.md` - auth, access keys, permissions, security policy.
- `iam-rbac-matrix.md` - role, endpoint, dashboard panel, and operation permission matrix.
- `kubernetes-rbac-matrix.md` - Kubernetes ServiceAccount, token automount, storage expansion runner, and cluster RBAC boundary matrix.
- `backup-recovery.md` - backup and recovery direction.
- `operation-monitoring.md` - health checks, backup readiness status, logs, metrics, monitoring.
- `deployment-strategy.md` - Docker Compose, Kubernetes, Helm direction.
- `minio-pool-expansion.md` - MinIO server pool-based capacity expansion strategy and Storage Expansion Manager direction.
- `storage-profile.md` - MinIO pool/parity intent mapping for Storage Profile.
- `../infra/k8s/README.md` - Kubernetes draft manifest guide.

## Testing

- `test-strategy.md` - test strategy and quality gates.
- `test-cases.md` - detailed test cases.
- `../scripts/verify-local.ps1` - local static/unit/build/backend verification.
- `../scripts/write-migration-rollback-plan.ps1` - write a Flyway forward-only migration rollback plan with backup, restore, smoke, and compensating-migration stages.
- `../scripts/verify-migration-rollback-plan.ps1` - verify the migration rollback plan shape, required stages, backup-artifact requirement, and no-secret reference policy.
- `../scripts/verify-metadata-index-coverage.ps1` - statically verify migration-backed index prefixes for high-volume metadata, data-flow, audit, storage expansion, and chargeback retry query paths.
- `../scripts/write-mariadb-query-plan-evidence.ps1` - write plan-only, operator-collected, or live `EXPLAIN FORMAT=JSON` evidence for high-volume MariaDB query paths without storing database passwords.
- `../scripts/verify-mariadb-query-plan-evidence.ps1` - self-test MariaDB query plan evidence shape, expected-index pass fixtures, and wrong-index failure fixtures.
- `../scripts/verify-object-list-query-pushdown.ps1` - statically verify MariaDB object list/search/tag/trash query pushdown for search, cursor, limit, and tag lookup paths.
- `../scripts/verify-prototype-prerequisites.ps1` - check Java, Node/npm, Docker, real S3 clients, and runtime/frontend/database/storage endpoints before deeper prototype verification.
- `../scripts/verify-prototype-release.ps1` - one-command MVP release gate that combines prerequisites, build verification, backend tests, runtime smoke, seeded demo smoke, and S3 smoke.
- `../scripts/write-mvp-audit.ps1` - write a human-readable MVP audit from the latest release evidence report and optional durable gate report.
- `../scripts/write-mvp-release-decision.ps1` - write lightweight demo and durable pilot go/no-go decisions from the latest release evidence report and optional durable gate report.
- `../scripts/write-mvp-release-notes.ps1` - write lightweight or durable demo release notes from the latest release evidence, durable gate, audit, and decision reports.
- `../scripts/write-durable-release-artifacts.ps1` - convert a passed durable demo gate report plus backend test evidence into synchronized durable release JSON, audit, decision, release notes, and artifact verification; preserves selected S3 client and durable preflight report evidence from the gate report.
- `../scripts/finalize-durable-mvp-demo.ps1` - one-command durable MVP finalization wrapper for Docker-ready machines; runs durable preflight, backend tests, durable gate, durable release artifact generation, and hard readiness verification. `-PlanOnly` writes the planned command sequence without starting containers.
- `../scripts/verify-mvp-completion.ps1` - verify the current local durable MVP completion state from demo readiness, durable gate, durable finalizer, release artifacts, and status documents; writes `.osmu-run/latest-mvp-completion.*` while keeping production/B2B operations readiness separate.
- `../scripts/write-operations-readiness.ps1` - write a production/B2B operations readiness JSON and Markdown report from release scope, RBAC/security/static controls, storage expansion finalizer evidence, storage backend telemetry evidence, Kubernetes HA/DR readiness, Kubernetes DR finalizer evidence, image signing evidence, container scan/SBOM evidence, secret rotation evidence, commercial integration evidence, commercial approval evidence, enterprise auth smoke evidence, and operations handoff package evidence; pending live/security/storage-telemetry/secret-rotation/commercial/enterprise-auth/package checks include remediation command/workflow metadata where applicable, including the dedicated storage backend telemetry evidence workflow.
- `../scripts/verify-operations-readiness.ps1` - regenerate and verify the operations readiness artifact shape, required pending evidence checks, and remediation metadata without requiring the target cluster to be ready.
- `../scripts/write-secret-rotation-evidence.ps1` - record target-environment secret/certificate rotation evidence as `.osmu-run/latest-secret-rotation-evidence.*` with external references and booleans only; it rejects credential-shaped references and never stores secret values.
- `../scripts/verify-secret-rotation-evidence.ps1` - self-test the secret rotation evidence writer, passed evidence shape, and secret-like reference rejection.
- `../scripts/write-storage-backend-telemetry-evidence.ps1` - record MinIO pool/server/drive telemetry evidence from `mc admin info --json` file input or explicit `-Execute`; stores summaries, SHA-256, and external references only, never raw admin output or credentials.
- `../scripts/verify-storage-backend-telemetry-evidence.ps1` - self-test storage backend telemetry evidence shape, pool/node/capacity parsing, and secret-like input rejection.
- `../scripts/verify-minio-bucket-cors.ps1` - verify MinIO bucket CORS from `mc cors info <alias>/<bucket>` or a collected CORS XML file; records only normalized methods, origins, allowed headers, exposed headers, max-age, and checks needed by browser multipart upload.
- `../scripts/verify-minio-bucket-cors-self-test.ps1` - self-test MinIO bucket CORS verification with plan-only, passed, and failed fixtures.
- `../scripts/write-commercial-integration-evidence.ps1` - record target-environment notification webhook, Slack, EMAIL SMTP relay, generic payment webhook, CARD/BANK/TAX/ERP payment webhook profile handoff, and sanitized payment-provider adapter readiness evidence as `.osmu-run/latest-commercial-integration-evidence.*` without credentials, raw provider responses, or native processor support claims.
- `../scripts/verify-commercial-integration-evidence.ps1` - self-test the commercial integration evidence writer, payment-provider adapter readiness snapshot parsing, passed evidence shape, and credential-like reference rejection.
- `../scripts/write-commercial-approval-evidence.ps1` - record final pricing, terms, support SLA, license agreement, legal approval, pilot contract boundary approval, and sanitized billing pricing proposal commercial approval evidence as `.osmu-run/latest-commercial-approval-evidence.*` with references, status metadata, and booleans only.
- `../scripts/verify-commercial-approval-evidence.ps1` - self-test the commercial approval evidence writer, pricing proposal approval snapshot parsing, passed approval shape, price/raw-contract exclusion, and credential-like reference rejection.
- `../scripts/write-operations-handoff-package.ps1` - record target-environment operations handoff package evidence as `.osmu-run/latest-operations-handoff-package.*`, tying runbook, troubleshooting, rollback, support escalation, known gaps, commercial approval, target evidence references, and sanitized operations readiness/convergence snapshot summaries together without executing external commands or storing secrets.
- `../scripts/verify-operations-handoff-package.ps1` - self-test the operations handoff package writer, passed package shape, readiness/convergence snapshot parsing, required snapshot failure, and credential-like reference/snapshot rejection.
- `../scripts/write-operations-evidence-plan.ps1` - convert pending operations readiness checks into an ordered evidence plan with local commands, `gh workflow run` commands, operator placeholders, approval flags, and kubeconfig-secret requirements.
- `../scripts/invoke-operations-evidence-plan.ps1` - turn the ordered evidence plan into a guarded plan-only or explicit `-Execute` invocation report; blocks unresolved placeholders, missing operator approval, missing kubeconfig-secret confirmation, and unsafe commands before dispatching live evidence workflows.
- `../scripts/verify-operations-evidence-plan-invocation.ps1` - self-test the evidence plan invocation helper across blocked, confirmed, and selected-action plan-only runs.
- `../scripts/write-operations-invocation-unblock-plan.ps1` - read the guarded invocation report and generate an operator handoff for resolving blocked actions, including required confirmations, placeholders, per-action plan commands, and currently planned actions that can be run separately.
- `../scripts/verify-operations-invocation-unblock-plan.ps1` - self-test invocation unblock planning across blocked and ready invocation fixtures.
- `../scripts/write-operations-dispatch-preflight.ps1` - verify dispatch readiness from the invocation unblock plan without executing workflows, including confirmations, placeholder values, workflow files, required GitHub secret names, and optional GitHub CLI availability.
- `../scripts/verify-operations-dispatch-preflight.ps1` - self-test dispatch preflight across missing-input and ready fixtures.
- `../scripts/write-operations-workflow-run-id-plan.ps1` - derive `gh run list` commands and recommended latest successful workflow run ids from an invocation report, then build Security Evidence Finalizer and artifact collection plan follow-up commands, including manual storage backend telemetry, secret rotation, commercial integration, commercial approval, operations handoff package, optional enterprise auth smoke, and Kubernetes operations report sync run ids.
- `../scripts/verify-operations-workflow-run-id-plan.ps1` - self-test workflow run id planning with plan-only and fixture-backed ready reports.
- `../scripts/write-operations-artifact-collection-plan.ps1` - derive expected GitHub artifact names, `gh run download` commands, Security Evidence Finalizer dispatch input, Operations Readiness Artifact Finalizer dispatch input, storage backend telemetry/secret rotation/commercial integration/commercial approval/enterprise auth smoke/operations handoff package/Kubernetes operations report sync artifact input, and local artifact import commands from an invocation report plus workflow run ids.
- `../scripts/verify-operations-artifact-collection-plan.ps1` - self-test the artifact collection plan helper with missing and concrete workflow run ids.
- `../scripts/finalize-operations-readiness.ps1` - orchestrate storage expansion, Kubernetes HA/DR, Kubernetes DR, security evidence finalization, and the combined operations readiness report from one guarded command; propagates `-PowerShellCommand` to child finalizers for Linux CI compatibility.
- `../scripts/verify-operations-readiness-finalizer.ps1` - self-test the operations readiness finalizer plan mode and secret masking behavior.
- `../scripts/import-operations-readiness-artifacts.ps1` - import previously collected storage expansion, HA/DR, Kubernetes DR, IAM/RBAC, security evidence, storage backend telemetry, secret rotation, commercial integration, commercial approval, enterprise auth smoke, operations handoff package, and Kubernetes operations report sync artifacts into the standard `.osmu-run/latest-*` readiness paths after validating their expected result values.
- `../scripts/verify-operations-readiness-artifact-import.ps1` - self-test the operations readiness artifact importer, including rejection of invalid failed evidence.
- `../scripts/write-operations-evidence-handoff.ps1` - stitch the latest operations readiness, evidence plan, guarded invocation, workflow run id, artifact collection, artifact import, and operations readiness finalizer reports into one current bottleneck plus next-command handoff report.
- `../scripts/verify-operations-evidence-handoff.ps1` - self-test handoff selection for missing reports, blocked invocation, artifact-finalizer-ready, operations-finalizer-missing, and operations-finalizer-pending states.
- `../scripts/write-operations-readiness-convergence.ps1` - summarize the latest handoff, readiness, and operations finalizer reports into a no-execute convergence report with current bottleneck, recommended command chain, and ready decision.
- `../scripts/verify-operations-readiness-convergence.ps1` - self-test convergence reporting for missing handoff, finalizer-required, and fully ready states.
- `../scripts/sync-kubernetes-operations-reports.ps1` - validate and sync the latest operations readiness convergence report plus generated sync evidence into the Kubernetes `osmu-operations-reports` ConfigMap with plan-only, server-dry-run, and explicit apply modes.
- `../scripts/verify-kubernetes-operations-report-sync.ps1` - self-test Kubernetes operations report ConfigMap sync using a fake kubectl for plan, server dry-run, and apply paths.
- `../scripts/verify-kubernetes-operations-report-sync-live.ps1` - poll deployed dashboard readiness until it reflects the applied Kubernetes operations report sync evidence and mounted data-flow storage plan without storing admin passwords or bearer tokens.
- `../scripts/verify-kubernetes-operations-report-sync-live-self-test.ps1` - self-test the live sync verifier with dashboard fixtures for applied sync/data-flow and stale sync states.
- `../scripts/verify-kubernetes-operations-report-mount.ps1` - read-only live verifier that checks the operations report ConfigMap keys and confirms the backend Pod can read the mounted convergence, sync evidence, and data-flow storage plan files.
- `../scripts/verify-kubernetes-operations-report-mount-self-test.ps1` - self-test the ConfigMap and backend Pod mount verifier with a fake kubectl.
- `../.github/workflows/kubernetes-operations-report-sync-ci.yml` - manual GitHub Actions workflow for operations convergence report generation plus optional data-flow storage plan restore, Kubernetes ConfigMap sync plan, server-dry-run, and guarded apply evidence.
- `../scripts/finalize-iam-rbac-readiness.ps1` - finalize IAM/RBAC readiness evidence by running the application IAM/RBAC matrix verifier, Kubernetes RBAC matrix verifier, and optional backend focused RBAC tests or live `kubectl auth can-i` evidence.
- `../scripts/verify-iam-rbac-finalizer.ps1` - self-test the IAM/RBAC finalizer static and plan modes.
- `../scripts/write-container-security-evidence.ps1` - convert successful Trivy high/critical scan flags and backend/frontend SPDX SBOM files into `.osmu-run/latest-container-security-evidence.json` with SBOM byte size and SHA256 hashes.
- `../scripts/write-image-signing-evidence.ps1` - convert successful Cosign verification for backend/frontend version and commit-SHA image tags into `.osmu-run/latest-image-signing-evidence.json` with image manifest digests.
- `../scripts/verify-security-evidence-writers.ps1` - self-test the container security and image signing evidence writers with synthetic local artifacts.
- `../scripts/finalize-security-evidence.ps1` - validate image signing and container scan/SBOM evidence from CI artifacts, reject synthetic evidence by default, promote passing evidence to the standard latest paths, and write `.osmu-run/latest-security-evidence-finalize.*`.
- `../scripts/verify-security-evidence-finalizer.ps1` - self-test the security evidence finalizer and its synthetic evidence rejection guard.
- `../scripts/verify-mvp-release-decision.ps1` - self-test release decision logic against synthetic lightweight and durable reports.
- `../scripts/verify-ci-workflow.ps1` - verify GitHub Actions workflow drafts for lightweight CI, durable Docker MVP gate CI, real S3 client CI, container security CI, Browser E2E CI, storage expansion finalizer CI, Kubernetes HA/DR readiness CI, Kubernetes DR finalizer CI, operations readiness finalizer CI, storage backend telemetry evidence CI, enterprise auth smoke CI, and finalizer `pwsh` command propagation.
- `../.github/workflows/storage-expansion-finalizer-ci.yml` - manual GitHub Actions workflow for storage expansion finalizer plan/live evidence collection. Live mode requires `OSMU_KUBECONFIG_BASE64` and uploads finalizer/RBAC/dry-run evidence artifacts plus optional storage backend telemetry evidence artifacts when `record_storage_backend_telemetry=true`.
- `../.github/workflows/kubernetes-ha-dr-readiness-ci.yml` - manual GitHub Actions workflow for Kubernetes HA/DR readiness plan/live evidence collection. Live mode requires `OSMU_KUBECONFIG_BASE64` and uploads `.osmu-run/latest-kubernetes-ha-dr-readiness.json`.
- `../.github/workflows/kubernetes-dr-finalizer-ci.yml` - manual GitHub Actions workflow for Kubernetes DR finalizer plan/live evidence collection. Live mode requires `OSMU_KUBECONFIG_BASE64`, uses `server_dry_run_only` by default, and requires explicit `confirm_restore=true` before confirmed restore or evidence submit can run.
- `../.github/workflows/operations-readiness-finalizer-ci.yml` - manual GitHub Actions workflow for combined operations readiness plan/live evidence collection. Live mode requires `OSMU_KUBECONFIG_BASE64` and uploads the combined readiness report plus selected storage, HA/DR, DR, IAM/RBAC, and security evidence artifacts.
- `../.github/workflows/operations-readiness-artifact-finalizer-ci.yml` - manual GitHub Actions workflow that downloads evidence artifacts from previous storage expansion, HA/DR, Kubernetes DR, IAM/RBAC, security, storage backend telemetry, secret rotation, commercial integration, commercial approval, enterprise auth smoke, operations handoff package, and optional Kubernetes operations report sync workflow runs, imports passing evidence into standard latest paths, writes the operations readiness report, and uploads the resulting artifact set.
- `../.github/workflows/manual-storage-backend-telemetry-evidence.yml` - manual GitHub Actions workflow that wraps `write-storage-backend-telemetry-evidence.ps1`, either decodes a prepared `OSMU_MINIO_ADMIN_INFO_JSON_BASE64` secret or uses `collection_mode=live` to run `mc admin info --json` against the target MinIO endpoint with temporary `MC_CONFIG_DIR`, removes raw input and mc config after the run, and uploads `storage-backend-telemetry-evidence-<run_id>`.
- `../.github/workflows/manual-secret-rotation-evidence.yml` - manual GitHub Actions workflow that wraps `write-secret-rotation-evidence.ps1`, records target secret/certificate rotation evidence without secrets, and uploads `secret-rotation-evidence-<run_id>`.
- `../.github/workflows/manual-commercial-integration-evidence.yml` - manual GitHub Actions workflow that wraps `write-commercial-integration-evidence.ps1`, accepts base64 payment-provider adapter readiness JSON, records target notification/payment handoff evidence without credentials or native processor claims, and uploads `commercial-integration-evidence-<run_id>`.
- `../.github/workflows/manual-commercial-approval-evidence.yml` - manual GitHub Actions workflow that wraps `write-commercial-approval-evidence.ps1`, accepts base64 billing pricing proposal approval JSON, records final commercial/legal approval references without prices/contracts/license keys, and uploads `commercial-approval-evidence-<run_id>`.
- `../.github/workflows/manual-operations-handoff-package.yml` - manual GitHub Actions workflow that wraps `write-operations-handoff-package.ps1`, accepts base64 operations readiness/convergence snapshots, records target operations handoff package references without running external systems, deletes decoded temporary snapshot files, and uploads `operations-handoff-package-<run_id>`.
- `../.github/workflows/enterprise-auth-smoke-ci.yml` - manual GitHub Actions workflow for target IdP/LDAP enterprise auth smoke. It is plan-only by default, requires fixed GitHub secrets for live target checks, and uploads `.osmu-run/latest-enterprise-auth-smoke.*`.
- `../.github/workflows/iam-rbac-finalizer-ci.yml` - manual GitHub Actions workflow for IAM/RBAC finalizer evidence. It can run focused backend RBAC tests on Java 17 and optionally collect live `kubectl auth can-i` evidence when `run_live=true` and `OSMU_KUBECONFIG_BASE64` is provided.
- `../.github/workflows/security-evidence-finalizer-ci.yml` - manual GitHub Actions workflow that downloads image signing and container security artifacts from previous workflow runs, runs `finalize-security-evidence.ps1`, and uploads promoted security evidence artifacts.
- `../scripts/verify-openapi-contract.ps1` - parse and verify the machine-readable MVP OpenAPI contract and frontend API function coverage.
- `../scripts/verify-iam-rbac-matrix.ps1` - verify the IAM/RBAC matrix against core backend/frontend policy contracts.
- `../scripts/verify-kubernetes-rbac-matrix.ps1` - verify Kubernetes ServiceAccount, token automount, and storage expansion runner RBAC hardening contracts.
- `../scripts/verify-storage-expansion-rbac-auth.ps1` - collect live `kubectl auth can-i` evidence for the storage expansion runner ServiceAccount after Kubernetes RBAC is applied.
- `../scripts/verify-storage-expansion-server-dry-run.ps1` - collect live MinIO Tenant CRD, existing Tenant, and server-side dry-run evidence for storage expansion manifests.
- `../scripts/finalize-storage-expansion.ps1` - one-command storage expansion finalization wrapper that runs RBAC authorization evidence, server-side dry-run evidence, optional backend dry-run/apply runner calls, and optional storage backend telemetry evidence recording with an explicit `-ConfirmApply` guard; supports `-PowerShellCommand` and records the selected command.
- `../scripts/verify-storage-expansion-finalizer.ps1` - self-test the storage expansion finalizer plan, apply guard, optional storage backend telemetry evidence link, and no-raw-admin-info evidence handoff.
- `../scripts/verify-kubernetes-ha-dr-readiness.ps1` - collect live Kubernetes HA/DR readiness evidence for backend/frontend replicas, StatefulSets, PodDisruptionBudgets, backup PVC/CronJobs, and restore Job server-side dry-run.
- `../scripts/run-kubernetes-backup-drill.ps1` - create one-off Kubernetes backup Jobs from the MariaDB/MinIO backup CronJobs, wait for completion, collect Job/Pod/log evidence, and write a backup drill report.
- `../scripts/prepare-kubernetes-restore-namespace.ps1` - render, dry-run, or apply a disposable Kubernetes restore target namespace and record namespace preparation evidence without copying secret values.
- `../scripts/verify-kubernetes-backup-artifacts.ps1` - run a read-only Kubernetes Job that checks restore PVC backup artifacts, metadata checksum, and MinIO mirror count/bytes before restore.
- `../scripts/run-kubernetes-restore-drill.ps1` - validate or run an isolated Kubernetes restore Job against a restore namespace and write restore drill evidence without copying secret values.
- `../scripts/run-kubernetes-dr-drill.ps1` - orchestrate the Kubernetes backup drill, optional DR bucket bootstrap, restore namespace preparation, optional DR bucket immutability preflight, artifact preflight, and restore drill sequence with a single wrapper evidence report.
- `../scripts/bootstrap-kubernetes-dr-bucket.ps1` - create or reuse an external S3-compatible DR bucket with object locking, versioning, and default retention, then write secret-free bootstrap evidence.
- `../scripts/verify-kubernetes-dr-bucket-immutability.ps1` - verify external DR bucket reachability, versioning, and default object-lock retention through `osmu-dr-transfer-secret` without copying secret values.
- `../scripts/transfer-kubernetes-backup-artifacts.ps1` - export/import a selected backup timestamp through external S3-compatible DR storage and write transfer evidence without copying secret values.
- `../scripts/verify-kubernetes-restore-smoke.ps1` - verify restored API health/login/bucket/object access plus optional real S3 client smoke and write restore smoke evidence.
- `../scripts/write-kubernetes-dr-evidence-request.ps1` - build or submit the admin restore evidence API request from Kubernetes DR wrapper evidence and artifact preflight logs.
- `../scripts/finalize-kubernetes-dr-drill.ps1` - one-command Kubernetes DR finalization wrapper that runs DR drill orchestration, restore smoke, and evidence request generation/submission while masking admin password values in reports; supports `-PowerShellCommand` and records the selected command.
- `../scripts/verify-k8s-manifests.ps1` - verify the Kubernetes draft manifest set, secret handling, backup resources, HA PodDisruptionBudgets, and topology spread controls.
- `../scripts/verify-mvp-release-artifacts.ps1` - check latest release JSON, durable gate report state, audit report, decision report, and release notes are synchronized.
- `../scripts/start-mvp-demo.ps1` - start the best available current-machine MVP demo: Docker full stack when Docker is available, Java backend prototype when JDK 17+ is available, or frontend mock fallback.
- `../scripts/stop-mvp-demo.ps1` - stop the demo started by `start-mvp-demo.ps1` using the recorded selected mode.
- `../scripts/start-local-demo.ps1` - start full Docker demo stack with MariaDB, MinIO, Backend, and Frontend; waits for health endpoints and prints URLs.
- `../scripts/seed-local-demo.ps1` - seed a running full Docker demo with sample org, users, buckets, objects, lifecycle rules, and access key.
- `../scripts/verify-local-demo.ps1` - verify a running seeded full Docker demo through portal bundle, REST API, permissions, lifecycle, and seeded S3 access key smoke.
- `../scripts/stop-local-demo.ps1` - stop the Docker demo stack and optionally remove MariaDB/MinIO volumes with `-ResetData`.
- `../scripts/start-local-prototype.ps1` - start Docker-free in-memory backend and frontend; uses the shared Java 17+ helper and fails fast when Java is missing or target ports are already occupied.
- `../scripts/verify-prototype-gate.ps1` - run the complete lightweight prototype gate in one command.
- `../scripts/verify-lightweight-prototype.ps1` - smoke test a running Docker-free prototype.
- `../scripts/seed-lightweight-demo.ps1` - seed a running Docker-free prototype with demo org, users, buckets, objects, lifecycle rules, and access key.
- `../scripts/verify-lightweight-demo.ps1` - verify seeded portal data, frontend bundle, scoped permissions, tags, lifecycle, access key inventory, and S3 SigV4 access with the seeded key.
- `../scripts/write-data-flow-storage-plan.ps1` - write target sizing and readiness evidence for future data-flow partition/time-series transition without storing object keys, raw event messages, or credentials.
- `../scripts/verify-data-flow-storage-plan.ps1` - self-test the data-flow storage plan writer, including plan-required, passed fixture, and credential-shaped input rejection cases.
- `../osmu-frontend/e2e/lightweight-demo.spec.js` - Browser E2E spec for stale session redirect, developer S3/API Key console, and admin storage portal click path. Run with `npm run test:e2e` from `osmu-frontend` after Playwright browsers are installed.
- `../osmu-frontend/playwright.config.js` - Playwright config. It reads `OSMU_PLAYWRIGHT_CHANNEL` so local runs can use installed Chrome or Edge when bundled Chromium download is unavailable.
- `../scripts/stop-local-prototype.ps1` - stop Docker-free prototype processes; use `-ForcePorts` to clean up stale child listeners on default ports.
- `../scripts/start-frontend-mock-demo.ps1` - start a Java-free frontend mock demo with Vite plus the Node mock API for UI/demo smoke; optional multipart threshold/part-size parameters support small Browser multipart fixtures without changing production defaults.
- `../scripts/verify-frontend-mock-demo.ps1` - start the frontend mock demo, reset mock API state, verify frontend shell, mock health, admin login, developer login/S3 config/access key flow, bucket/object flow, dashboard summary, and stop it.
- `../scripts/verify-browser-e2e-mock-demo.ps1` - start the frontend mock demo, reset mock API state, run Playwright Browser E2E against it, auto-select installed Chrome/Edge when `OSMU_PLAYWRIGHT_CHANNEL` is not set, optionally enable the small multipart pause/resume fixture with `-EnableMultipartFixture -TestGrep "pause and resume multipart"`, and stop the demo.
- `../scripts/stop-frontend-mock-demo.ps1` - stop frontend mock demo processes and optionally clear default ports with `-ForcePorts`.
- `../osmu-frontend/mock-api/server.mjs` - dependency-free Node mock API used by the Java/Docker-free frontend demo. `npm run mock:api:self-test` verifies its in-memory API fixtures, including the mock-only `POST /api/mock/reset` state reset endpoint.
- `../scripts/verify-browser-e2e-prototype.ps1` - start the Java in-memory backend and Vite frontend, run backend API smoke plus Playwright Browser E2E, auto-select installed Chrome/Edge when needed, and stop the prototype.
- `../scripts/verify-browser-e2e-local-demo.ps1` - start the full Docker local demo, seed demo data, verify REST/S3 demo smoke, run Playwright Browser E2E against the Docker frontend, auto-select installed Chrome/Edge when needed, and stop the Docker stack.
- `../scripts/verify-durable-demo-preflight.ps1` - check durable demo prerequisites without starting containers; writes `.osmu-run/latest-durable-demo-preflight.*` with Docker, Compose, Node/npm, and selected S3 client readiness.
- `../scripts/verify-durable-demo-gate.ps1` - strongest local MVP demo proof. It starts the full Docker local demo, runs Browser E2E, runs Docker integration smoke, runs real S3 client smoke through host or Dockerized clients, writes `.osmu-run/latest-durable-demo-gate.*`, and stops the stack.
- `../scripts/verify-mvp-demo-readiness.ps1` - one-command current-machine demo readiness gate. It accepts `-JavaHome <jdk17>` and `-S3Client <auto|aws|boto3|aws-js|mc|docker-mc|all>`, runs Node prerequisites, static/frontend checks, mock API self-test, frontend mock demo smoke, mock Browser E2E, durable demo preflight, backend Gradle tests when available, backend-backed prototype Browser E2E when Java is available, durable Docker/MariaDB/MinIO/Browser/S3 client gate when Docker daemon is available, and writes pending durable gates when proof is incomplete.
- `../scripts/verify-docker-integration.ps1` - full Docker integration smoke.
- `../scripts/verify-s3-client-smoke.ps1` - S3 client compatibility smoke, including built-in SigV4 probes for object tagging, range GET, conditional requests, CopyObject, bucket tagging, multi-delete, AWS CLI checksum option smoke when host `aws` is available, boto3 checksum option smoke when Python+boto3 is available, AWS SDK JavaScript checksum option smoke when Node.js with `@aws-sdk/client-s3` is available, AWS SDK Java checksum option smoke when `OSMU_AWS_SDK_JAVA_CLASSPATH` points to AWS SDK Java v2 jars, host MinIO Client, and Dockerized MinIO Client via `-Client docker-mc`.

## Worklogs

- `worklog/main/worklog-main.md` - main branch historical worklog.
- `worklog/codex/frontend-backend-mvp/worklog-codex-frontend-backend-mvp.md` - current Codex branch worklog.

## Current Stack

- Backend: Spring Boot
- Frontend: Vue + Vite
- Metadata DB: MariaDB
- Object storage: MinIO
- Local infra: Docker Compose
- Kubernetes draft: `infra/k8s`
- API surface: REST API + S3-compatible API

## Current Prototype Gate

- `powershell -ExecutionPolicy Bypass -File .\scripts\verify-local.ps1 -SkipDocker -JavaHome <jdk17>`
- `powershell -ExecutionPolicy Bypass -File .\scripts\verify-k8s-manifests.ps1`
- `powershell -ExecutionPolicy Bypass -File .\scripts\verify-durable-demo-gate.ps1` after Docker Desktop is running
- `powershell -ExecutionPolicy Bypass -File .\scripts\verify-browser-e2e-local-demo.ps1` after Docker Desktop is running
- `powershell -ExecutionPolicy Bypass -File .\scripts\verify-docker-integration.ps1` after Docker Desktop is running
