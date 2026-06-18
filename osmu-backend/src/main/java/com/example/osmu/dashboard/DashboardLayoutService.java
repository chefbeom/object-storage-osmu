package com.example.osmu.dashboard;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.dashboard.repository.DashboardLayoutDefaultRepository;
import com.example.osmu.dashboard.repository.DashboardLayoutPresetRepository;
import com.example.osmu.dashboard.repository.DashboardLayoutRepository;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Stream;
import org.springframework.stereotype.Service;

@Service
public class DashboardLayoutService {

    private static final String PRESET_EXPORT_FORMAT_VERSION = "osmu.dashboard-preset.v1";
    private static final String PRESET_BUNDLE_EXPORT_FORMAT_VERSION = "osmu.dashboard-preset-bundle.v1";
    private static final String LAYOUT_SCHEMA_VERSION = "osmu.dashboard-layout.v1";
    private static final int MAX_WIDGETS = 30;
    private static final int MAX_ID_LENGTH = 64;
    private static final int MAX_SCOPE_LENGTH = 64;
    private static final int MAX_PRESET_NAME_LENGTH = 120;
    private static final int MAX_PRESET_DESCRIPTION_LENGTH = 500;
    private static final int MAX_PRESET_BUNDLE_SIZE = 50;
    private static final Set<String> ALLOWED_DEFAULT_TARGET_TYPES = Set.of("ROLE", "ORGANIZATION");
    private static final Set<String> ALLOWED_DEFAULT_ROLE_TARGETS = Set.of("ADMIN", "ORG_ADMIN", "USER");
    private static final Set<String> ALLOWED_WIDGET_SIZES = Set.of("compact", "normal", "wide");
    private static final List<String> WIDGET_SECTION_ORDER = List.of("overview", "operations", "governance");
    private static final Set<String> ALLOWED_WIDGET_SECTIONS = Set.copyOf(WIDGET_SECTION_ORDER);
    private static final Set<String> ALLOWED_WIDGET_OPTION_KEYS = Set.of("tone", "refreshInterval");
    private static final List<String> WIDGET_TONE_VALUES = List.of("default", "focus", "muted");
    private static final Set<String> ALLOWED_WIDGET_TONES = Set.copyOf(WIDGET_TONE_VALUES);
    private static final List<String> WIDGET_REFRESH_INTERVAL_VALUES = List.of("manual", "30s", "60s", "5m", "15m");
    private static final Set<String> ALLOWED_WIDGET_REFRESH_INTERVALS = Set.copyOf(WIDGET_REFRESH_INTERVAL_VALUES);
    private static final List<DashboardWidgetConfigOption> DEFAULT_WIDGET_CONFIG_OPTIONS = List.of(
            new DashboardWidgetConfigOption("tone", "Tone", "select", WIDGET_TONE_VALUES, "default"),
            new DashboardWidgetConfigOption("refreshInterval", "Refresh", "select", WIDGET_REFRESH_INTERVAL_VALUES, "manual")
    );
    private static final List<DashboardWidgetCatalogItem> WIDGET_CATALOG = List.of(
            widget("capacity", "스토리지 사용률", "Used capacity against allocated storage quota.", "STORAGE", false),
            widget("remaining", "남은 용량", "Remaining allocated capacity across buckets.", "STORAGE", false),
            widget("buckets", "버킷 현황", "Bucket count and selected bucket context.", "STORAGE", false),
            widget("objects", "오브젝트 현황", "Object count and active/trash explorer state.", "OBJECTS", false),
            widget("health", "서비스 상태", "Backend, database, and object storage health.", "OPERATIONS", false),
            widget("runtime", "런타임 엔진", "Metadata, object storage, and access key provisioner modes.", "OPERATIONS", false),
            widget("readiness", "데모 준비도", "Current deployment/demo readiness blockers and warnings.", "OPERATIONS", false),
            widget("backup", "백업 준비도", "Backup/restore readiness and RPO/RTO contract.", "OPERATIONS", false),
            widget("io", "데이터 입출력", "Current upload progress and I/O status.", "OBJECTS", false),
            widget("requests", "요청/감사 현황", "Recent request and audit event count.", "AUDIT", true),
            widget("sharing", "공유 링크 현황", "Temporary object share link activity.", "SHARING", true),
            widget("quota", "쿼터 정책 경보", "Quota policy warning and exhausted target count.", "GOVERNANCE", true),
            widget("access-keys", "Access Key 운영", "Active S3-compatible access key inventory and provisioner state.", "SECURITY", false),
            widget("identity", "사용자/조직 현황", "User and organization inventory for operators.", "IDENTITY", true),
            widget("lifecycle", "Lifecycle 규칙", "Object lifecycle rules and conflict analysis.", "GOVERNANCE", true),
            widget("selected", "선택 워크스페이스", "Selected bucket and next recommended action.", "WORKSPACE", false),
            widget("retention", "보존 정책", "Trash retention policy and purge counters.", "GOVERNANCE", true)
    );
    private static final List<DashboardWidgetCatalogItem> EFFECTIVE_WIDGET_CATALOG = Stream.concat(
            WIDGET_CATALOG.stream(),
            Stream.of(
                    widget("execution-retention", "Execution Log Retention", "Storage expansion execution output retention status.", "GOVERNANCE", true),
                    widget("storage-expansion", "Storage Expansion", "Storage expansion request and execution status.", "OPERATIONS", true)
            )
    ).toList();
    private static final Set<String> ALLOWED_WIDGET_IDS = EFFECTIVE_WIDGET_CATALOG.stream()
            .map(DashboardWidgetCatalogItem::id)
            .collect(java.util.stream.Collectors.toUnmodifiableSet());
    private static final Map<String, DashboardWidgetCatalogItem> WIDGET_CATALOG_BY_ID = EFFECTIVE_WIDGET_CATALOG.stream()
            .collect(java.util.stream.Collectors.toUnmodifiableMap(DashboardWidgetCatalogItem::id, item -> item));
    private static final List<DashboardLayoutPresetResponse> BUILT_IN_PRESETS = List.of(
            new DashboardLayoutPresetResponse(
                    "operations",
                    "Operations",
                    "General storage operations view with capacity, health, activity, sharing, quota, access keys, lifecycle, and selected workspace.",
                    List.of(
                            new DashboardWidgetLayout("capacity", true, "wide"),
                            new DashboardWidgetLayout("health", true, "normal"),
                            new DashboardWidgetLayout("runtime", true, "normal"),
                            new DashboardWidgetLayout("readiness", true, "wide"),
                            new DashboardWidgetLayout("backup", true, "normal"),
                            new DashboardWidgetLayout("io", true, "normal"),
                            new DashboardWidgetLayout("requests", true, "normal"),
                            new DashboardWidgetLayout("sharing", true, "normal"),
                            new DashboardWidgetLayout("quota", true, "normal"),
                            new DashboardWidgetLayout("access-keys", true, "normal"),
                            new DashboardWidgetLayout("lifecycle", true, "normal"),
                            new DashboardWidgetLayout("execution-retention", true, "normal"),
                            new DashboardWidgetLayout("storage-expansion", true, "normal"),
                            new DashboardWidgetLayout("selected", true, "normal")
                    ),
                    false
            ),
            new DashboardLayoutPresetResponse(
                    "compact",
                    "Compact",
                    "Dense view for small screens or NOC displays.",
                    List.of(
                            new DashboardWidgetLayout("capacity", true, "normal"),
                            new DashboardWidgetLayout("health", true, "compact"),
                            new DashboardWidgetLayout("runtime", true, "compact"),
                            new DashboardWidgetLayout("io", true, "compact"),
                            new DashboardWidgetLayout("requests", true, "compact"),
                            new DashboardWidgetLayout("access-keys", true, "compact"),
                            new DashboardWidgetLayout("selected", true, "compact")
                    ),
                    false
            ),
            new DashboardLayoutPresetResponse(
                    "admin",
                    "Admin Focus",
                    "Admin-oriented view for readiness, backup, quota, sharing, and audit activity.",
                    List.of(
                            new DashboardWidgetLayout("readiness", true, "wide"),
                            new DashboardWidgetLayout("backup", true, "wide"),
                            new DashboardWidgetLayout("quota", true, "normal"),
                            new DashboardWidgetLayout("sharing", true, "normal"),
                            new DashboardWidgetLayout("requests", true, "normal"),
                            new DashboardWidgetLayout("access-keys", true, "normal"),
                            new DashboardWidgetLayout("identity", true, "normal"),
                            new DashboardWidgetLayout("lifecycle", true, "normal"),
                            new DashboardWidgetLayout("execution-retention", true, "normal"),
                            new DashboardWidgetLayout("storage-expansion", true, "normal"),
                            new DashboardWidgetLayout("health", true, "normal"),
                            new DashboardWidgetLayout("runtime", true, "normal")
                    ),
                    false
            ),
            new DashboardLayoutPresetResponse(
                    "executive",
                    "Executive",
                    "High-level capacity, readiness, backup, sharing, and quota view for leadership reviews.",
                    List.of(
                            new DashboardWidgetLayout("capacity", true, "wide", "overview", Map.of("tone", "focus")),
                            new DashboardWidgetLayout("remaining", true, "normal", "overview"),
                            new DashboardWidgetLayout("buckets", true, "normal", "overview"),
                            new DashboardWidgetLayout("readiness", true, "wide", "operations"),
                            new DashboardWidgetLayout("backup", true, "normal", "operations"),
                            new DashboardWidgetLayout("sharing", true, "normal", "governance"),
                            new DashboardWidgetLayout("quota", true, "normal", "governance")
                    ),
                    List.of(
                            new DashboardSectionLayout("overview", false),
                            new DashboardSectionLayout("operations", false),
                            new DashboardSectionLayout("governance", false)
                    ),
                    false
            ),
            new DashboardLayoutPresetResponse(
                    "storage-ops",
                    "Storage Ops",
                    "Operational storage view for runtime health, data flow, retention, lifecycle, and expansion work.",
                    List.of(
                            new DashboardWidgetLayout("capacity", true, "wide", "overview"),
                            new DashboardWidgetLayout("objects", true, "normal", "overview"),
                            new DashboardWidgetLayout("io", true, "normal", "operations", Map.of("tone", "focus")),
                            new DashboardWidgetLayout("health", true, "normal", "operations"),
                            new DashboardWidgetLayout("runtime", true, "normal", "operations"),
                            new DashboardWidgetLayout("readiness", true, "wide", "operations"),
                            new DashboardWidgetLayout("backup", true, "normal", "operations"),
                            new DashboardWidgetLayout("lifecycle", true, "normal", "governance"),
                            new DashboardWidgetLayout("retention", true, "normal", "governance"),
                            new DashboardWidgetLayout("execution-retention", true, "normal", "governance"),
                            new DashboardWidgetLayout("storage-expansion", true, "normal", "operations"),
                            new DashboardWidgetLayout("selected", true, "normal", "overview")
                    ),
                    List.of(
                            new DashboardSectionLayout("overview", false),
                            new DashboardSectionLayout("operations", false),
                            new DashboardSectionLayout("governance", false)
                    ),
                    false
            ),
            new DashboardLayoutPresetResponse(
                    "security-audit",
                    "Security / Audit",
                    "Security and audit view for access keys, identity, request activity, lifecycle, and readiness controls.",
                    List.of(
                            new DashboardWidgetLayout("access-keys", true, "wide", "governance", Map.of("tone", "focus")),
                            new DashboardWidgetLayout("identity", true, "normal", "governance"),
                            new DashboardWidgetLayout("requests", true, "normal", "governance"),
                            new DashboardWidgetLayout("readiness", true, "wide", "operations"),
                            new DashboardWidgetLayout("backup", true, "normal", "operations"),
                            new DashboardWidgetLayout("quota", true, "normal", "governance"),
                            new DashboardWidgetLayout("sharing", true, "normal", "governance"),
                            new DashboardWidgetLayout("lifecycle", true, "normal", "governance"),
                            new DashboardWidgetLayout("health", true, "normal", "operations")
                    ),
                    List.of(
                            new DashboardSectionLayout("overview", true),
                            new DashboardSectionLayout("operations", false),
                            new DashboardSectionLayout("governance", false)
                    ),
                    false
            )
    );

