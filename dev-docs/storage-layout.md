# OSMU Storage Layout Design

## Scope

Storage Layout is the administrator control plane for Kubernetes PVC topology and a planned MinIO pool handoff. It supports JBOD, RAID0-like, RAID1-like, RAID5-like, RAID6-like, and RAID10-like intent records. The application never runs node-local RAID commands and it does not configure raw disks inside a normal application Pod.

## Backend Boundary

The target storage stack is:

physical disks -> CSI StorageClass -> PersistentVolume -> PVC -> MinIO Tenant Pool -> OSMU control plane

A StorageClass owns physical durability and failure-domain behavior. MinIO owns distributed object placement and erasure coding. OSMU records the requested layout, validates static PVC topology, records approval and simulation history, and produces a non-applicable YAML preview.

## Layout Catalog

| Layout | Minimum PVCs | Estimate | Risk |
| --- | ---: | --- | --- |
| JBOD | 1 | Raw capacity | High |
| RAID0-like | 2 | Raw capacity | High |
| RAID1-like | 2 and even | Half raw capacity | Low |
| RAID5-like | 3 | Raw minus one PVC share | Medium |
| RAID6-like | 4 | Raw minus two PVC shares | Low |
| RAID10-like | 4 and even | Half raw capacity | Low |

The estimates are planning values only. They do not replace CSI replication, MinIO erasure coding, capacity reserve, or target-cluster validation.

## Lifecycle

1. An administrator creates a PLANNED record with a layout, StorageClass, server count, volumes per server, PVC size, and reason.
2. The service calculates total PVC count and theoretical capacity, then returns simulation-only preflight checks.
3. An administrator APPROVES or REJECTS the plan.
4. A non-rejected plan can be simulated. Simulation records who ran it and returns a YAML preview but does not create PVCs or apply MinIO resources.
5. A future target-cluster driver may consume an APPROVED plan only after StorageClass capability, MinIO Operator Tenant schema, topology, quota, data migration, and rollback evidence are present.

## Safety Rules

- Existing object data is never converted in place. A future apply path must create a new pool, copy and verify data, then cut over.
- RAID2, RAID3, RAID4, RAID7, RAID8, and RAID9 are not product-supported layout choices.
- JBOD means independent PVC intent in this scope. Concatenated linear volumes are not created.
- Development simulation is intentionally non-destructive and must remain valid without a kubeconfig.