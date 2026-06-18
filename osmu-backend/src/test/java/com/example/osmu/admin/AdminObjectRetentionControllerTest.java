package com.example.osmu.admin;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jayway.jsonpath.JsonPath;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class AdminObjectRetentionControllerTest {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanReadRetentionStatusAndRunManualPurge() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(get("/api/admin/object-retention/status")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.enabled").value(true))
                .andExpect(jsonPath("$.data.retentionDays").value(30))
                .andExpect(jsonPath("$.data.batchSize").value(100))
                .andExpect(jsonPath("$.data.versionRetentionDays").value(90))
                .andExpect(jsonPath("$.data.versionBatchSize").value(100))
                .andExpect(jsonPath("$.data.purgedObjectCount").exists())
                .andExpect(jsonPath("$.data.failedObjectCount").exists())
                .andExpect(jsonPath("$.data.failedRunCount").exists())
                .andExpect(jsonPath("$.data.purgedVersionCount").exists())
                .andExpect(jsonPath("$.data.failedVersionCount").exists())
                .andExpect(jsonPath("$.data.failedVersionRunCount").exists());

        mockMvc.perform(post("/api/admin/object-retention/purge")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.purgedCount").exists())
                .andExpect(jsonPath("$.data.purgedVersionCount").exists())
                .andExpect(jsonPath("$.data.status.enabled").value(true));
    }

    @Test
    void adminCanUpdateRetentionPolicy() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(put("/api/admin/object-retention/policy")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "enabled": true,
                                  "retentionDays": 7,
                                  "batchSize": 25,
                                  "versionRetentionDays": 45,
                                  "versionBatchSize": 50
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.enabled").value(true))
                .andExpect(jsonPath("$.data.retentionDays").value(7))
                .andExpect(jsonPath("$.data.batchSize").value(25))
                .andExpect(jsonPath("$.data.versionRetentionDays").value(45))
                .andExpect(jsonPath("$.data.versionBatchSize").value(50));

        mockMvc.perform(put("/api/admin/object-retention/policy")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "enabled": false
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.enabled").value(false))
                .andExpect(jsonPath("$.data.retentionDays").value(7))
                .andExpect(jsonPath("$.data.batchSize").value(25))
                .andExpect(jsonPath("$.data.versionRetentionDays").value(45))
                .andExpect(jsonPath("$.data.versionBatchSize").value(50));

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("eventType", "OBJECT_RETENTION_POLICY_UPDATE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].eventType").value("OBJECT_RETENTION_POLICY_UPDATE"));
    }

    @Test
    void adminCanManageLifecycleRules() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        String response = mockMvc.perform(post("/api/admin/object-lifecycle/rules")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Archive raw videos",
                                  "enabled": true,
                                  "priority": 50,
                                  "bucketName": "Video-Raw",
                                  "targetType": "OBJECT_VERSION",
                                  "prefix": "videos/raw/",
                                  "tags": "project=osmu,stage=raw",
                                  "retentionDays": 14,
                                  "batchSize": 20
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Archive raw videos"))
                .andExpect(jsonPath("$.data.priority").value(50))
                .andExpect(jsonPath("$.data.bucketName").value("video-raw"))
                .andExpect(jsonPath("$.data.targetType").value("OBJECT_VERSION"))
                .andExpect(jsonPath("$.data.prefix").value("videos/raw/"))
                .andExpect(jsonPath("$.data.tags.project").value("osmu"))
                .andExpect(jsonPath("$.data.tags.stage").value("raw"))
                .andExpect(jsonPath("$.data.retentionDays").value(14))
                .andExpect(jsonPath("$.data.batchSize").value(20))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String ruleId = JsonPath.read(response, "$.data.ruleId");

        String urgentResponse = mockMvc.perform(post("/api/admin/object-lifecycle/rules")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Urgent raw trash",
                                  "enabled": true,
                                  "priority": 10,
                                  "targetType": "TRASH_OBJECT",
                                  "prefix": "videos/raw/",
                                  "tags": "stage=raw",
                                  "retentionDays": 3,
                                  "batchSize": 10
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.priority").value(10))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String urgentRuleId = JsonPath.read(urgentResponse, "$.data.ruleId");

        mockMvc.perform(get("/api/admin/object-lifecycle/rules")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].ruleId").value(urgentRuleId))
                .andExpect(jsonPath("$.data[1].ruleId").value(ruleId));

        mockMvc.perform(delete("/api/admin/object-lifecycle/rules/{ruleId}", ruleId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isNoContent());
        mockMvc.perform(delete("/api/admin/object-lifecycle/rules/{ruleId}", urgentRuleId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/admin/object-lifecycle/rules")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(0));
    }

    @Test
    void adminCanReadLifecycleRuleConflictReport() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        String parentResponse = mockMvc.perform(post("/api/admin/object-lifecycle/rules")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "All raw videos",
                                  "enabled": true,
                                  "priority": 10,
                                  "targetType": "OBJECT_VERSION",
                                  "prefix": "videos/",
                                  "tags": "project=osmu",
                                  "retentionDays": 30,
                                  "batchSize": 20
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String parentRuleId = JsonPath.read(parentResponse, "$.data.ruleId");

        String childResponse = mockMvc.perform(post("/api/admin/object-lifecycle/rules")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Raw stage videos",
                                  "enabled": true,
                                  "priority": 20,
                                  "targetType": "OBJECT_VERSION",
                                  "prefix": "videos/raw/",
                                  "tags": "project=osmu,stage=raw",
                                  "retentionDays": 7,
                                  "batchSize": 10
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String childRuleId = JsonPath.read(childResponse, "$.data.ruleId");

        mockMvc.perform(get("/api/admin/object-lifecycle/conflicts")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ruleCount").value(2))
                .andExpect(jsonPath("$.data.conflictCount").value(1))
                .andExpect(jsonPath("$.data.conflicts[0].conflictType").value("OVERLAPPING_SCOPE"))
                .andExpect(jsonPath("$.data.conflicts[0].severity").value("WARNING"))
                .andExpect(jsonPath("$.data.conflicts[0].targetType").value("OBJECT_VERSION"))
                .andExpect(jsonPath("$.data.conflicts[0].firstRule.ruleId").value(parentRuleId))
                .andExpect(jsonPath("$.data.conflicts[0].secondRule.ruleId").value(childRuleId));

        mockMvc.perform(delete("/api/admin/object-lifecycle/rules/{ruleId}", parentRuleId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isNoContent());
        mockMvc.perform(delete("/api/admin/object-lifecycle/rules/{ruleId}", childRuleId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isNoContent());
    }

    @Test
    void adminCanExportAndImportS3LifecycleXml() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        String createdResponse = mockMvc.perform(post("/api/admin/object-lifecycle/rules")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Export raw versions",
                                  "enabled": true,
                                  "priority": 10,
                                  "targetType": "OBJECT_VERSION",
                                  "prefix": "videos/raw/",
                                  "tags": "stage=raw",
                                  "retentionDays": 14,
                                  "batchSize": 20
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String createdRuleId = JsonPath.read(createdResponse, "$.data.ruleId");

        mockMvc.perform(get("/api/admin/object-lifecycle/s3-xml")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ruleCount").value(1))
                .andExpect(jsonPath("$.data.xml").value(org.hamcrest.Matchers.containsString("<LifecycleConfiguration")))
                .andExpect(jsonPath("$.data.xml").value(org.hamcrest.Matchers.containsString("<NoncurrentVersionExpiration>")))
                .andExpect(jsonPath("$.data.xml").value(org.hamcrest.Matchers.containsString("Export raw versions")));

        mockMvc.perform(delete("/api/admin/object-lifecycle/rules/{ruleId}", createdRuleId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isNoContent());

        String importXml = """
                <LifecycleConfiguration>
                  <Rule>
                    <ID>Imported trash</ID>
                    <Status>Enabled</Status>
                    <Filter>
                      <And>
                        <Prefix>logs/</Prefix>
                        <Tag><Key>stage</Key><Value>cold</Value></Tag>
                      </And>
                    </Filter>
                    <Expiration><Days>15</Days></Expiration>
                  </Rule>
                  <Rule>
                    <ID>Imported versions</ID>
                    <Status>Disabled</Status>
                    <Filter><Prefix>videos/</Prefix></Filter>
                    <NoncurrentVersionExpiration><NoncurrentDays>45</NoncurrentDays></NoncurrentVersionExpiration>
                  </Rule>
                </LifecycleConfiguration>
                """;
        String importResponse = mockMvc.perform(post("/api/admin/object-lifecycle/s3-xml")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(OBJECT_MAPPER.writeValueAsString(Map.of("xml", importXml))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.importedCount").value(2))
                .andExpect(jsonPath("$.data.rules[0].name").value("Imported trash"))
                .andExpect(jsonPath("$.data.rules[0].priority").value(10))
                .andExpect(jsonPath("$.data.rules[0].targetType").value("TRASH_OBJECT"))
                .andExpect(jsonPath("$.data.rules[0].prefix").value("logs/"))
                .andExpect(jsonPath("$.data.rules[0].tags.stage").value("cold"))
                .andExpect(jsonPath("$.data.rules[0].retentionDays").value(15))
                .andExpect(jsonPath("$.data.rules[0].batchSize").value(100))
                .andExpect(jsonPath("$.data.rules[1].name").value("Imported versions"))
                .andExpect(jsonPath("$.data.rules[1].enabled").value(false))
                .andExpect(jsonPath("$.data.rules[1].priority").value(20))
                .andExpect(jsonPath("$.data.rules[1].targetType").value("OBJECT_VERSION"))
                .andExpect(jsonPath("$.data.rules[1].retentionDays").value(45))
                .andReturn()
                .getResponse()
                .getContentAsString();
        List<String> importedRuleIds = JsonPath.read(importResponse, "$.data.rules[*].ruleId");
        for (String ruleId : importedRuleIds) {
            mockMvc.perform(delete("/api/admin/object-lifecycle/rules/{ruleId}", ruleId)
                            .header("Authorization", "Bearer " + adminToken))
                    .andExpect(status().isNoContent());
        }
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
}
