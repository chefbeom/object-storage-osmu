# Operations Readiness Dispatch Handoff

This handoff keeps the remaining operations-readiness work focused on object-storage operations evidence. It does not mark any pending gate as passed without target evidence, operator approval, workflow run ids, and imported artifacts.

## Current Gate State

- Latest readiness summary: passed=83 / pending=19 / total=102.
- Latest handoff result: blocked.
- Current bottleneck: resolve invocation blockers.
- Latest PR branch: codex/operations-readiness-9dedd532.
- Latest verified head before this handoff: f5c145770a47596d227711ff9e6ea65921dbe94d.
- Latest CI evidence before this handoff: Prototype CI #52 passed for f5c145770a47596d227711ff9e6ea65921dbe94d.

## Default-Branch Workflow Gate

GitHub workflow_dispatch requires the workflow file to exist on the repository default branch before dispatch. The following selected evidence workflows exist on the PR branch but were missing from origin/main in the latest dispatch preflight:

- action 8: manual-data-flow-query-retention-budget-evidence.yml
- action 14: manual-chargeback-closeout-evidence.yml
- action 16: manual-enterprise-auth-jit-rollback-evidence.yml
- action 18: manual-cluster-network-access-review-evidence.yml
- action 19: manual-helm-values-hardening-evidence.yml

Do not attempt to close those actions with local placeholder evidence. Merge or publish the workflow files to the default branch first, then rerun dispatch preflight.

## Required Operator Inputs

The remaining 19 actions are blocked by some combination of these requirements:

- explicit operator approval via -ConfirmOperatorApproval
- kubeconfig secret readiness confirmation via -KubeconfigSecretConfirmed for live Kubernetes actions
- concrete environment, cluster, operator, change, evidence reference, timestamp, run-id, and base64 JSON payload values
- successful image signing and container security workflow runs before the security evidence finalizer
- artifact collection/import after all workflow run ids and artifact names are known

The source of truth for exact placeholders is .osmu-run/latest-operations-invocation-unblock-plan.md.

## Execution Order

1. Merge or publish the five missing workflow_dispatch files to the default branch.
2. Regenerate readiness and evidence planning reports:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-readiness.ps1
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-evidence-plan.ps1 -GitHubRepository chefbeom/object-storage-osmu
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1 -ActionOrder 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-invocation-unblock-plan.ps1
   ```

3. Fill all placeholders and confirmations from the unblock plan. Keep values concrete and operator-approved.
4. Rerun dispatch preflight before any live dispatch:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-dispatch-preflight.ps1 -ActionOrder 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19 -GitHubRepository chefbeom/object-storage-osmu -GitHubRef main -CheckGitHubCli
   ```

5. Dispatch only actions that preflight marks ready.
6. Collect run ids after workflow completion:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-operations-workflow-run-id-plan.ps1 -UseGitHubApi -GitHubRepository chefbeom/object-storage-osmu -Branch codex/operations-readiness-9dedd532 -Limit 20 -ImageSigningVersion v0.1.0-rc.1
   ```

7. Regenerate artifact collection, import artifacts, and finalize readiness:

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

## Completion Criteria

The goal is complete only when the regenerated operations readiness report is ready/passed with pending=0 and the finalizer/convergence reports prove no failed imports, no stale reports, and no remaining gaps. A green prototype CI check alone is not sufficient for operations readiness completion.