    private final DashboardLayoutRepository repository;
    private final DashboardLayoutPresetRepository presetRepository;
    private final DashboardLayoutDefaultRepository defaultRepository;

    public DashboardLayoutService(
            DashboardLayoutRepository repository,
            DashboardLayoutPresetRepository presetRepository,
            DashboardLayoutDefaultRepository defaultRepository
    ) {
        this.repository = repository;
        this.presetRepository = presetRepository;
        this.defaultRepository = defaultRepository;
    }

    public DashboardLayoutResponse get(AuthenticatedUser user, String scope) {
        String normalizedScope = normalizeScope(scope);
        return repository.findByUserIdAndScope(user.id(), normalizedScope)
                .map(record -> response(user, record, "SAVED"))
                .orElseGet(() -> defaultLayoutFor(user, normalizedScope));
    }

    public List<DashboardLayoutPresetResponse> presets(AuthenticatedUser user) {
        List<DashboardLayoutPresetResponse> presets = new ArrayList<>(BUILT_IN_PRESETS.stream()
                .map(preset -> presetResponseForUser(user, preset))
                .toList());
        presetRepository.findAll().stream()
                .map(record -> customPresetResponse(user, record))
                .forEach(presets::add);
        return List.copyOf(presets);
    }

    public List<DashboardWidgetCatalogItem> widgetCatalog(AuthenticatedUser user) {
        return EFFECTIVE_WIDGET_CATALOG.stream()
                .filter(widget -> isWidgetAllowedForUser(user, widget.id()))
                .toList();
    }

