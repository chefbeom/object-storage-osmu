# Operations Readiness Dispatch Handoff

This handoff keeps the remaining operations-readiness work focused on object-storage operations evidence. It does not mark any pending gate as passed without target evidence, operator approval, workflow run ids, and imported artifacts.

## Current Gate State

- Latest readiness summary: passed=83 / pending=19 / total=102.
- Latest handoff result: blocked.
- Current bottleneck: resolve invocation blockers; no default-branch workflow files are missing.
- Current main HEAD: 9c9a7a2b2152f6a7ea9546a22306929ab6943fde.
- PR #1 merge commit: 81acaf4e3c44ee3dc2014f3429f585ac7defaedd.
- PR #1 is merged into main.
- Prototype CI #54 passed on 13a3402facf92349e409d91d66961b77622fe7fd before merge.
- The dispatch preflight, workflow run-id plan, artifact collection plan, evidence handoff, and convergence reports were regenerated after pushing 9c9a7a2 to main.

## Default-Branch Workflow Gate

Resolved. The workflow_dispatch files that were previously missing from origin/main are now present on main:

- action 8: manual-data-flow-query-retention-budget-evidence.yml
- action 14: manual-chargeback-closeout-evidence.yml
- action 16: manual-enterprise-auth-jit-rollback-evidence.yml
- action 18: manual-cluster-network-access-review-evidence.yml
- action 19: manual-helm-values-hardening-evidence.yml

The latest dispatch preflight confirmed defaultBranchWorkflowMissingCount=0. Do not close these actions with local placeholder evidence; dispatch the workflows with concrete target evidence values and import their artifacts.

## Ready Subset After Operator Confirmation

With explicit operator approval, OSMU_KUBECONFIG_BASE64 readiness confirmation, and required GitHub secrets configured, actions 1, 2, and 5 have no remaining workflow input placeholders. The current-head preflight for this subset produced readyActionCount=3 and blockedActionCount=0, but its overall result remains action-required on this machine because GitHub CLI is not installed and GH_TOKEN/GITHUB_TOKEN is not set.

Plan-only command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2,5 -KubeconfigSecretConfirmed -ConfirmOperatorApproval
```

Planned workflow dispatch commands:

```powershell
gh workflow run storage-expansion-finalizer-ci.yml -f run_live=true -f namespace=osmu -f tenant_name=osmu-minio -f manifest_path=./infra/k8s/examples/minio-tenant-pool-expansion.example.yaml -f impersonate_runner=true
gh workflow run kubernetes-ha-dr-readiness-ci.yml -f run_live=true -f namespace=osmu -f restore_manifest_path=./infra/k8s/examples/restore-from-backup.example.yaml
gh workflow run image-publish-sign-ci.yml -f version=v0.1.0-rc.1 -f publish=true
```

Do not run this subset until the operator confirms live Kubernetes access, image publishing/signing approval, and the required GitHub secrets.

## Required Operator Inputs

The remaining 19 actions are blocked by some combination of these requirements:

- explicit operator approval via -ConfirmOperatorApproval
- kubeconfig secret readiness confirmation via -KubeconfigSecretConfirmed for live Kubernetes actions
- concrete environment, cluster, operator, change, evidence reference, timestamp, run-id, and base64 JSON payload values
- successful image signing and container security workflow runs before the security evidence finalizer
- artifact collection/import after all workflow run ids and artifact names are known

The source of truth for exact placeholders is .osmu-run/latest-operations-invocation-unblock-plan.md.

For operator data collection and manual workflow dispatch, generate the expanded worksheet:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-operator-input-worksheet.ps1
```

The worksheet writes JSON, Markdown, and CSV to `.osmu-run/latest-operations-operator-input-worksheet.*`. It expands repeated placeholders such as `<iso-time>`, `<ref>`, `<ms>`, and `<n>` into workflow-input-level rows so operators can provide distinct start/end timestamps, evidence refs, p95/p99 values, and per-metric counts without reusing one placeholder value accidentally. It is collection guidance only; it does not mark readiness evidence as passed.

## Execution Order

1. Confirm operator approval and GitHub secret readiness for the selected action subset.
2. Rerun dispatch preflight before any live dispatch:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-dispatch-preflight.ps1 -ActionOrder 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19 -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -CheckGitHubCli
   ```

3. Dispatch only actions that preflight marks ready.
4. Collect run ids after workflow completion:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch main -Limit 20 -ImageSigningVersion v0.1.0-rc.1
   ```

5. Regenerate artifact collection, import artifacts, and finalize readiness:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-artifact-collection-plan.ps1 -ImageSigningVersion v0.1.0-rc.1
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\import-operations-readiness-artifacts.ps1
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\finalize-operations-readiness.ps1
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness-convergence.ps1
   ```

## Security Evidence Chain

Run and collect these in order:

1. image-publish-sign-ci.yml with version v0.1.0-rc.1 and publish=true when the operator approves publishing/signing.
2. container-security-ci.yml.
3. security-evidence-finalizer-ci.yml with both source run ids and artifact names.
4. operations-readiness-artifact-finalizer-ci.yml or local artifact import.
5. finalize-operations-readiness.ps1.

Expected artifact names must match the commit used by the workflow run. Recompute them from the latest workflow run-id and artifact collection plans after dispatch; do not reuse stale artifact names from older commits.

Current main-head artifact hints:

- image signing source: `osmu-image-signing-v0.1.0-rc.1-9c9a7a2b2152f6a7ea9546a22306929ab6943fde`
- container security source: `osmu-container-security-9c9a7a2b2152f6a7ea9546a22306929ab6943fde`

## Completion Criteria

The goal is complete only when the regenerated operations readiness report is ready/passed with pending=0 and the finalizer/convergence reports prove no failed imports, no stale reports, and no remaining gaps. A green prototype CI check alone is not sufficient for operations readiness completion.
