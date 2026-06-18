package com.example.osmu.dashboard;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/dashboard/layout")
public class DashboardLayoutController {

    private final AuthContext authContext;
    private final AuditLogService auditLogService;
    private final DashboardLayoutService dashboardLayoutService;

    public DashboardLayoutController(
            AuthContext authContext,
            AuditLogService auditLogService,
            DashboardLayoutService dashboardLayoutService
    ) {
        this.authContext = authContext;
        this.auditLogService = auditLogService;
        this.dashboardLayoutService = dashboardLayoutService;
    }

    @GetMapping
    public ApiResponse<DashboardLayoutResponse> get(
            @RequestParam(defaultValue = "main") String scope,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(dashboardLayoutService.get(user, scope));
    }

    @GetMapping("/presets")
    public ApiResponse<List<DashboardLayoutPresetResponse>> presets(HttpServletRequest request) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(dashboardLayoutService.presets(user));
    }

    @GetMapping("/widgets")
    public ApiResponse<List<DashboardWidgetCatalogItem>> widgetCatalog(HttpServletRequest request) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(dashboardLayoutService.widgetCatalog(user));
    }

    @GetMapping("/defaults")
    public ApiResponse<List<DashboardLayoutDefaultResponse>> defaults(HttpServletRequest request) {
        AuthenticatedUser user = authContext.currentUser(request);
        return ApiResponse.of(dashboardLayoutService.defaults(user));
    }

    @PutMapping("/defaults")
    public ApiResponse<DashboardLayoutDefaultResponse> saveDefault(
            @RequestBody(required = false) DashboardLayoutDefaultRequest defaultRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        DashboardLayoutDefaultResponse response = dashboardLayoutService.saveDefault(user, defaultRequest);
        auditLogService.record("DASHBOARD_LAYOUT_DEFAULT_SAVE", user.loginId(), "DASHBOARD_LAYOUT_DEFAULT", response.targetType() + ":" + response.targetId(), "SUCCESS", "Dashboard layout default saved", request);
        return ApiResponse.of(response);
    }

    @DeleteMapping("/defaults/{targetType}/{targetId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteDefault(
            @PathVariable String targetType,
            @PathVariable String targetId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        dashboardLayoutService.deleteDefault(user, targetType, targetId);
        auditLogService.record("DASHBOARD_LAYOUT_DEFAULT_DELETE", user.loginId(), "DASHBOARD_LAYOUT_DEFAULT", targetType + ":" + targetId, "SUCCESS", "Dashboard layout default deleted", request);
    }

    @PostMapping("/presets")
    public ApiResponse<DashboardLayoutPresetResponse> createPreset(
            @RequestBody(required = false) DashboardLayoutPresetRequest presetRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        DashboardLayoutPresetResponse response = dashboardLayoutService.createPreset(user, presetRequest);
        auditLogService.record("DASHBOARD_LAYOUT_PRESET_CREATE", user.loginId(), "DASHBOARD_LAYOUT_PRESET", response.id(), "SUCCESS", "Dashboard layout preset created", request);
        return ApiResponse.of(response);
    }

    @GetMapping("/presets/{presetId}/export")
    public ApiResponse<DashboardLayoutPresetExportResponse> exportPreset(
            @PathVariable String presetId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        DashboardLayoutPresetExportResponse response = dashboardLayoutService.exportPreset(user, presetId);
        auditLogService.record("DASHBOARD_LAYOUT_PRESET_EXPORT", user.loginId(), "DASHBOARD_LAYOUT_PRESET", response.preset().id(), "SUCCESS", "Dashboard layout preset exported", request);
        return ApiResponse.of(response);
    }

    @GetMapping("/preset-bundle/export")
    public ApiResponse<DashboardLayoutPresetBundleExportResponse> exportPresetBundle(HttpServletRequest request) {
        AuthenticatedUser user = authContext.currentUser(request);
        DashboardLayoutPresetBundleExportResponse response = dashboardLayoutService.exportPresetBundle(user);
        auditLogService.record("DASHBOARD_LAYOUT_PRESET_BUNDLE_EXPORT", user.loginId(), "DASHBOARD_LAYOUT_PRESET_BUNDLE", response.formatVersion(), "SUCCESS", "Dashboard layout preset bundle exported", request);
        return ApiResponse.of(response);
    }

    @PostMapping("/presets/import")
    public ApiResponse<DashboardLayoutPresetResponse> importPreset(
            @RequestBody(required = false) DashboardLayoutPresetImportRequest presetRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        DashboardLayoutPresetResponse response = dashboardLayoutService.importPreset(user, presetRequest);
        auditLogService.record("DASHBOARD_LAYOUT_PRESET_IMPORT", user.loginId(), "DASHBOARD_LAYOUT_PRESET", response.id(), "SUCCESS", "Dashboard layout preset imported", request);
        return ApiResponse.of(response);
    }

    @PostMapping("/preset-bundle/import")
    public ApiResponse<DashboardLayoutPresetBundleImportResponse> importPresetBundle(
            @RequestBody(required = false) DashboardLayoutPresetBundleImportRequest presetRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        DashboardLayoutPresetBundleImportResponse response = dashboardLayoutService.importPresetBundle(user, presetRequest);
        auditLogService.record("DASHBOARD_LAYOUT_PRESET_BUNDLE_IMPORT", user.loginId(), "DASHBOARD_LAYOUT_PRESET_BUNDLE", response.importedCount() + "", "SUCCESS", "Dashboard layout preset bundle imported", request);
        return ApiResponse.of(response);
    }

    @PutMapping
    public ApiResponse<DashboardLayoutResponse> save(
            @RequestParam(defaultValue = "main") String scope,
            @RequestBody(required = false) DashboardLayoutRequest layoutRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        DashboardLayoutResponse response = dashboardLayoutService.save(user, scope, layoutRequest);
        auditLogService.record("DASHBOARD_LAYOUT_SAVE", user.loginId(), "DASHBOARD_LAYOUT", response.scope(), "SUCCESS", "Dashboard layout saved", request);
        return ApiResponse.of(response);
    }

    @PutMapping("/presets/{presetId}")
    public ApiResponse<DashboardLayoutResponse> applyPreset(
            @PathVariable String presetId,
            @RequestParam(defaultValue = "main") String scope,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        DashboardLayoutResponse response = dashboardLayoutService.applyPreset(user, scope, presetId);
        auditLogService.record("DASHBOARD_LAYOUT_PRESET_APPLY", user.loginId(), "DASHBOARD_LAYOUT", response.scope(), "SUCCESS", "Dashboard layout preset applied: " + presetId, request);
        return ApiResponse.of(response);
    }

    @PatchMapping("/presets/{presetId}")
    public ApiResponse<DashboardLayoutPresetResponse> updatePreset(
            @PathVariable String presetId,
            @RequestBody(required = false) DashboardLayoutPresetRequest presetRequest,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        DashboardLayoutPresetResponse response = dashboardLayoutService.updatePreset(user, presetId, presetRequest);
        auditLogService.record("DASHBOARD_LAYOUT_PRESET_UPDATE", user.loginId(), "DASHBOARD_LAYOUT_PRESET", response.id(), "SUCCESS", "Dashboard layout preset updated", request);
        return ApiResponse.of(response);
    }

    @DeleteMapping("/presets/{presetId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deletePreset(
            @PathVariable String presetId,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        dashboardLayoutService.deletePreset(user, presetId);
        auditLogService.record("DASHBOARD_LAYOUT_PRESET_DELETE", user.loginId(), "DASHBOARD_LAYOUT_PRESET", presetId, "SUCCESS", "Dashboard layout preset deleted", request);
    }

    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(
            @RequestParam(defaultValue = "main") String scope,
            HttpServletRequest request
    ) {
        AuthenticatedUser user = authContext.currentUser(request);
        dashboardLayoutService.delete(user, scope);
        auditLogService.record("DASHBOARD_LAYOUT_RESET", user.loginId(), "DASHBOARD_LAYOUT", scope, "SUCCESS", "Dashboard layout reset", request);
    }
}