    public DashboardLayoutResponse save(AuthenticatedUser user, String scope, DashboardLayoutRequest request) {
        String normalizedScope = normalizeScope(scope);
        List<DashboardWidgetLayout> widgets = sanitizeWidgetsForSave(user, request == null ? null : request.widgets());
        List<DashboardSectionLayout> sections = sanitizeSections(request == null ? null : request.sections());
        String schemaVersion = normalizeSchemaVersion(request == null ? null : request.schemaVersion());
        DashboardLayoutRecord record = repository.save(new DashboardLayoutRecord(
                user.id(),
                normalizedScope,
                widgets,
                sections,
                schemaVersion,
                OffsetDateTime.now()
        ));
        return response(user, record, "SAVED");
    }

    public void delete(AuthenticatedUser user, String scope) {
        repository.deleteByUserIdAndScope(user.id(), normalizeScope(scope));
    }

    public DashboardLayoutResponse applyPreset(AuthenticatedUser user, String scope, String presetId) {
        DashboardLayoutPresetResponse preset = findPreset(user, presetId);
        return save(user, scope, new DashboardLayoutRequest(preset.widgets(), preset.sections(), preset.schemaVersion()));
    }

    public DashboardLayoutPresetResponse createPreset(AuthenticatedUser user, DashboardLayoutPresetRequest request) {
        requireAdmin(user, "Dashboard layout preset create denied.");
        String name = normalizePresetName(request == null ? null : request.name());
        String description = normalizePresetDescription(request == null ? null : request.description());
        List<DashboardWidgetLayout> widgets = sanitizeWidgets(request == null ? null : request.widgets());
        List<DashboardSectionLayout> sections = sanitizeSections(request == null ? null : request.sections());
        String schemaVersion = normalizeSchemaVersion(request == null ? null : request.schemaVersion());
        OffsetDateTime now = OffsetDateTime.now();
        DashboardLayoutPresetRecord record = presetRepository.save(new DashboardLayoutPresetRecord(
                nextCustomPresetId(name),
                user.id(),
                name,
                description,
                widgets,
                sections,
                schemaVersion,
                now,
                now
        ));
        return customPresetResponse(record);
    }

