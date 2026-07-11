package com.example.osmu.storagelayout;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storagelayout.repository.StorageLayoutPlanRepository;
import com.example.osmu.storageprofile.StorageProfileCode;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.springframework.stereotype.Service;

@Service
public class StorageLayoutService {

    private static final long GIB = 1024L * 1024L * 1024L;
    private static final int DEFAULT_LIST_LIMIT = 50;
    private static final int MAX_LIST_LIMIT = 200;
    private static final int MAX_SERVER_COUNT = 32;
    private static final int MAX_VOLUMES_PER_SERVER = 16;
    private static final long MIN_VOLUME_SIZE_GIB = 10L;
    private static final long MAX_VOLUME_SIZE_GIB = 1024L * 1024L;
    private static final int MAX_REASON_LENGTH = 512;
    private static final Set<String> PLAN_STATUSES = Set.of("PLANNED", "APPROVED", "REJECTED");
    private static final Set<String> ADMIN_STATUSES = Set.of("APPROVED", "REJECTED");

    private final StorageLayoutPlanRepository repository;

    public StorageLayoutService(StorageLayoutPlanRepository repository) {
        this.repository = repository;
    }

    public List<StorageLayoutDefinition> capabilities(AuthenticatedUser user) {
        requireAdmin(user);
        return StorageLayoutCatalog.list();
    }

    public ListResponse<StorageLayoutPlanResponse> list(
            AuthenticatedUser user,
            String status,
            String cursor,
            Integer limit
    ) {
        requireAdmin(user);
        int pageSize = normalizeListLimit(limit);
        List<StorageLayoutPlanRecord> matchedPlans = repository.findPage(
                normalizeListStatuses(status),
                parseListCursor(cursor),
                pageSize + 1
        );
        boolean hasNextPage = matchedPlans.size() > pageSize;
        List<StorageLayoutPlanRecord> page = hasNextPage
                ? matchedPlans.subList(0, pageSize)
                : matchedPlans;
        String nextCursor = hasNextPage ? String.valueOf(page.get(page.size() - 1).id()) : null;
        return ListResponse.of(page.stream().map(this::response).toList(), nextCursor);
    }

    public StorageLayoutPlanResponse create(AuthenticatedUser user, StorageLayoutPlanPayload payload) {
        requireAdmin(user);
        StorageLayoutCode layoutCode = StorageLayoutCode.parse(payload == null ? null : payload.layoutCode());
        String storageClassName = normalizeStorageClassName(payload == null ? null : payload.storageClassName());
        int serverCount = normalizeCount(payload == null ? null : payload.serverCount(), 4, MAX_SERVER_COUNT, "Server count");
        int volumesPerServer = normalizeCount(
                payload == null ? null : payload.volumesPerServer(),
                1,
                MAX_VOLUMES_PER_SERVER,
                "Volumes per server"
        );
        long volumeSizeGiB = normalizeVolumeSize(payload == null ? null : payload.volumeSizeGiB());
        int pvcCount = Math.multiplyExact(serverCount, volumesPerServer);
        validateTopology(layoutCode, pvcCount);

        OffsetDateTime now = OffsetDateTime.now();
        StorageLayoutPlanRecord saved = repository.save(new StorageLayoutPlanRecord(
                repository.nextId(),
                layoutCode.name(),
                storageClassName,
                serverCount,
                volumesPerServer,
                volumeSizeGiB,
                "PLANNED",
                normalizeOptionalText(payload == null ? null : payload.reason()),
                user.loginId(),
                null,
                null,
                null,
                null,
                null,
                now,
                now
        ));
        return response(saved);
    }

    public StorageLayoutPlanResponse updateStatus(
            AuthenticatedUser user,
            long planId,
            StorageLayoutStatusRequest request
    ) {
        requireAdmin(user);
        StorageLayoutPlanRecord existing = requirePlan(planId);
        if (!"PLANNED".equals(existing.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage layout plan status can change only from PLANNED.");
        }
        String status = normalizeAdminStatus(request == null ? null : request.status());
        if ("APPROVED".equals(status) && existing.simulatedAt() == null) {
            throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    "Storage layout plan must complete simulation before approval."
            );
        }
        OffsetDateTime now = OffsetDateTime.now();
        StorageLayoutPlanRecord saved = repository.save(new StorageLayoutPlanRecord(
                existing.id(),
                existing.layoutCode(),
                existing.storageClassName(),
                existing.serverCount(),
                existing.volumesPerServer(),
                existing.volumeSizeGiB(),
                status,
                existing.reason(),
                existing.createdBy(),
                "APPROVED".equals(status) ? user.loginId() : null,
                "APPROVED".equals(status) ? now : null,
                existing.simulatedBy(),
                existing.simulatedAt(),
                normalizeOptionalText(request == null ? null : request.adminNote()),
                existing.createdAt(),
                now
        ));
        return response(saved);
    }

