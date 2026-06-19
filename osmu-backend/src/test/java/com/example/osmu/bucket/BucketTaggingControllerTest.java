package com.example.osmu.bucket;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.Arrays;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class BucketTaggingControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanPutGetAndDeleteRestBucketTags() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "rest-bucket-tags-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/buckets/{bucketName}/tags", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "tags": {
                                    "project": "osmu",
                                    "stage": "rest"
                                  }
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.bucketName").value(bucketName))
                .andExpect(jsonPath("$.data.tagCount").value(2))
                .andExpect(jsonPath("$.data.tags.project").value("osmu"))
                .andExpect(jsonPath("$.data.tags.stage").value("rest"));

        mockMvc.perform(get("/api/buckets/{bucketName}/tags", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.bucketName").value(bucketName))
                .andExpect(jsonPath("$.data.tagCount").value(2))
                .andExpect(jsonPath("$.data.tags.project").value("osmu"));

        mockMvc.perform(put("/api/buckets/{bucketName}/tags", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "tags": {
                                    "bad key": "value"
                                  }
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));

        mockMvc.perform(delete("/api/buckets/{bucketName}/tags", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/buckets/{bucketName}/tags", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.tagCount").value(0))
                .andExpect(jsonPath("$.data.tags.project").doesNotExist());

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + token)
                        .param("eventType", "BUCKET_TAGS_DELETE")
                        .param("targetId", bucketName)
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].actorId").value("admin"));
    }

    @Test
    void adminCanPutGetAndDeleteS3BucketTagging() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-bucket-tagging-bucket";
        createBucket(token, bucketName);

        String taggingXml = """
                <Tagging xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                  <TagSet>
                    <Tag><Key>project</Key><Value>osmu</Value></Tag>
                    <Tag><Key>stage</Key><Value>prototype</Value></Tag>
                  </TagSet>
                </Tagging>
                """;

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("tagging", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content(taggingXml))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("tagging", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Tagging xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">")))
                .andExpect(content().string(containsString("<Key>project</Key>")))
                .andExpect(content().string(containsString("<Value>osmu</Value>")))
                .andExpect(content().string(containsString("<Key>stage</Key>")));

        mockMvc.perform(delete("/api/s3/{bucketName}", bucketName)
                        .queryParam("tagging", "")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("tagging", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(not(containsString("<Key>project</Key>"))));

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + token)
                        .param("eventType", "S3_BUCKET_TAGGING_DELETE")
                        .param("targetId", bucketName)
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].actorId").value("admin"));
    }

    @Test
    void accessKeyWithAdminScopeCanManageS3BucketTagging() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-bucket-tagging-key-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials adminKey = createAccessKey(token, bucketName, "ADMIN");
        AccessKeyCredentials readKey = createAccessKey(token, bucketName, "READ");

        String taggingXml = """
                <Tagging>
                  <TagSet>
                    <Tag><Key>owner</Key><Value>platform</Value></Tag>
                  </TagSet>
                </Tagging>
                """;

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("tagging", "")
                        .header("X-OSMU-Access-Key", adminKey.accessKey())
                        .header("X-OSMU-Secret-Key", adminKey.secretKey())
                        .contentType(MediaType.APPLICATION_XML)
                        .content(taggingXml))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("tagging", "")
                        .header("X-OSMU-Access-Key", adminKey.accessKey())
                        .header("X-OSMU-Secret-Key", adminKey.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<Key>owner</Key>")))
                .andExpect(content().string(containsString("<Value>platform</Value>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("tagging", "")
                        .header("X-OSMU-Access-Key", readKey.accessKey())
                        .header("X-OSMU-Secret-Key", readKey.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isForbidden())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>AccessDenied</Code>")));
    }

    @Test
    void invalidS3BucketTaggingXmlReturnsInvalidRequest() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-bucket-tagging-invalid-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("tagging", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("<Tagging><TagSet><Tag><Key>project</Key></Tag></TagSet></Tagging>"))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));
    }

    @Test
    void missingS3BucketTaggingBodyReturnsMissingRequestBodyError() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-bucket-tagging-missing-body";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("tagging", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>MissingRequestBodyError</Code>")))
                .andExpect(content().string(containsString("<Message>Request body is empty.</Message>")));
    }

    @Test
    void malformedS3BucketTaggingXmlReturnsMalformedXml() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-bucket-tagging-malformed-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("tagging", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("<Tagging><TagSet>"))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>MalformedXML</Code>")))
                .andExpect(content().string(containsString("<Message>The XML you provided was not well-formed or did not validate against our published schema.</Message>")));
    }

    private void createBucket(String token, String bucketName) throws Exception {
        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "quotaBytes": 1073741824
                                }
                                """.formatted(bucketName)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value(bucketName));
    }

    private AccessKeyCredentials createAccessKey(String token, String bucketName, String... permissions) throws Exception {
        String permissionList = Arrays.stream(permissions)
                .map(permission -> "\"" + permission + "\"")
                .collect(Collectors.joining(", "));
        String response = mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "bucket-tagging-key",
                                  "bucketScopes": [
                                    {
                                      "bucketName": "%s",
                                      "permissions": [%s]
                                    }
                                  ],
                                  "expiresAt": null
                                }
                                """.formatted(bucketName, permissionList)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return new AccessKeyCredentials(
                JsonPath.read(response, "$.data.accessKey"),
                JsonPath.read(response, "$.data.secretKey")
        );
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

    private record AccessKeyCredentials(String accessKey, String secretKey) {
    }
}
