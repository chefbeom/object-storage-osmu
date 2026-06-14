# OSMU Secret And Certificate Rotation Policy Draft

This document defines the MVP pilot contract for rotating secrets and TLS certificates without committing secret material to the repository.

## Scope

The rotation policy covers:

- `OSMU_ADMIN_PASSWORD`
- `OSMU_JWT_SECRET`
- `OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY`
- `MARIADB_USER`
- `MARIADB_PASSWORD`
- `MARIADB_ROOT_PASSWORD`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`
- `osmu-tls` Kubernetes TLS Secret
- OSMU user access keys and MinIO provisioned S3 users/policies

## Storage Rules

- Do not commit real secrets to git.
- Do not write secrets to worklog, release reports, audit reports, screenshots, or logs.
- Local development may use `.env` files that are ignored by git.
- Kubernetes pilot deployments should use Kubernetes Secret, External Secrets, Sealed Secrets, or a customer secret manager.
- Helm `secrets.create` must remain `false` by default. Rendered Secret values are allowed only after all placeholders are replaced outside source control.

## Rotation Frequency

- TLS certificate: rotate before expiry; recommended automation through cert-manager or the customer certificate manager.
- Admin password: rotate before every shared demo or pilot handoff.
- JWT signing secret: rotate on environment bootstrap, suspected exposure, or planned maintenance window.
- Access key encryption key: avoid routine rotation in MVP; rotate only during a planned migration because existing encrypted SigV4 secrets must be re-issued or re-encrypted.
- MariaDB and MinIO root credentials: rotate before pilot handoff and after any suspected exposure.
- User access keys: rotate on user departure, scope reduction, suspected exposure, or customer policy interval.

## Rotation Triggers

Rotate immediately when:

- A secret appears in git, logs, screenshots, chat, ticket systems, or release artifacts.
- A user account is deactivated after privileged access.
- A bucket permission scope is reduced for a user with active access keys.
- A customer pilot environment changes owner or operator.
- TLS certificate issuer, domain, or ingress controller changes.

## Rotation Runbook

1. Create the replacement secret in the environment secret manager.
2. Apply the secret update to Kubernetes, Helm values, Docker `.env`, or the runtime platform outside git.
3. Restart or roll workloads that read the secret only at startup.
4. Revoke or re-issue dependent credentials where required.
5. Run the matching smoke checks:
   - `scripts\verify-prototype-prerequisites.ps1`
   - `scripts\verify-prototype-release.ps1`
   - `scripts\verify-s3-client-smoke.ps1` when `aws` or `mc` is available
6. Confirm release artifacts do not expose secret values.
7. Record only the rotation event, operator, timestamp, and affected secret name. Never record secret values.

## Special Cases

### JWT Signing Secret

Changing `OSMU_JWT_SECRET` invalidates existing access and refresh tokens. Rotate during a maintenance window and require users to log in again.

### Access Key Secret Encryption Key

Changing `OSMU_ACCESS_KEY_SECRET_ENCRYPTION_KEY` prevents decrypting existing SigV4 secret material unless a migration re-encrypts it. MVP-safe rotation is to revoke and re-issue affected access keys.

### MinIO Credentials

MinIO root credentials must not be used by applications after bootstrap. OSMU-generated access keys should have scoped bucket policies and should be revoked through OSMU metadata plus MinIO policy cleanup.

### TLS Certificate

The Kubernetes and Helm ingress drafts reference `osmu-tls`. The certificate issuer and renewal automation are environment-specific. Pilot readiness requires creating the TLS Secret and verifying HTTPS routing in the target cluster.

## Evidence

This policy is verified by:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-secret-rotation-policy.ps1
```

The verifier checks that the policy covers secret inventory, no-git storage rules, rotation triggers, runbook steps, JWT behavior, access key encryption key behavior, and TLS certificate handling.