    public StorageLayoutSimulationResponse simulate(AuthenticatedUser user, long planId) {
        requireAdmin(user);
        StorageLayoutPlanRecord existing = requirePlan(planId);
        if ("REJECTED".equals(existing.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Rejected storage layout plans cannot be simulated.");
        }
        OffsetDateTime now = OffsetDateTime.now();
        StorageLayoutPlanRecord saved = repository.save(new StorageLayoutPlanRecord(
                existing.id(),
                existing.layoutCode(),
                existing.storageClassName(),
                existing.serverCount(),
                existing.volumesPerServer(),
                existing.volumeSizeGiB(),
                existing.status(),
                existing.reason(),
                existing.createdBy(),
                existing.approvedBy(),
                existing.approvedAt(),
                user.loginId(),
                now,
                existing.adminNote(),
                existing.createdAt(),
                now
        ));
        StorageLayoutPlanResponse plan = response(saved);
        return new StorageLayoutSimulationResponse(
                plan,
                "DEVELOPMENT_SIMULATION",
                manifestPreview(saved),
                "No Kubernetes resources were created. Validate the StorageClass and MinIO Operator Tenant in the target cluster before apply."
        );
    }

    public StorageLayoutPlanResponse requireApplicablePlan(
            AuthenticatedUser user,
            long planId,
            StorageProfileCode profileCode
    ) {
        requireAdmin(user);
        StorageLayoutPlanRecord plan = requirePlan(planId);
        if (!"APPROVED".equals(plan.status()) || plan.simulatedAt() == null) {
            throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    "Storage profile apply requires an approved, simulated storage layout plan."
            );
        }
        StorageLayoutCode layoutCode = StorageLayoutCode.parse(plan.layoutCode());
        if (!compatibleLayouts(profileCode).contains(layoutCode)) {
            throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    profileCode.name() + " profile is not compatible with " + layoutCode.name() + "."
            );
        }
        return response(plan);
    }

    private StorageLayoutPlanResponse response(StorageLayoutPlanRecord record) {
        StorageLayoutCode layoutCode = StorageLayoutCode.parse(record.layoutCode());
        int pvcCount = Math.multiplyExact(record.serverCount(), record.volumesPerServer());
        long rawCapacityBytes = Math.multiplyExact(Math.multiplyExact((long) pvcCount, record.volumeSizeGiB()), GIB);
        return new StorageLayoutPlanResponse(
                record.id(),
                StorageLayoutCatalog.definition(layoutCode),
                poolName(record.id()),
                record.storageClassName(),
                record.serverCount(),
                record.volumesPerServer(),
                pvcCount,
                record.volumeSizeGiB(),
                rawCapacityBytes,
                StorageLayoutCatalog.estimatedUsableCapacityBytes(layoutCode, pvcCount, rawCapacityBytes),
                record.status(),
                true,
                preflight(record, layoutCode, pvcCount),
                record.reason(),
                record.createdBy(),
                record.approvedBy(),
                record.approvedAt(),
                record.simulatedBy(),
                record.simulatedAt(),
                record.adminNote(),
                record.createdAt(),
                record.updatedAt()
        );
    }

    private StorageLayoutPreflightResponse preflight(
            StorageLayoutPlanRecord record,
            StorageLayoutCode layoutCode,
            int pvcCount
    ) {
        StorageLayoutDefinition definition = StorageLayoutCatalog.definition(layoutCode);
        String topologyDetail = pvcCount + " PVCs meet the " + definition.code()
                + " minimum of " + definition.minimumPvcCount()
                + (definition.requiresEvenPvcCount() ? " and the even-device requirement." : ".");
        return new StorageLayoutPreflightResponse(
                "SIMULATION_READY",
                true,
                List.of(
                        new StorageLayoutPreflightCheck(
                                "LAYOUT_POLICY",
                                "PASS",
                                definition.name() + " is an intent mapped to PVC and storage backend capabilities, not a node-local RAID command."
                        ),
                        new StorageLayoutPreflightCheck("PVC_TOPOLOGY", "PASS", topologyDetail),
                        new StorageLayoutPreflightCheck(
                                "STORAGE_CLASS",
                                "UNVERIFIED",
                                "StorageClass " + record.storageClassName() + " is recorded and must be validated in the target cluster."
                        ),
                        new StorageLayoutPreflightCheck(
                                "MINIO_POOL",
                                "PLANNED",
                                "Pool " + poolName(record.id()) + " is planned; MinIO Tenant changes remain disabled in development."
                        ),
                        new StorageLayoutPreflightCheck(
                                "CLUSTER_MUTATION",
                                "SIMULATED",
                                "This endpoint never creates PVCs, changes StorageClasses, or applies a MinIO Tenant."
                        )
                )
        );
    }

    private String manifestPreview(StorageLayoutPlanRecord record) {
        return """
                # Development simulation only. Do not apply this preview directly.
                apiVersion: osmu.example/v1alpha1
                kind: StorageLayoutPlan
                metadata:
                  name: %s
                spec:
                  layout: %s
                  storageClassName: %s
                  pvcTopology:
                    servers: %d
                    volumesPerServer: %d
                    volumeSizeGiB: %d
                  minio:
                    poolName: %s
                    clusterMutation: disabled
                """.formatted(
                poolName(record.id()),
                record.layoutCode(),
                record.storageClassName(),
                record.serverCount(),
                record.volumesPerServer(),
                record.volumeSizeGiB(),
                poolName(record.id())
        );
    }

    private StorageLayoutPlanRecord requirePlan(long planId) {
        return repository.findById(planId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Storage layout plan not found."));
    }

    private int normalizeCount(Integer rawValue, int defaultValue, int maximum, String label) {
        int value = rawValue == null ? defaultValue : rawValue;
        if (value < 1 || value > maximum) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, label + " must be between 1 and " + maximum + ".");
        }
        return value;
    }

    private long normalizeVolumeSize(Long rawValue) {
        long value = rawValue == null ? 1024L : rawValue;
        if (value < MIN_VOLUME_SIZE_GIB || value > MAX_VOLUME_SIZE_GIB) {
            throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    "PVC volume size must be between " + MIN_VOLUME_SIZE_GIB + " and " + MAX_VOLUME_SIZE_GIB + " GiB."
            );
        }
        return value;
    }

    private void validateTopology(StorageLayoutCode layoutCode, int pvcCount) {
        StorageLayoutDefinition definition = StorageLayoutCatalog.definition(layoutCode);
        if (pvcCount < definition.minimumPvcCount()) {
            throw new ApiException(
                    ApiErrorCode.VALIDATION_ERROR,
                    definition.code() + " requires at least " + definition.minimumPvcCount() + " PVCs."
            );
        }
        if (definition.requiresEvenPvcCount() && pvcCount % 2 != 0) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, definition.code() + " requires an even PVC count.");
        }
    }

    private String normalizeStorageClassName(String rawValue) {
        String value = rawValue == null ? "" : rawValue.trim();
        if (!value.matches("[a-z0-9][a-z0-9.-]{0,62}")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "StorageClass name is invalid.");
        }
        return value;
    }

    private String normalizeAdminStatus(String rawValue) {
        String value = rawValue == null ? "" : rawValue.trim().toUpperCase(Locale.ROOT);
        if (!ADMIN_STATUSES.contains(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage layout plan status must be APPROVED or REJECTED.");
        }
        return value;
    }

    private List<String> normalizeListStatuses(String rawValue) {
        String value = rawValue == null ? "OPEN" : rawValue.trim().toUpperCase(Locale.ROOT);
        if (value.isBlank() || "OPEN".equals(value)) {
            return List.of("PLANNED", "APPROVED");
        }
        if ("ALL".equals(value)) {
            return List.of();
        }
        if (!PLAN_STATUSES.contains(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage layout plan status filter is invalid.");
        }
        return List.of(value);
    }

    private int normalizeListLimit(Integer limit) {
        if (limit == null) {
            return DEFAULT_LIST_LIMIT;
        }
        if (limit < 1 || limit > MAX_LIST_LIMIT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage layout page limit must be between 1 and 200.");
        }
        return limit;
    }

    private Long parseListCursor(String rawValue) {
        if (rawValue == null || rawValue.isBlank()) {
            return null;
        }
        try {
            long value = Long.parseLong(rawValue.trim());
            if (value < 1) {
                throw new NumberFormatException("cursor must be positive");
            }
            return value;
        } catch (NumberFormatException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage layout page cursor is invalid.");
        }
    }

    private String normalizeOptionalText(String rawValue) {
        String value = rawValue == null ? "" : rawValue.trim();
        if (value.length() > MAX_REASON_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Storage layout text is too long.");
        }
        return value;
    }

    private String poolName(long id) {
        return "storage-layout-" + id;
    }

    private Set<StorageLayoutCode> compatibleLayouts(StorageProfileCode profileCode) {
        return switch (profileCode) {
            case PERFORMANCE -> Set.of(StorageLayoutCode.JBOD, StorageLayoutCode.RAID0);
            case STANDARD -> Set.of(StorageLayoutCode.RAID5, StorageLayoutCode.RAID10);
            case DURABLE -> Set.of(StorageLayoutCode.RAID1, StorageLayoutCode.RAID6);
        };
    }

    private void requireAdmin(AuthenticatedUser user) {
        if (!user.isAdmin()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Storage layout management requires ADMIN role.");
        }
    }
}
