package com.example.osmu.admin;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.example.osmu.object.ObjectVersionRecord;
import com.example.osmu.object.ObjectVersionStorageKeys;
import com.example.osmu.object.StoredObjectRecord;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.jayway.jsonpath.JsonPath;
import java.time.OffsetDateTime;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class AdminObjectLifecycleRuleDryRunControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMetadataRepository objectMetadataRepository;

    @Autowired
    private ObjectVersionRepository objectVersionRepository;

    @Test
    void adminCanDryRunTrashLifecycleRule() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        OffsetDateTime now = OffsetDateTime.now();
        objectMetadataRepository.save("bucket", new StoredObjectRecord(
                "videos/raw/input.mp4",
                3L,
                "video/mp4",
                now.minusDays(10),
                Map.of("stage", "raw"),
                now.minusDays(8)
        ));
        objectMetadataRepository.save("bucket", new StoredObjectRecord(
                "videos/final/input.mp4",
                5L,
                "video/mp4",
                now.minusDays(10),
                Map.of("stage", "final"),
                now.minusDays(8)
        ));
        String ruleId = createRule(adminToken, "Raw trash", "TRASH_OBJECT");

        mockMvc.perform(get("/api/admin/object-lifecycle/rules/{ruleId}/dry-run", ruleId)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.rule.ruleId").value(ruleId))
                .andExpect(jsonPath("$.data.rule.targetType").value("TRASH_OBJECT"))
                .andExpect(jsonPath("$.data.previewLimit").value(10))
                .andExpect(jsonPath("$.data.purgeBatchSize").value(20))
                .andExpect(jsonPath("$.data.candidateCount").value(1))
                .andExpect(jsonPath("$.data.candidateBytes").value(3))
                .andExpect(jsonPath("$.data.truncated").value(false))
                .andExpect(jsonPath("$.data.candidates[0].targetId").value("bucket/videos/raw/input.mp4"));
    }

    @Test
    void adminCanDryRunVersionLifecycleRule() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        OffsetDateTime now = OffsetDateTime.now();
        objectVersionRepository.save("bucket", new ObjectVersionRecord(
                "raw-v1",
                "videos/raw/input.mp4",
                ObjectVersionStorageKeys.PREFIX + "videos/raw/v1",
                7L,
                "video/mp4",
                now.minusDays(20),
                now.minusDays(8),
                Map.of("stage", "raw")
        ));
        objectVersionRepository.save("bucket", new ObjectVersionRecord(
                "final-v1",
                "videos/final/input.mp4",
                ObjectVersionStorageKeys.PREFIX + "videos/final/v1",
                11L,
                "video/mp4",
                now.minusDays(20),
                now.minusDays(8),
                Map.of("stage", "final")
        ));
        String ruleId = createRule(adminToken, "Raw versions", "OBJECT_VERSION");

        mockMvc.perform(get("/api/admin/object-lifecycle/rules/{ruleId}/dry-run", ruleId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.rule.ruleId").value(ruleId))
                .andExpect(jsonPath("$.data.rule.targetType").value("OBJECT_VERSION"))
                .andExpect(jsonPath("$.data.candidateCount").value(1))
                .andExpect(jsonPath("$.data.candidateBytes").value(7))
                .andExpect(jsonPath("$.data.candidates[0].targetId").value("bucket/videos/raw/input.mp4#raw-v1"))
                .andExpect(jsonPath("$.data.candidates[0].versionId").value("raw-v1"));
    }

    private String createRule(String adminToken, String name, String targetType) throws Exception {
        String response = mockMvc.perform(post("/api/admin/object-lifecycle/rules")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "enabled": false,
                                  "targetType": "%s",
                                  "prefix": "videos/raw/",
                                  "tags": "stage=raw",
                                  "retentionDays": 7,
                                  "batchSize": 20
                                }
                                """.formatted(name, targetType)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.ruleId");
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