    public DashboardLayoutPresetResponse updatePreset(AuthenticatedUser user, String presetId, DashboardLayoutPresetRequest request) {
        requireAdmin(user, "Dashboard layout preset update denied.");
        String normalizedPresetId = normalizePresetId(presetId);
        if (isBuiltInPreset(normalizedPresetId)) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Built-in dashboard layout preset cannot be updated.");
        }
        DashboardLayoutPresetRecord existing = presetRepository.findById(normalizedPresetId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Dashboard layout preset not found."));
        DashboardLayoutPresetRecord updated = presetRepository.save(new DashboardLayoutPresetRecord(
                existing.id(),
                existing.createdByUserId(),
                normalizePresetName(request == null ? null : request.name()),
                normalizePresetDescription(request == null ? null : request.description()),
                sanitizeWidgets(request == null ? null : request.widgets()),
                sanitizeSections(request == null ? null : request.sections()),
                normalizeSchemaVersion(request == null ? null : request.schemaVersion()),
                existing.createdAt(),
                OffsetDateTime.now()
        ));
        return customPresetResponse(updated);
    }

    public DashboardLayoutPresetExportResponse exportPreset(AuthenticatedUser user, String presetId) {
        return new DashboardLayoutPresetExportResponse(
                PRESET_EXPORT_FORMAT_VERSION,
                OffsetDateTime.now(),
                findPreset(user, presetId)
        );
    }

    public DashboardLayoutPresetBundleExportResponse exportPresetBundle(AuthenticatedUser user) {
        requireAdmin(user, "Dashboard layout preset bundle export denied.");
        return new DashboardLayoutPresetBundleExportResponse(
                PRESET_BUNDLE_EXPORT_FORMAT_VERSION,
                OffsetDateTime.now(),
                presets(user).stream()
                        .filter(DashboardLayoutPresetResponse::custom)
                        .toList()
        );
    }

