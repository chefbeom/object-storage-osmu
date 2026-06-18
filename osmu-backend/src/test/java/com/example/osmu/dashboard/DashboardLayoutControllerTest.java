package com.example.osmu.dashboard;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class DashboardLayoutControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void userCanPersistAndResetDashboardLayout() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String scope = "ops-test-" + System.nanoTime();

        mockMvc.perform(get("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.scope").value(scope))
                .andExpect(jsonPath("$.data.source").value("DEFAULT"))
                .andExpect(jsonPath("$.data.schemaVersion").value("osmu.dashboard-layout.v1"))
                .andExpect(jsonPath("$.data.widgets").isArray());

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "wide", "section": "overview", "options": { "tone": "focus" } },
                                    { "id": "readiness", "enabled": false, "size": "compact" }
                                  ],
                                  "sections": [
                                    { "id": "operations", "collapsed": true }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.scope").value(scope))
                .andExpect(jsonPath("$.data.source").value("SAVED"))
                .andExpect(jsonPath("$.data.schemaVersion").value("osmu.dashboard-layout.v1"))
                .andExpect(jsonPath("$.data.widgets[0].id").value("capacity"))
                .andExpect(jsonPath("$.data.widgets[0].size").value("wide"))
                .andExpect(jsonPath("$.data.widgets[0].section").value("overview"))
                .andExpect(jsonPath("$.data.widgets[0].options.tone").value("focus"))
                .andExpect(jsonPath("$.data.widgets[1].id").value("readiness"))
                .andExpect(jsonPath("$.data.widgets[1].enabled").value(false))
                .andExpect(jsonPath("$.data.widgets[1].size").value("compact"))
                .andExpect(jsonPath("$.data.widgets[1].section").value("overview"))
                .andExpect(jsonPath("$.data.widgets[1].options.tone").value("default"))
                .andExpect(jsonPath("$.data.sections[1].id").value("operations"))
                .andExpect(jsonPath("$.data.sections[1].collapsed").value(true))
                .andExpect(jsonPath("$.data.updatedAt").isString());

        mockMvc.perform(get("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.source").value("SAVED"))
                .andExpect(jsonPath("$.data.schemaVersion").value("osmu.dashboard-layout.v1"))
                .andExpect(jsonPath("$.data.widgets[0].id").value("capacity"))
                .andExpect(jsonPath("$.data.widgets[0].size").value("wide"))
                .andExpect(jsonPath("$.data.widgets[0].section").value("overview"))
                .andExpect(jsonPath("$.data.widgets[0].options.tone").value("focus"))
                .andExpect(jsonPath("$.data.widgets[1].enabled").value(false))
                .andExpect(jsonPath("$.data.sections[1].collapsed").value(true));

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "widgets": [
                                    { "id": "capacity", "enabled": true },
                                    { "id": "capacity", "enabled": false }
                                  ]
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "schemaVersion": "osmu.dashboard-layout.v9",
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "normal" }
                                  ]
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "normal" }
                                  ],
                                  "sections": [
                                    { "id": "executive", "collapsed": true }
                                  ]
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "huge" }
                                  ]
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "normal", "section": "executive" }
                                  ]
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "normal", "options": { "tone": "neon" } }
                                  ]
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(delete("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.source").value("DEFAULT"))
                .andExpect(jsonPath("$.data.widgets").isEmpty());
    }

    @Test
    void userCanReadAndApplyDashboardLayoutPreset() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String scope = "preset-test-" + System.nanoTime();

        mockMvc.perform(get("/api/dashboard/layout/presets")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].id").value("operations"))
                .andExpect(jsonPath("$.data[0].custom").value(false))
                .andExpect(jsonPath("$.data[0].widgets[0].id").value("capacity"))
                .andExpect(jsonPath("$.data[0].widgets[0].size").value("wide"))
                .andExpect(jsonPath("$.data[0].widgets[*].id", hasItem("access-keys")))
                .andExpect(jsonPath("$.data[0].widgets[*].id", hasItem("lifecycle")))
                .andExpect(jsonPath("$.data[0].widgets[*].id", hasItem("execution-retention")))
                .andExpect(jsonPath("$.data[0].widgets[*].id", hasItem("storage-expansion")));

        mockMvc.perform(get("/api/dashboard/layout/widgets")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[*].id", hasItem("access-keys")))
                .andExpect(jsonPath("$.data[*].id", hasItem("identity")))
                .andExpect(jsonPath("$.data[*].id", hasItem("lifecycle")))
                .andExpect(jsonPath("$.data[*].id", hasItem("execution-retention")))
                .andExpect(jsonPath("$.data[*].id", hasItem("storage-expansion")))
                .andExpect(jsonPath("$.data[?(@.id == 'identity')].adminOnly", hasItem(true)))
                .andExpect(jsonPath("$.data[?(@.id == 'execution-retention')].adminOnly", hasItem(true)))
                .andExpect(jsonPath("$.data[?(@.id == 'execution-retention')].category", hasItem("GOVERNANCE")))
                .andExpect(jsonPath("$.data[?(@.id == 'storage-expansion')].adminOnly", hasItem(true)))
                .andExpect(jsonPath("$.data[?(@.id == 'storage-expansion')].category", hasItem("OPERATIONS")))
                .andExpect(jsonPath("$.data[?(@.id == 'access-keys')].category", hasItem("SECURITY")))
                .andExpect(jsonPath("$.data[?(@.id == 'access-keys')].configOptions[0].key", hasItem("tone")))
                .andExpect(jsonPath("$.data[?(@.id == 'access-keys')].configOptions[0].defaultValue", hasItem("default")));

        mockMvc.perform(put("/api/dashboard/layout/presets/compact")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.scope").value(scope))
                .andExpect(jsonPath("$.data.source").value("SAVED"))
                .andExpect(jsonPath("$.data.widgets[0].id").value("capacity"))
                .andExpect(jsonPath("$.data.widgets[1].id").value("health"))
                .andExpect(jsonPath("$.data.widgets[1].size").value("compact"));

        mockMvc.perform(get("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.source").value("SAVED"))
                .andExpect(jsonPath("$.data.widgets[1].size").value("compact"));

        mockMvc.perform(put("/api/dashboard/layout/presets/missing")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isNotFound());

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "widgets": [
                                    { "id": "unknown-widget", "enabled": true, "size": "normal" }
                                  ]
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void nonAdminDashboardLayoutHidesAndRejectsAdminOnlyWidgets() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        String loginId = "dashboard-user-" + System.nanoTime();
        createUser(adminToken, loginId, "USER", null);
        String userToken = loginAndReturnAccessToken(loginId, "user-password");
        String scope = "non-admin-widget-test-" + System.nanoTime();

        mockMvc.perform(get("/api/dashboard/layout/widgets")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[*].id", hasItem("capacity")))
                .andExpect(jsonPath("$.data[*].id", hasItem("access-keys")))
                .andExpect(jsonPath("$.data[*].id", org.hamcrest.Matchers.not(hasItem("identity"))))
                .andExpect(jsonPath("$.data[*].id", org.hamcrest.Matchers.not(hasItem("storage-expansion"))))
                .andExpect(jsonPath("$.data[*].adminOnly", org.hamcrest.Matchers.not(hasItem(true))));

        mockMvc.perform(get("/api/dashboard/layout/presets")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[*].widgets[*].id", org.hamcrest.Matchers.not(hasItem("requests"))))
                .andExpect(jsonPath("$.data[*].widgets[*].id", org.hamcrest.Matchers.not(hasItem("storage-expansion"))));

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + userToken)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "widgets": [
                                    { "id": "identity", "enabled": true, "size": "normal" }
                                  ]
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + userToken)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "wide" },
                                    { "id": "access-keys", "enabled": true, "size": "normal" }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.widgets[*].id", hasItem("capacity")))
                .andExpect(jsonPath("$.data.widgets[*].id", hasItem("access-keys")))
                .andExpect(jsonPath("$.data.widgets[*].id", org.hamcrest.Matchers.not(hasItem("identity"))));

        mockMvc.perform(put("/api/dashboard/layout/presets/admin")
                        .header("Authorization", "Bearer " + userToken)
                        .param("scope", scope))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.widgets[*].id", hasItem("readiness")))
                .andExpect(jsonPath("$.data.widgets[*].id", hasItem("backup")))
                .andExpect(jsonPath("$.data.widgets[*].id", hasItem("access-keys")))
                .andExpect(jsonPath("$.data.widgets[*].id", org.hamcrest.Matchers.not(hasItem("identity"))))
                .andExpect(jsonPath("$.data.widgets[*].id", org.hamcrest.Matchers.not(hasItem("storage-expansion"))));
    }

    @Test
    void adminCanCreateApplyAndDeleteCustomDashboardLayoutPreset() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String scope = "custom-preset-test-" + System.nanoTime();

        String createResponse = mockMvc.perform(post("/api/dashboard/layout/presets")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Executive Console",
                                  "description": "Board room layout",
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "wide" },
                                    { "id": "sharing", "enabled": true, "size": "normal" }
                                  ],
                                  "sections": [
                                    { "id": "governance", "collapsed": true }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.custom").value(true))
                .andExpect(jsonPath("$.data.name").value("Executive Console"))
                .andExpect(jsonPath("$.data.schemaVersion").value("osmu.dashboard-layout.v1"))
                .andExpect(jsonPath("$.data.widgets[0].size").value("wide"))
                .andExpect(jsonPath("$.data.sections[2].collapsed").value(true))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String presetId = JsonPath.read(createResponse, "$.data.id");

        String presetsResponse = mockMvc.perform(get("/api/dashboard/layout/presets")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        List<String> presetIds = JsonPath.read(presetsResponse, "$.data[*].id");
        assertTrue(presetIds.contains(presetId));

        mockMvc.perform(patch("/api/dashboard/layout/presets/{presetId}", presetId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Executive Console Updated",
                                  "description": "Updated board room layout",
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "wide" },
                                    { "id": "quota", "enabled": true, "size": "compact" }
                                  ],
                                  "sections": [
                                    { "id": "operations", "collapsed": true }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(presetId))
                .andExpect(jsonPath("$.data.name").value("Executive Console Updated"))
                .andExpect(jsonPath("$.data.schemaVersion").value("osmu.dashboard-layout.v1"))
                .andExpect(jsonPath("$.data.widgets[1].id").value("quota"))
                .andExpect(jsonPath("$.data.widgets[1].size").value("compact"))
                .andExpect(jsonPath("$.data.sections[1].collapsed").value(true));

        mockMvc.perform(patch("/api/dashboard/layout/presets/operations")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Cannot Update Built In",
                                  "description": "",
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "wide" }
                                  ]
                                }
                                """))
                .andExpect(status().isConflict());

        mockMvc.perform(get("/api/dashboard/layout/presets/{presetId}/export", presetId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.formatVersion").value("osmu.dashboard-preset.v1"))
                .andExpect(jsonPath("$.data.preset.id").value(presetId))
                .andExpect(jsonPath("$.data.preset.custom").value(true))
                .andExpect(jsonPath("$.data.preset.schemaVersion").value("osmu.dashboard-layout.v1"))
                .andExpect(jsonPath("$.data.preset.widgets[1].id").value("quota"))
                .andExpect(jsonPath("$.data.preset.sections[1].collapsed").value(true));

        String importResponse = mockMvc.perform(post("/api/dashboard/layout/presets/import")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "formatVersion": "osmu.dashboard-preset.v1",
                                  "preset": {
                                    "name": "Imported Executive Console",
                                    "description": "Imported board room layout",
                                    "widgets": [
                                      { "id": "readiness", "enabled": true, "size": "wide" },
                                      { "id": "backup", "enabled": true, "size": "normal" }
                                    ],
                                    "sections": [
                                      { "id": "overview", "collapsed": true }
                                    ]
                                  }
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.custom").value(true))
                .andExpect(jsonPath("$.data.name").value("Imported Executive Console"))
                .andExpect(jsonPath("$.data.schemaVersion").value("osmu.dashboard-layout.v1"))
                .andExpect(jsonPath("$.data.widgets[0].id").value("readiness"))
                .andExpect(jsonPath("$.data.sections[0].collapsed").value(true))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String importedPresetId = JsonPath.read(importResponse, "$.data.id");

        String bundleExportResponse = mockMvc.perform(get("/api/dashboard/layout/preset-bundle/export")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.formatVersion").value("osmu.dashboard-preset-bundle.v1"))
                .andExpect(jsonPath("$.data.presets[*].id", hasItem(presetId)))
                .andExpect(jsonPath("$.data.presets[*].id", hasItem(importedPresetId)))
                .andExpect(jsonPath("$.data.presets[0].custom").value(true))
                .andExpect(jsonPath("$.data.presets[0].schemaVersion").value("osmu.dashboard-layout.v1"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String bundleFormatVersion = JsonPath.read(bundleExportResponse, "$.data.formatVersion");

        String bundleImportResponse = mockMvc.perform(post("/api/dashboard/layout/preset-bundle/import")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "formatVersion": "%s",
                                  "presets": [
                                    {
                                      "name": "Bundle Executive Console",
                                      "description": "Bundle imported board room layout",
                                      "widgets": [
                                        { "id": "capacity", "enabled": true, "size": "wide" }
                                      ],
                                      "sections": [
                                        { "id": "governance", "collapsed": true }
                                      ]
                                    },
                                    {
                                      "name": "Bundle Operations Console",
                                      "description": "Bundle imported operations layout",
                                      "schemaVersion": "osmu.dashboard-layout.v1",
                                      "widgets": [
                                        { "id": "health", "enabled": true, "size": "normal" }
                                      ],
                                      "sections": [
                                        { "id": "operations", "collapsed": true }
                                      ]
                                    }
                                  ]
                                }
                                """.formatted(bundleFormatVersion)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.importedCount").value(2))
                .andExpect(jsonPath("$.data.presets[0].custom").value(true))
                .andExpect(jsonPath("$.data.presets[0].schemaVersion").value("osmu.dashboard-layout.v1"))
                .andExpect(jsonPath("$.data.presets[0].sections[2].collapsed").value(true))
                .andExpect(jsonPath("$.data.presets[1].widgets[0].id").value("health"))
                .andExpect(jsonPath("$.data.presets[1].sections[1].collapsed").value(true))
                .andReturn()
                .getResponse()
                .getContentAsString();
        List<String> bundleImportedPresetIds = JsonPath.read(bundleImportResponse, "$.data.presets[*].id");

        mockMvc.perform(post("/api/dashboard/layout/preset-bundle/import")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "formatVersion": "osmu.dashboard-preset-bundle.v0",
                                  "presets": []
                                }
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(put("/api/dashboard/layout/presets/{presetId}", presetId)
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.source").value("SAVED"))
                .andExpect(jsonPath("$.data.schemaVersion").value("osmu.dashboard-layout.v1"))
                .andExpect(jsonPath("$.data.widgets[0].id").value("capacity"))
                .andExpect(jsonPath("$.data.widgets[1].id").value("quota"))
                .andExpect(jsonPath("$.data.sections[1].collapsed").value(true));

        mockMvc.perform(delete("/api/dashboard/layout/presets/operations")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isConflict());

        mockMvc.perform(delete("/api/dashboard/layout/presets/{presetId}", presetId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(delete("/api/dashboard/layout/presets/{presetId}", importedPresetId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        for (String bundleImportedPresetId : bundleImportedPresetIds) {
            mockMvc.perform(delete("/api/dashboard/layout/presets/{presetId}", bundleImportedPresetId)
                            .header("Authorization", "Bearer " + token))
                    .andExpect(status().isNoContent());
        }

        mockMvc.perform(put("/api/dashboard/layout/presets/{presetId}", presetId)
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isNotFound());
    }

    @Test
    void adminCanAssignRoleDefaultDashboardLayoutPreset() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String scope = "role-default-test-" + System.nanoTime();

        mockMvc.perform(put("/api/dashboard/layout/defaults")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "targetType": "ROLE",
                                  "targetId": "ADMIN",
                                  "presetId": "compact"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.targetType").value("ROLE"))
                .andExpect(jsonPath("$.data.targetId").value("ADMIN"))
                .andExpect(jsonPath("$.data.presetId").value("compact"))
                .andExpect(jsonPath("$.data.presetName").value("Compact"));

        mockMvc.perform(get("/api/dashboard/layout/defaults")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[?(@.targetType == 'ROLE' && @.targetId == 'ADMIN' && @.presetId == 'compact')]").exists());

        mockMvc.perform(get("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.scope").value(scope))
                .andExpect(jsonPath("$.data.source").value("DEFAULT_PRESET"))
                .andExpect(jsonPath("$.data.widgets[0].id").value("capacity"))
                .andExpect(jsonPath("$.data.widgets[1].id").value("health"))
                .andExpect(jsonPath("$.data.widgets[1].size").value("compact"));

        mockMvc.perform(put("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "widgets": [
                                    { "id": "capacity", "enabled": true, "size": "wide" }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.source").value("SAVED"))
                .andExpect(jsonPath("$.data.widgets[0].size").value("wide"));

        mockMvc.perform(delete("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.source").value("DEFAULT_PRESET"))
                .andExpect(jsonPath("$.data.widgets[1].size").value("compact"));

        mockMvc.perform(delete("/api/dashboard/layout/defaults/ROLE/ADMIN")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/dashboard/layout")
                        .header("Authorization", "Bearer " + token)
                        .param("scope", scope))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.source").value("DEFAULT"))
                .andExpect(jsonPath("$.data.widgets").isEmpty());

        mockMvc.perform(delete("/api/dashboard/layout/defaults/ROLE/ADMIN")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void dashboardLayoutRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/api/dashboard/layout"))
                .andExpect(status().isUnauthorized());
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

    private void createUser(String adminToken, String loginId, String role, Long organizationId) throws Exception {
        String organizationField = organizationId == null ? "" : """
                                  ,"organizationId": %d
                """.formatted(organizationId);
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s@example.com",
                                  "name": "Dashboard Test User",
                                  "password": "user-password",
                                  "role": "%s"%s
                                }
                                """.formatted(loginId, loginId, role, organizationField)))
                .andExpect(status().isOk());
    }
}
