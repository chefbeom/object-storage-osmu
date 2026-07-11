package com.example.osmu.bucket;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.example.osmu.object.StoredObjectRecord;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import java.time.OffsetDateTime;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class BucketObjectFlowTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectStorageAdapter storageAdapter;

    @Autowired
    private ObjectMetadataRepository objectMetadataRepository;

    @Test
    void bucketAndObjectFlowWorks() throws Exception {
        String bucketName = "flow-bucket";
        String accessToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "flow-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value(bucketName));

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "sample.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "hello osmu".getBytes()
        );

        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", bucketName)
                        .file(file)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("key", "docs/sample.txt"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.key").value("docs/sample.txt"));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].key").value("docs/sample.txt"));

        MvcResult downloadResult = mockMvc.perform(get("/api/buckets/{bucketName}/objects/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(downloadResult))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"sample.txt\""))
                .andExpect(content().string("hello osmu"));

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + accessToken)
                        .param("eventType", "OBJECT_DOWNLOAD")
                        .param("targetType", "OBJECT")
                        .param("targetId", "flow-bucket/docs/sample.txt")
                        .param("result", "SUCCESS")
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].actorId").value("admin"))
                .andExpect(jsonPath("$.items[0].message").value("Object download started"));

        String shareResponse = mockMvc.perform(post("/api/buckets/{bucketName}/objects/share-links", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "key": "docs/sample.txt",
                                  "expiresInSeconds": 120,
                                  "note": "department reuse",
                                  "maxDownloads": 2,
                                  "password": "SharePass!23",
                                  "allowedIpCidrs": "203.0.113.0/24"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.key").value("docs/sample.txt"))
                .andExpect(jsonPath("$.data.status").value("ACTIVE"))
                .andExpect(jsonPath("$.data.note").value("department reuse"))
                .andExpect(jsonPath("$.data.maxDownloads").value(2))
                .andExpect(jsonPath("$.data.downloadCount").value(0))
                .andExpect(jsonPath("$.data.lastAccessedAt").doesNotExist())
                .andExpect(jsonPath("$.data.passwordProtected").value(true))
                .andExpect(jsonPath("$.data.allowedIpCidrs").value("203.0.113.0/24"))
                .andExpect(jsonPath("$.data.ipRestricted").value(true))
                .andExpect(jsonPath("$.data.url").exists())
                .andExpect(jsonPath("$.data.token").exists())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String shareToken = JsonPath.read(shareResponse, "$.data.token");
        int shareLinkId = JsonPath.read(shareResponse, "$.data.id");

        mockMvc.perform(get("/api/public/share-links/{token}", shareToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

        mockMvc.perform(get("/api/public/share-links/{token}", shareToken)
                        .header("X-Forwarded-For", "203.0.113.10")
                        .header("X-OSMU-Share-Password", "wrong-password"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

        mockMvc.perform(get("/api/public/share-links/{token}", shareToken)
                        .header("X-Forwarded-For", "198.51.100.10")
                        .header("X-OSMU-Share-Password", "SharePass!23"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

        MvcResult allowedSharedDownloadResult = mockMvc.perform(get("/api/public/share-links/{token}", shareToken)
                        .header("X-Forwarded-For", "203.0.113.10")
                        .header("X-OSMU-Share-Password", "SharePass!23"))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(allowedSharedDownloadResult))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"sample.txt\""))
                .andExpect(content().string("hello osmu"));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/share-links", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("key", "docs/sample.txt"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value(shareLinkId))
                .andExpect(jsonPath("$.items[0].status").value("ACTIVE"))
                .andExpect(jsonPath("$.items[0].note").value("department reuse"))
                .andExpect(jsonPath("$.items[0].maxDownloads").value(2))
                .andExpect(jsonPath("$.items[0].downloadCount").value(1))
                .andExpect(jsonPath("$.items[0].lastAccessedAt").exists())
                .andExpect(jsonPath("$.items[0].passwordProtected").value(true))
                .andExpect(jsonPath("$.items[0].allowedIpCidrs").value("203.0.113.0/24"))
                .andExpect(jsonPath("$.items[0].ipRestricted").value(true))
                .andExpect(jsonPath("$.items[0].token").doesNotExist())
                .andExpect(jsonPath("$.items[0].url").doesNotExist());

        mockMvc.perform(delete("/api/buckets/{bucketName}/objects/share-links/{linkId}", bucketName, shareLinkId)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/public/share-links/{token}", shareToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

        String limitedShareResponse = mockMvc.perform(post("/api/buckets/{bucketName}/objects/share-links", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "key": "docs/sample.txt",
                                  "expiresInSeconds": 120,
                                  "note": "single use",
                                  "maxDownloads": 1
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.maxDownloads").value(1))
                .andExpect(jsonPath("$.data.passwordProtected").value(false))
                .andExpect(jsonPath("$.data.ipRestricted").value(false))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String limitedShareToken = JsonPath.read(limitedShareResponse, "$.data.token");
        int limitedShareLinkId = JsonPath.read(limitedShareResponse, "$.data.id");

        MvcResult limitedDownloadResult = mockMvc.perform(get("/api/public/share-links/{token}", limitedShareToken))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(limitedDownloadResult))
                .andExpect(status().isOk())
                .andExpect(content().string("hello osmu"));

        mockMvc.perform(get("/api/public/share-links/{token}", limitedShareToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/share-links", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("key", "docs/sample.txt"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value(limitedShareLinkId))
                .andExpect(jsonPath("$.items[0].status").value("LIMIT_REACHED"))
                .andExpect(jsonPath("$.items[0].downloadCount").value(1));

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/share-links/cleanup", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.bucketName").value(bucketName))
                .andExpect(jsonPath("$.data.expiredCount").value(0));

        MockMultipartFile overwriteFile = new MockMultipartFile(
                "file",
                "sample.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "hello v2".getBytes()
        );

        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", bucketName)
                        .file(overwriteFile)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("key", "docs/sample.txt"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.key").value("docs/sample.txt"))
                .andExpect(jsonPath("$.data.sizeBytes").value(8));

        String versionResponse = mockMvc.perform(get("/api/buckets/{bucketName}/objects/versions/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].key").value("docs/sample.txt"))
                .andExpect(jsonPath("$.data[0].sizeBytes").value(10))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String firstVersionId = JsonPath.read(versionResponse, "$.data[0].versionId");

        MvcResult versionDownloadResult = mockMvc.perform(get("/api/buckets/{bucketName}/objects/versions/{versionId}/download/docs/sample.txt", bucketName, firstVersionId)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(versionDownloadResult))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"sample.txt\""))
                .andExpect(content().string("hello osmu"));

        MvcResult overwrittenDownloadResult = mockMvc.perform(get("/api/buckets/{bucketName}/objects/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(overwrittenDownloadResult))
                .andExpect(status().isOk())
                .andExpect(content().string("hello v2"));

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/versions/{versionId}/restore/docs/sample.txt", bucketName, firstVersionId)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.key").value("docs/sample.txt"))
                .andExpect(jsonPath("$.data.sizeBytes").value(10));

        MvcResult versionRestoredDownloadResult = mockMvc.perform(get("/api/buckets/{bucketName}/objects/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(versionRestoredDownloadResult))
                .andExpect(status().isOk())
                .andExpect(content().string("hello osmu"));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/versions/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(2));

        mockMvc.perform(delete("/api/buckets/{bucketName}/objects/versions/{versionId}/delete/docs/sample.txt", bucketName, firstVersionId)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + accessToken)
                        .param("eventType", "OBJECT_VERSION_DELETE")
                        .param("targetType", "OBJECT")
                        .param("targetId", "flow-bucket/docs/sample.txt#" + firstVersionId)
                        .param("result", "SUCCESS")
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].actorId").value("admin"))
                .andExpect(jsonPath("$.items[0].targetId").value("flow-bucket/docs/sample.txt#" + firstVersionId));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/versions/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1));

        MockMultipartFile imageFile = new MockMultipartFile(
                "file",
                "sample.png",
                MediaType.IMAGE_PNG_VALUE,
                "fake-png".getBytes()
        );

        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", bucketName)
                        .file(imageFile)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("key", "images/sample.png"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.key").value("images/sample.png"));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("prefix", "docs/"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].key", hasItem("docs/sample.txt")))
                .andExpect(jsonPath("$.items[*].key", not(hasItem("images/sample.png"))));

        String nextCursor = JsonPath.read(mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].key").value("docs/sample.txt"))
                .andExpect(jsonPath("$.nextCursor").value("docs/sample.txt"))
                .andReturn()
                .getResponse()
                .getContentAsString(), "$.nextCursor");

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("limit", "1")
                        .param("cursor", nextCursor))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].key").value("images/sample.png"))
                .andExpect(jsonPath("$.nextCursor").doesNotExist());

        MockMultipartFile reportFile = new MockMultipartFile(
                "file",
                "report.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "nested report".getBytes()
        );

        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", bucketName)
                        .file(reportFile)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("key", "docs/2026/report.txt")
                        .param("tags", "project=osmu,stage=raw"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.key").value("docs/2026/report.txt"))
                .andExpect(jsonPath("$.data.tags.project").value("osmu"));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("prefix", "docs/")
                        .param("delimiter", "/"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.prefixes[*]", hasItem("docs/2026/")))
                .andExpect(jsonPath("$.items[*].key", hasItem("docs/sample.txt")))
                .andExpect(jsonPath("$.items[*].key", not(hasItem("docs/2026/report.txt"))));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("prefix", "docs/")
                        .param("delimiter", "/")
                        .param("search", "report"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].key", hasItem("docs/2026/report.txt")))
                .andExpect(jsonPath("$.items[*].key", not(hasItem("docs/sample.txt"))))
                .andExpect(jsonPath("$.prefixes").isEmpty());

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("prefix", "docs/")
                        .param("delimiter", "/")
                        .param("tag", "project=osmu"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].key", hasItem("docs/2026/report.txt")))
                .andExpect(jsonPath("$.items[0].tags.project").value("osmu"))
                .andExpect(jsonPath("$.items[*].key", not(hasItem("docs/sample.txt"))))
                .andExpect(jsonPath("$.prefixes").isEmpty());

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/metadata/docs/2026/report.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.key").value("docs/2026/report.txt"))
                .andExpect(jsonPath("$.data.sizeBytes").value(13))
                .andExpect(jsonPath("$.data.syncStatus").value("SYNCED"))
                .andExpect(jsonPath("$.data.tags.project").value("osmu"));

        mockMvc.perform(put("/api/buckets/{bucketName}/objects/tags", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "key": "docs/2026/report.txt",
                                  "tags": "project=archive,stage=curated"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.tags.project").value("archive"));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("prefix", "docs/")
                        .param("tag", "project=archive"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].key", hasItem("docs/2026/report.txt")))
                .andExpect(jsonPath("$.items[0].tags.stage").value("curated"));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/metadata/docs/2026/report.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.syncStatus").value("SYNCED"))
                .andExpect(jsonPath("$.data.tags.project").value("archive"))
                .andExpect(jsonPath("$.data.tags.stage").value("curated"));

        mockMvc.perform(delete("/api/buckets/{bucketName}/objects/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].key", not(hasItem("docs/sample.txt"))));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("deleted", "true"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].key", hasItem("docs/sample.txt")))
                .andExpect(jsonPath("$.items[0].deletedAt").exists());

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/restore/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.key").value("docs/sample.txt"));

        MvcResult restoredDownloadResult = mockMvc.perform(get("/api/buckets/{bucketName}/objects/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(restoredDownloadResult))
                .andExpect(status().isOk())
                .andExpect(content().string("hello osmu"));

        mockMvc.perform(delete("/api/buckets/{bucketName}/objects/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/purge/docs/sample.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + accessToken)
                        .param("eventType", "OBJECT_PURGE")
                        .param("targetType", "OBJECT")
                        .param("targetId", "flow-bucket/docs/sample.txt")
                        .param("result", "SUCCESS")
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].actorId").value("admin"))
                .andExpect(jsonPath("$.items[0].targetId").value("flow-bucket/docs/sample.txt"));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", bucketName)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("deleted", "true"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].key", not(hasItem("docs/sample.txt"))));

        mockMvc.perform(delete("/api/buckets/{bucketName}/objects/docs/2026/report.txt", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(delete("/api/buckets/{bucketName}/objects/images/sample.png", bucketName)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNoContent());
    }

    @Test
    void userCanAccessOnlyOwnedBucket() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        createUser(adminToken, "bucket-owner-user", "bucket-owner-user@example.com");
        String userToken = loginAndReturnAccessToken("bucket-owner-user", "user-password");

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "admin-private-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "user-owned-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("user-owned-bucket"));

        mockMvc.perform(get("/api/buckets")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("user-owned-bucket")))
                .andExpect(jsonPath("$.items[*].name", not(hasItem("admin-private-bucket"))));

        mockMvc.perform(get("/api/buckets/admin-private-bucket")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "blocked.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "blocked".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "admin-private-bucket")
                        .file(file)
                        .header("Authorization", "Bearer " + userToken)
                        .param("key", "blocked.txt"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));
    }

    @Test
    void orgAdminCanCreateOrgBucketForMembers() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int organizationId = createOrganization(adminToken, "Bucket Org 1");
        createUser(adminToken, "org-admin-bucket-1", "org-admin-bucket-1@example.com", "ORG_ADMIN", organizationId);
        createUser(adminToken, "org-member-bucket-1", "org-member-bucket-1@example.com", "USER", organizationId);
        createUser(adminToken, "org-outsider-bucket-1", "org-outsider-bucket-1@example.com", "USER", null);

        String orgAdminToken = loginAndReturnAccessToken("org-admin-bucket-1", "user-password");
        String orgMemberToken = loginAndReturnAccessToken("org-member-bucket-1", "user-password");
        String outsiderToken = loginAndReturnAccessToken("org-outsider-bucket-1", "user-password");

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + orgAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "org-shared-bucket",
                                  "quotaBytes": 1024,
                                  "ownerType": "ORG",
                                  "ownerId": %d
                                }
                                """.formatted(organizationId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ownerType").value("ORG"))
                .andExpect(jsonPath("$.data.ownerId").value(organizationId));

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "shared.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "shared".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "org-shared-bucket")
                        .file(file)
                        .header("Authorization", "Bearer " + orgMemberToken)
                        .param("key", "shared.txt"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.key").value("shared.txt"));

        mockMvc.perform(get("/api/buckets")
                        .header("Authorization", "Bearer " + orgMemberToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("org-shared-bucket")));

        mockMvc.perform(get("/api/buckets/org-shared-bucket")
                        .header("Authorization", "Bearer " + outsiderToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        mockMvc.perform(delete("/api/buckets/org-shared-bucket")
                        .header("Authorization", "Bearer " + orgMemberToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));
    }

    @Test
    void orgBucketUploadRejectsOrganizationQuotaExceeded() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int organizationId = createOrganization(adminToken, "Small Quota Org 1", 8L);

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "small-org-bucket",
                                  "quotaBytes": 1024,
                                  "ownerType": "ORG",
                                  "ownerId": %d
                                }
                                """.formatted(organizationId)))
                .andExpect(status().isOk());

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "too-large.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "too-large".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "small-org-bucket")
                        .file(file)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("key", "too-large.txt"))
                .andExpect(status().isPayloadTooLarge())
                .andExpect(jsonPath("$.error.code").value("QUOTA_EXCEEDED"));
    }

    @Test
    void userBucketUploadRejectsUserQuotaPolicyExceeded() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int userId = createUser(adminToken, "small-quota-user-1", "small-quota-user-1@example.com");
        String userToken = loginAndReturnAccessToken("small-quota-user-1", "user-password");

        mockMvc.perform(put("/api/admin/quota-policies/USER/{targetId}", userId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "quotaBytes": 8
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "small-user-quota-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk());

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "too-large.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "too-large".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "small-user-quota-bucket")
                        .file(file)
                        .header("Authorization", "Bearer " + userToken)
                        .param("key", "too-large.txt"))
                .andExpect(status().isPayloadTooLarge())
                .andExpect(jsonPath("$.error.code").value("QUOTA_EXCEEDED"));
    }

    @Test
    void bucketUploadRejectsBucketQuotaPolicyExceeded() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        String bucketResponse = mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "bucket-policy-quota-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        int bucketId = JsonPath.read(bucketResponse, "$.data.id");

        mockMvc.perform(put("/api/admin/quota-policies/BUCKET/{targetId}", bucketId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "quotaBytes": 8
                                }
                                """))
                .andExpect(status().isOk());

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "too-large.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "too-large".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "bucket-policy-quota-bucket")
                        .file(file)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("key", "too-large.txt"))
                .andExpect(status().isPayloadTooLarge())
                .andExpect(jsonPath("$.error.code").value("QUOTA_EXCEEDED"));
    }

    @Test
    void orgBucketUploadRejectsOrganizationQuotaPolicyExceeded() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int organizationId = createOrganization(adminToken, "Policy Quota Org 1", 1024L);

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "org-policy-quota-bucket",
                                  "quotaBytes": 1024,
                                  "ownerType": "ORG",
                                  "ownerId": %d
                                }
                                """.formatted(organizationId)))
                .andExpect(status().isOk());

        mockMvc.perform(put("/api/admin/quota-policies/ORGANIZATION/{targetId}", organizationId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "quotaBytes": 8
                                }
                                """))
                .andExpect(status().isOk());

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "too-large.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "too-large".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "org-policy-quota-bucket")
                        .file(file)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("key", "too-large.txt"))
                .andExpect(status().isPayloadTooLarge())
                .andExpect(jsonPath("$.error.code").value("QUOTA_EXCEEDED"));
    }

    @Test
    void bucketPermissionGrantControlsObjectActions() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        createUser(adminToken, "permission-owner-1", "permission-owner-1@example.com");
        int readerWriterId = createUser(adminToken, "permission-target-1", "permission-target-1@example.com");
        String ownerToken = loginAndReturnAccessToken("permission-owner-1", "user-password");
        String targetToken = loginAndReturnAccessToken("permission-target-1", "user-password");

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "permission-bucket-1",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk());

        MockMultipartFile seedFile = new MockMultipartFile(
                "file",
                "seed.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "seed".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "permission-bucket-1")
                        .file(seedFile)
                        .header("Authorization", "Bearer " + ownerToken)
                        .param("key", "seed.txt"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "permission-write-bucket-1",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/buckets/permission-bucket-1")
                        .header("Authorization", "Bearer " + targetToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        String readGrantResponse = mockMvc.perform(post("/api/buckets/{bucketName}/permissions", "permission-bucket-1")
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "subjectType": "USER",
                                  "subjectId": %d,
                                  "permissions": ["READ"]
                                }
                                """.formatted(readerWriterId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].permission", hasItem("READ")))
                .andReturn()
                .getResponse()
                .getContentAsString();
        int readPermissionId = JsonPath.read(readGrantResponse, "$.items[0].id");

        mockMvc.perform(get("/api/buckets")
                        .header("Authorization", "Bearer " + targetToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("permission-bucket-1")))
                .andExpect(jsonPath("$.items[*].name", not(hasItem("permission-write-bucket-1"))));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", "permission-bucket-1")
                        .header("Authorization", "Bearer " + targetToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].key", hasItem("seed.txt")));

        mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + targetToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "read-only-key",
                                  "allowedBuckets": ["permission-bucket-1"],
                                  "permissions": ["READ"]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.permissions[*]", hasItem("READ")));

        mockMvc.perform(post("/api/buckets/{bucketName}/permissions", "permission-write-bucket-1")
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "subjectType": "USER",
                                  "subjectId": %d,
                                  "permissions": ["WRITE"]
                                }
                                """.formatted(readerWriterId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].permission", hasItem("WRITE")));

        mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + targetToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "mixed-scope-key",
                                  "bucketScopes": [
                                    {
                                      "bucketName": "permission-bucket-1",
                                      "permissions": ["READ"]
                                    },
                                    {
                                      "bucketName": "permission-write-bucket-1",
                                      "permissions": ["WRITE"]
                                    }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.bucketScopes[*].bucketName", hasItem("permission-bucket-1")))
                .andExpect(jsonPath("$.data.bucketScopes[*].bucketName", hasItem("permission-write-bucket-1")));

        mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + targetToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "blocked-write-key",
                                  "allowedBuckets": ["permission-bucket-1"],
                                  "permissions": ["WRITE"]
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        MockMultipartFile blockedFile = new MockMultipartFile(
                "file",
                "blocked.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "blocked".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "permission-bucket-1")
                        .file(blockedFile)
                        .header("Authorization", "Bearer " + targetToken)
                        .param("key", "blocked.txt"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        mockMvc.perform(delete("/api/buckets/{bucketName}/permissions/{permissionId}", "permission-bucket-1", readPermissionId)
                        .header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", "permission-bucket-1")
                        .header("Authorization", "Bearer " + targetToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        mockMvc.perform(get("/api/buckets")
                        .header("Authorization", "Bearer " + targetToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", not(hasItem("permission-bucket-1"))))
                .andExpect(jsonPath("$.items[*].name", hasItem("permission-write-bucket-1")));

        mockMvc.perform(get("/api/access-keys")
                        .header("Authorization", "Bearer " + targetToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.name == 'read-only-key')].status", hasItem("INACTIVE")))
                .andExpect(jsonPath("$.items[?(@.name == 'mixed-scope-key')].status", hasItem("ACTIVE")))
                .andExpect(jsonPath("$.items[?(@.name == 'mixed-scope-key')].bucketScopes[0].bucketName", hasItem("permission-write-bucket-1")));

        mockMvc.perform(post("/api/buckets/{bucketName}/permissions", "permission-bucket-1")
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "subjectType": "USER",
                                  "subjectId": %d,
                                  "permissions": ["WRITE", "DELETE"]
                                }
                                """.formatted(readerWriterId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].permission", hasItem("WRITE")))
                .andExpect(jsonPath("$.items[*].permission", hasItem("DELETE")));

        MockMultipartFile grantedFile = new MockMultipartFile(
                "file",
                "granted.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "granted".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "permission-bucket-1")
                        .file(grantedFile)
                        .header("Authorization", "Bearer " + targetToken)
                        .param("key", "granted.txt"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.key").value("granted.txt"));

        mockMvc.perform(delete("/api/buckets/{bucketName}/objects/granted.txt", "permission-bucket-1")
                        .header("Authorization", "Bearer " + targetToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/buckets/{bucketName}/permissions", "permission-bucket-1")
                        .header("Authorization", "Bearer " + targetToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));
    }

    @Test
    void teamBucketPermissionAppliesToTeamMembers() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int organizationId = createOrganization(adminToken, "Team Permission Org 1");
        int memberId = createUser(adminToken, "team-permission-member-1", "team-permission-member-1@example.com", "USER", organizationId);
        int outsiderId = createUser(adminToken, "team-permission-outsider-1", "team-permission-outsider-1@example.com", "USER", organizationId);
        String memberToken = loginAndReturnAccessToken("team-permission-member-1", "user-password");
        String outsiderToken = loginAndReturnAccessToken("team-permission-outsider-1", "user-password");

        String teamResponse = mockMvc.perform(post("/api/admin/teams")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "organizationId": %d,
                                  "name": "Permission Team",
                                  "description": "bucket permission team",
                                  "memberIds": [%d]
                                }
                                """.formatted(organizationId, memberId)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        int teamId = JsonPath.read(teamResponse, "$.data.id");

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "team-permission-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk());

        MockMultipartFile seedFile = new MockMultipartFile(
                "file",
                "team-seed.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "team-seed".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "team-permission-bucket")
                        .file(seedFile)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("key", "team-seed.txt"))
                .andExpect(status().isOk());

        String permissionResponse = mockMvc.perform(post("/api/buckets/{bucketName}/permissions", "team-permission-bucket")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "subjectType": "TEAM",
                                  "subjectId": %d,
                                  "permissions": ["READ"]
                                }
                                """.formatted(teamId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.subjectType == 'TEAM' && @.subjectId == %d)]".formatted(teamId)).exists())
                .andReturn()
                .getResponse()
                .getContentAsString();
        int permissionId = JsonPath.read(permissionResponse, "$.items[0].id");

        mockMvc.perform(get("/api/buckets")
                        .header("Authorization", "Bearer " + memberToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", hasItem("team-permission-bucket")));

        mockMvc.perform(get("/api/buckets")
                        .header("Authorization", "Bearer " + outsiderToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", not(hasItem("team-permission-bucket"))));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", "team-permission-bucket")
                        .header("Authorization", "Bearer " + memberToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].key", hasItem("team-seed.txt")));

        mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + memberToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "team-read-key",
                                  "allowedBuckets": ["team-permission-bucket"],
                                  "permissions": ["READ"]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.permissions[*]", hasItem("READ")));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", "team-permission-bucket")
                        .header("Authorization", "Bearer " + outsiderToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        mockMvc.perform(delete("/api/buckets/{bucketName}/permissions/{permissionId}", "team-permission-bucket", permissionId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", "team-permission-bucket")
                        .header("Authorization", "Bearer " + memberToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        mockMvc.perform(get("/api/buckets")
                        .header("Authorization", "Bearer " + memberToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[*].name", not(hasItem("team-permission-bucket"))));

        mockMvc.perform(get("/api/access-keys")
                        .header("Authorization", "Bearer " + memberToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.name == 'team-read-key')].status", hasItem("INACTIVE")));

        mockMvc.perform(put("/api/admin/teams/{teamId}/members", teamId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "memberIds": [%d]
                                }
                                """.formatted(outsiderId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.memberIds[*]", hasItem(outsiderId)));
    }

    @Test
    void bucketSyncReconcilesObjectsWrittenThroughS3Path() throws Exception {
        String accessToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "sync-direct-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.usedBytes").value(0))
                .andExpect(jsonPath("$.data.objectCount").value(0));

        storageAdapter.putObject("sync-direct-bucket", "direct/s3-object.txt", "direct-write".getBytes(), MediaType.TEXT_PLAIN_VALUE);
        objectMetadataRepository.save(
                "sync-direct-bucket",
                new StoredObjectRecord("ghost.txt", 5L, MediaType.TEXT_PLAIN_VALUE, OffsetDateTime.now())
        );

        mockMvc.perform(post("/api/buckets/{bucketName}/sync", "sync-direct-bucket")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.usedBytes").value(12))
                .andExpect(jsonPath("$.data.objectCount").value(1))
                .andExpect(jsonPath("$.data.previousUsedBytes").value(0))
                .andExpect(jsonPath("$.data.previousObjectCount").value(0))
                .andExpect(jsonPath("$.data.storageObjectCount").value(1))
                .andExpect(jsonPath("$.data.visibleStorageObjectCount").value(1))
                .andExpect(jsonPath("$.data.metadataObjectCountBefore").value(1))
                .andExpect(jsonPath("$.data.metadataObjectCountAfter").value(1))
                .andExpect(jsonPath("$.data.metadataAddedCount").value(1))
                .andExpect(jsonPath("$.data.metadataUpdatedCount").value(0))
                .andExpect(jsonPath("$.data.metadataRemovedCount").value(1));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects", "sync-direct-bucket")
                        .header("Authorization", "Bearer " + accessToken)
                        .param("prefix", "direct/"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].key").value("direct/s3-object.txt"));
    }

    @Test
    void objectMetadataReportsStorageDriftAndSyncRecovery() throws Exception {
        String accessToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "drift-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk());

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "drift.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "indexed".getBytes()
        );

        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "drift-bucket")
                        .file(file)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("key", "drift.txt")
                        .param("tags", "project=osmu"))
                .andExpect(status().isOk());

        storageAdapter.putObject("drift-bucket", "drift.txt", "changed-content".getBytes(), MediaType.TEXT_PLAIN_VALUE);

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/metadata/drift.txt", "drift-bucket")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.syncStatus").value("STALE"))
                .andExpect(jsonPath("$.data.sizeBytes").value(7))
                .andExpect(jsonPath("$.data.storageSizeBytes").value(15));

        mockMvc.perform(post("/api/buckets/{bucketName}/sync", "drift-bucket")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.metadataAddedCount").value(0))
                .andExpect(jsonPath("$.data.metadataUpdatedCount").value(1))
                .andExpect(jsonPath("$.data.metadataRemovedCount").value(0));

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/metadata/drift.txt", "drift-bucket")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.syncStatus").value("SYNCED"))
                .andExpect(jsonPath("$.data.sizeBytes").value(15));
    }

    @Test
    void bucketSyncPreservesChecksumOnlyWhenStorageEtagStillMatches() throws Exception {
        String accessToken = loginAndReturnAccessToken("admin", "password");
        String checksum = "ZXbcLmKjH2t4wT9hmjgGJaa2mILR8+vgkzqagm7UHv4=";

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "sync-checksum-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk());

        StoredObjectRecord original = storageAdapter.putObject(
                "sync-checksum-bucket",
                "checksum.txt",
                "same-body".getBytes(),
                MediaType.TEXT_PLAIN_VALUE
        );
        objectMetadataRepository.save(
                "sync-checksum-bucket",
                original.withChecksums(Map.of("x-amz-checksum-sha256", checksum))
        );

        mockMvc.perform(post("/api/buckets/{bucketName}/sync", "sync-checksum-bucket")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/metadata/checksum.txt", "sync-checksum-bucket")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.checksums['x-amz-checksum-sha256']").value(checksum));

        storageAdapter.putObject(
                "sync-checksum-bucket",
                "checksum.txt",
                "changed-body".getBytes(),
                MediaType.TEXT_PLAIN_VALUE
        );

        mockMvc.perform(post("/api/buckets/{bucketName}/sync", "sync-checksum-bucket")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/buckets/{bucketName}/objects/metadata/checksum.txt", "sync-checksum-bucket")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.checksums").isEmpty());
    }

    @Test
    void objectTagsRejectInvalidPolicy() throws Exception {
        String accessToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "tag-policy-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk());

        MockMultipartFile invalidKeyFile = new MockMultipartFile(
                "file",
                "invalid-key.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "invalid-key".getBytes()
        );

        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "tag-policy-bucket")
                        .file(invalidKeyFile)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("key", "invalid-key.txt")
                        .param("tags", "bad key=value"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));

        MockMultipartFile longValueFile = new MockMultipartFile(
                "file",
                "long-value.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "long-value".getBytes()
        );

        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "tag-policy-bucket")
                        .file(longValueFile)
                        .header("Authorization", "Bearer " + accessToken)
                        .param("key", "long-value.txt")
                        .param("tags", "project=%s".formatted("x".repeat(257))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
    }

    @Test
    void presignedUrlKeepsOwnerGuardAndReportsUnsupportedMemoryMode() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");

        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "presigned-owner-bucket",
                                  "quotaBytes": 1024
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/presigned-upload", "presigned-owner-bucket")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "key": "large/video.mp4",
                                  "contentType": "video/mp4",
                                  "expiresInSeconds": 900
                                }
                                """))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.error.code").value("STORAGE_ERROR"));

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/presigned-upload/complete", "presigned-owner-bucket")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "uploadId": "missing-upload-id",
                                  "key": "large/video.mp4"
                                }
                                """))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/multipart-upload", "presigned-owner-bucket")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "key": "large/multipart-video.mp4",
                                  "contentType": "video/mp4",
                                  "sizeBytes": 512,
                                  "partSizeBytes": 512,
                                  "expiresInSeconds": 900
                                }
                                """))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.error.code").value("STORAGE_ERROR"));

        createUser(adminToken, "presigned-limited-user", "presigned-limited-user@example.com");
        String userToken = loginAndReturnAccessToken("presigned-limited-user", "user-password");

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/presigned-upload", "presigned-owner-bucket")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "key": "blocked.mp4",
                                  "expiresInSeconds": 900
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));

        mockMvc.perform(post("/api/buckets/{bucketName}/objects/multipart-upload", "presigned-owner-bucket")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "key": "blocked-multipart.mp4",
                                  "sizeBytes": 10485760,
                                  "partSizeBytes": 5242880,
                                  "expiresInSeconds": 900
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("AUTHORIZATION_FAILED"));
    }

    private int createUser(String adminToken, String loginId, String email) throws Exception {
        return createUser(adminToken, loginId, email, "USER", null);
    }

    private int createUser(String adminToken, String loginId, String email, String role, Integer organizationId) throws Exception {
        String organizationJson = organizationId == null ? "null" : String.valueOf(organizationId);
        String response = mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s",
                                  "name": "Bucket Owner",
                                  "password": "user-password",
                                  "role": "%s",
                                  "organizationId": %s
                                }
                                """.formatted(loginId, email, role, organizationJson)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.id");
    }

    private int createOrganization(String adminToken, String name) throws Exception {
        return createOrganization(adminToken, name, 1099511627776L);
    }

    private int createOrganization(String adminToken, String name, long defaultQuotaBytes) throws Exception {
        String response = mockMvc.perform(post("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "description": "bucket test org",
                                  "defaultQuotaBytes": %d
                                }
                                """.formatted(name, defaultQuotaBytes)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.id");
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