    public DashboardLayoutPresetResponse importPreset(AuthenticatedUser user, DashboardLayoutPresetImportRequest request) {
        requireAdmin(user, "Dashboard layout preset import denied.");
        if (request == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout preset import body is required.");
        }
        DashboardLayoutPresetRequest source = request.preset();
        String name = firstPresent(request.name(), source == null ? null : source.name());
        String description = request.description() == null && source != null ? source.description() : request.description();
        List<DashboardWidgetLayout> widgets = request.widgets() == null && source != null ? source.widgets() : request.widgets();
        List<DashboardSectionLayout> sections = request.sections().isEmpty() && source != null
                ? source.sections()
                : request.sections();
        String schemaVersion = firstPresent(request.schemaVersion(), source == null ? null : source.schemaVersion());
        return createPreset(user, new DashboardLayoutPresetRequest(name, description, widgets, sections, schemaVersion));
    }

    public DashboardLayoutPresetBundleImportResponse importPresetBundle(AuthenticatedUser user, DashboardLayoutPresetBundleImportRequest request) {
        requireAdmin(user, "Dashboard layout preset bundle import denied.");
        if (request == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout preset bundle import body is required.");
        }
        normalizePresetBundleFormatVersion(request.formatVersion());
        if (request.presets().isEmpty()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout preset bundle is empty.");
        }
        if (request.presets().size() > MAX_PRESET_BUNDLE_SIZE) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout preset bundle exceeds the limit.");
        }
        List<DashboardLayoutPresetRequest> normalizedPresets = request.presets().stream()
                .map(this::normalizePresetRequest)
                .toList();
        List<DashboardLayoutPresetResponse> importedPresets = normalizedPresets.stream()
                .map(preset -> createPreset(user, preset))
                .toList();
        return new DashboardLayoutPresetBundleImportResponse(importedPresets.size(), importedPresets);
    }

    public List<DashboardLayoutDefaultResponse> defaults(AuthenticatedUser user) {
        requireAdmin(user, "Dashboard layout defaults read denied.");
        return defaultRepository.findAll().stream()
                .map(this::defaultResponse)
                .toList();
    }

    public DashboardLayoutDefaultResponse saveDefault(AuthenticatedUser user, DashboardLayoutDefaultRequest request) {
        requireAdmin(user, "Dashboard layout default save denied.");
        if (request == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout default request is required.");
        }
        String targetType = normalizeDefaultTargetType(request.targetType());
        String targetId = normalizeDefaultTargetId(targetType, request.targetId());
        DashboardLayoutPresetResponse preset = findPreset(request.presetId());
        DashboardLayoutDefaultRecord record = defaultRepository.save(new DashboardLayoutDefaultRecord(
                targetType,
                targetId,
                preset.id(),
                user.id(),
                OffsetDateTime.now()
        ));
        return defaultResponse(record, preset);
    }

    public void deleteDefault(AuthenticatedUser user, String targetType, String targetId) {
        requireAdmin(user, "Dashboard layout default delete denied.");
        String normalizedTargetType = normalizeDefaultTargetType(targetType);
        String normalizedTargetId = normalizeDefaultTargetId(normalizedTargetType, targetId);
        if (!defaultRepository.deleteByTarget(normalizedTargetType, normalizedTargetId)) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Dashboard layout default not found.");
        }
    }

    public void deletePreset(AuthenticatedUser user, String presetId) {
        requireAdmin(user, "Dashboard layout preset delete denied.");
        String normalizedPresetId = normalizePresetId(presetId);
        if (isBuiltInPreset(normalizedPresetId)) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Built-in dashboard layout preset cannot be deleted.");
        }
        if (!presetRepository.deleteById(normalizedPresetId)) {
            throw new ApiException(ApiErrorCode.NOT_FOUND, "Dashboard layout preset not found.");
        }
    }

    private DashboardLayoutResponse response(AuthenticatedUser user, DashboardLayoutRecord record, String source) {
        return new DashboardLayoutResponse(
                record.scope(),
                filterWidgetsForUser(user, record.widgets()),
                sanitizeSections(record.sections()),
                normalizeSchemaVersion(record.schemaVersion()),
                source,
                record.updatedAt()
        );
    }

    private DashboardLayoutResponse defaultLayoutFor(AuthenticatedUser user, String scope) {
        DashboardLayoutDefaultRecord defaultRecord = defaultRecordFor(user);
        if (defaultRecord == null) {
            return new DashboardLayoutResponse(scope, List.of(), defaultSections(), LAYOUT_SCHEMA_VERSION, "DEFAULT", null);
        }
        DashboardLayoutPresetResponse preset = findPresetOrNull(defaultRecord.presetId());
        if (preset == null) {
            return new DashboardLayoutResponse(scope, List.of(), defaultSections(), LAYOUT_SCHEMA_VERSION, "DEFAULT", null);
        }
        return new DashboardLayoutResponse(
                scope,
                filterWidgetsForUser(user, preset.widgets()),
                sanitizeSections(preset.sections()),
                normalizeSchemaVersion(preset.schemaVersion()),
                "DEFAULT_PRESET",
                defaultRecord.updatedAt()
        );
    }

    private DashboardLayoutDefaultRecord defaultRecordFor(AuthenticatedUser user) {
        if (user.organizationId() != null) {
            DashboardLayoutDefaultRecord organizationDefault = defaultRepository
                    .findByTarget("ORGANIZATION", String.valueOf(user.organizationId()))
                    .orElse(null);
            if (organizationDefault != null && findPresetOrNull(organizationDefault.presetId()) != null) {
                return organizationDefault;
            }
        }
        return defaultRepository.findByTarget("ROLE", normalizeRole(user.role()))
                .filter(record -> findPresetOrNull(record.presetId()) != null)
                .orElse(null);
    }

    private String normalizeScope(String scope) {
        String value = scope == null || scope.isBlank() ? "main" : scope.trim().toLowerCase(Locale.ROOT);
        if (value.length() > MAX_SCOPE_LENGTH || !value.matches("[a-z0-9][a-z0-9_.-]*")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout scope is invalid.");
        }
        return value;
    }

    private String normalizeSchemaVersion(String schemaVersion) {
        String value = schemaVersion == null || schemaVersion.isBlank() ? LAYOUT_SCHEMA_VERSION : schemaVersion.trim();
        if (!LAYOUT_SCHEMA_VERSION.equals(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout schema version is invalid.");
        }
        return value;
    }

    private String normalizePresetBundleFormatVersion(String formatVersion) {
        String value = formatVersion == null || formatVersion.isBlank() ? PRESET_BUNDLE_EXPORT_FORMAT_VERSION : formatVersion.trim();
        if (!PRESET_BUNDLE_EXPORT_FORMAT_VERSION.equals(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout preset bundle format version is invalid.");
        }
        return value;
    }

    private DashboardLayoutPresetRequest normalizePresetRequest(DashboardLayoutPresetRequest request) {
        if (request == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout preset bundle item is required.");
        }
        return new DashboardLayoutPresetRequest(
                normalizePresetName(request.name()),
                normalizePresetDescription(request.description()),
                sanitizeWidgets(request.widgets()),
                sanitizeSections(request.sections()),
                normalizeSchemaVersion(request.schemaVersion())
        );
    }

    private DashboardLayoutPresetResponse findPreset(String presetId) {
        String normalizedPresetId = normalizePresetId(presetId);
        return BUILT_IN_PRESETS.stream()
                .filter(preset -> preset.id().equals(normalizedPresetId))
                .findFirst()
                .or(() -> presetRepository.findById(normalizedPresetId).map(this::customPresetResponse))
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Dashboard layout preset not found."));
    }

    private DashboardLayoutPresetResponse findPreset(AuthenticatedUser user, String presetId) {
        return presetResponseForUser(user, findPreset(presetId));
    }

    private DashboardLayoutPresetResponse findPresetOrNull(String presetId) {
        try {
            return findPreset(presetId);
        } catch (ApiException exception) {
            if (exception.code() == ApiErrorCode.NOT_FOUND || exception.code() == ApiErrorCode.VALIDATION_ERROR) {
                return null;
            }
            throw exception;
        }
    }

    private DashboardLayoutPresetResponse customPresetResponse(DashboardLayoutPresetRecord record) {
        return new DashboardLayoutPresetResponse(
                record.id(),
                record.name(),
                record.description(),
                sanitizeWidgets(record.widgets()),
                sanitizeSections(record.sections()),
                normalizeSchemaVersion(record.schemaVersion()),
                true
        );
    }

    private DashboardLayoutPresetResponse customPresetResponse(AuthenticatedUser user, DashboardLayoutPresetRecord record) {
        return presetResponseForUser(user, customPresetResponse(record));
    }

    private DashboardLayoutPresetResponse presetResponseForUser(AuthenticatedUser user, DashboardLayoutPresetResponse preset) {
        return new DashboardLayoutPresetResponse(
                preset.id(),
                preset.name(),
                preset.description(),
                filterWidgetsForUser(user, preset.widgets()),
                sanitizeSections(preset.sections()),
                normalizeSchemaVersion(preset.schemaVersion()),
                preset.custom()
        );
    }

    private void requireAdmin(AuthenticatedUser user, String message) {
        if (!user.isAdmin()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, message);
        }
    }

    private String normalizePresetName(String name) {
        String value = name == null ? "" : name.trim();
        if (value.isBlank() || value.length() > MAX_PRESET_NAME_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout preset name is invalid.");
        }
        return value;
    }

    private String normalizePresetDescription(String description) {
        String value = description == null ? "" : description.trim();
        if (value.length() > MAX_PRESET_DESCRIPTION_LENGTH) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout preset description is invalid.");
        }
        return value;
    }

    private String normalizePresetId(String presetId) {
        String value = presetId == null || presetId.isBlank() ? "" : presetId.trim().toLowerCase(Locale.ROOT);
        if (value.isBlank() || value.length() > MAX_ID_LENGTH || !value.matches("[a-z][a-z0-9-]*")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout preset id is invalid.");
        }
        return value;
    }

    private String normalizeDefaultTargetType(String targetType) {
        String value = targetType == null ? "" : targetType.trim().toUpperCase(Locale.ROOT);
        if (!ALLOWED_DEFAULT_TARGET_TYPES.contains(value)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout default target type is invalid.");
        }
        return value;
    }

    private String normalizeDefaultTargetId(String targetType, String targetId) {
        if ("ROLE".equals(targetType)) {
            String value = normalizeRole(targetId);
            if (!ALLOWED_DEFAULT_ROLE_TARGETS.contains(value)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout default role target is invalid.");
            }
            return value;
        }
        String value = targetId == null ? "" : targetId.trim();
        if (!value.matches("[1-9][0-9]{0,17}")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard layout default organization target is invalid.");
        }
        return value;
    }

    private String normalizeRole(String role) {
        return role == null ? "" : role.trim().toUpperCase(Locale.ROOT);
    }

    private String nextCustomPresetId(String name) {
        String base = ("custom-" + name.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", "-"))
                .replaceAll("-+", "-")
                .replaceAll("^-|-$", "");
        if ("custom".equals(base) || base.isBlank()) {
            base = "custom-preset";
        }
        if (base.length() > MAX_ID_LENGTH) {
            base = base.substring(0, MAX_ID_LENGTH).replaceAll("-$", "");
        }
        String candidate = base;
        if (isBuiltInPreset(candidate) || presetRepository.findById(candidate).isPresent()) {
            String suffix = "-" + Long.toString(System.currentTimeMillis(), 36);
            int maxBaseLength = Math.max(1, MAX_ID_LENGTH - suffix.length());
            candidate = base.substring(0, Math.min(base.length(), maxBaseLength)).replaceAll("-$", "") + suffix;
        }
        return candidate;
    }

    private boolean isBuiltInPreset(String presetId) {
        return BUILT_IN_PRESETS.stream().anyMatch(preset -> preset.id().equals(presetId));
    }

    private String firstPresent(String primary, String fallback) {
        if (primary != null && !primary.isBlank()) {
            return primary;
        }
        return fallback;
    }

    private DashboardLayoutDefaultResponse defaultResponse(DashboardLayoutDefaultRecord record) {
        DashboardLayoutPresetResponse preset = findPresetOrNull(record.presetId());
        return defaultResponse(record, preset);
    }

    private DashboardLayoutDefaultResponse defaultResponse(DashboardLayoutDefaultRecord record, DashboardLayoutPresetResponse preset) {
        return new DashboardLayoutDefaultResponse(
                record.targetType(),
                record.targetId(),
                record.presetId(),
                preset == null ? "" : preset.name(),
                preset != null && preset.custom(),
                record.updatedAt()
        );
    }

    private List<DashboardSectionLayout> defaultSections() {
        return WIDGET_SECTION_ORDER.stream()
                .map(section -> new DashboardSectionLayout(section, false))
                .toList();
    }

    private List<DashboardSectionLayout> sanitizeSections(List<DashboardSectionLayout> sections) {
        Map<String, DashboardSectionLayout> sanitized = new LinkedHashMap<>();
        for (String section : WIDGET_SECTION_ORDER) {
            sanitized.put(section, new DashboardSectionLayout(section, false));
        }
        if (sections == null || sections.isEmpty()) {
            return List.copyOf(sanitized.values());
        }
        Set<String> ids = new HashSet<>();
        for (DashboardSectionLayout section : sections) {
            if (section == null || section.id() == null || section.id().isBlank()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard section id is required.");
            }
            String id = section.id().trim().toLowerCase(Locale.ROOT);
            if (!ALLOWED_WIDGET_SECTIONS.contains(id)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard section id is invalid.");
            }
            if (!ids.add(id)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard section id is duplicated.");
            }
            sanitized.put(id, new DashboardSectionLayout(id, section.collapsed()));
        }
        return List.copyOf(sanitized.values());
    }

    private List<DashboardWidgetLayout> sanitizeWidgets(List<DashboardWidgetLayout> widgets) {
        if (widgets == null) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widgets are required.");
        }
        if (widgets.size() > MAX_WIDGETS) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget count exceeds the limit.");
        }
        Set<String> ids = new HashSet<>();
        List<DashboardWidgetLayout> sanitized = new ArrayList<>();
        for (DashboardWidgetLayout widget : widgets) {
            if (widget == null || widget.id() == null || widget.id().isBlank()) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget id is required.");
            }
            String id = widget.id().trim().toLowerCase(Locale.ROOT);
            if (id.length() > MAX_ID_LENGTH || !id.matches("[a-z][a-z0-9-]*")) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget id is invalid.");
            }
            if (!ALLOWED_WIDGET_IDS.contains(id)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget id is not in the catalog.");
            }
            if (!ids.add(id)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget id is duplicated.");
            }
            sanitized.add(new DashboardWidgetLayout(
                    id,
                    widget.enabled(),
                    normalizeWidgetSize(widget.size()),
                    normalizeWidgetSection(widget.section()),
                    sanitizeWidgetOptions(widget.options())
            ));
        }
        return List.copyOf(sanitized);
    }

    private List<DashboardWidgetLayout> sanitizeWidgetsForSave(AuthenticatedUser user, List<DashboardWidgetLayout> widgets) {
        List<DashboardWidgetLayout> sanitized = sanitizeWidgets(widgets);
        for (DashboardWidgetLayout widget : sanitized) {
            if (!isWidgetAllowedForUser(user, widget.id())) {
                throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Dashboard widget is admin-only.");
            }
        }
        return sanitized;
    }

    private List<DashboardWidgetLayout> filterWidgetsForUser(AuthenticatedUser user, List<DashboardWidgetLayout> widgets) {
        return sanitizeWidgets(widgets).stream()
                .filter(widget -> isWidgetAllowedForUser(user, widget.id()))
                .toList();
    }

    private boolean isWidgetAllowedForUser(AuthenticatedUser user, String widgetId) {
        DashboardWidgetCatalogItem item = WIDGET_CATALOG_BY_ID.get(widgetId);
        return item != null && (!item.adminOnly() || user.isAdmin());
    }

    private static DashboardWidgetCatalogItem widget(
            String id,
            String title,
            String description,
            String category,
            boolean adminOnly
    ) {
        return new DashboardWidgetCatalogItem(id, title, description, category, adminOnly, DEFAULT_WIDGET_CONFIG_OPTIONS);
    }

    private Map<String, String> sanitizeWidgetOptions(Map<String, String> options) {
        if (options == null || options.isEmpty()) {
            return Map.of("tone", "default", "refreshInterval", "manual");
        }
        if (options.size() > 10) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget options exceed the limit.");
        }
        Map<String, String> sanitized = new LinkedHashMap<>();
        for (Map.Entry<String, String> entry : options.entrySet()) {
            String rawKey = entry.getKey() == null ? "" : entry.getKey().trim().toLowerCase(Locale.ROOT);
            String key = rawKey.equals("refreshinterval") ? "refreshInterval" : rawKey;
            if (!ALLOWED_WIDGET_OPTION_KEYS.contains(key)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget option is invalid.");
            }
            String value = entry.getValue() == null ? "" : entry.getValue().trim().toLowerCase(Locale.ROOT);
            if (key.equals("tone") && !ALLOWED_WIDGET_TONES.contains(value)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget tone is invalid.");
            }
            if (key.equals("refreshInterval") && !ALLOWED_WIDGET_REFRESH_INTERVALS.contains(value)) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget refresh interval is invalid.");
            }
            sanitized.put(key, value);
        }
        sanitized.putIfAbsent("tone", "default");
        sanitized.putIfAbsent("refreshInterval", "manual");
        return Map.copyOf(sanitized);
    }

    private String normalizeWidgetSize(String size) {
        String normalized = size == null || size.isBlank() ? "normal" : size.trim().toLowerCase(Locale.ROOT);
        if (!ALLOWED_WIDGET_SIZES.contains(normalized)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget size is invalid.");
        }
        return normalized;
    }

    private String normalizeWidgetSection(String section) {
        String normalized = section == null || section.isBlank() ? "overview" : section.trim().toLowerCase(Locale.ROOT);
        if (!ALLOWED_WIDGET_SECTIONS.contains(normalized)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Dashboard widget section is invalid.");
        }
        return normalized;
    }
}
