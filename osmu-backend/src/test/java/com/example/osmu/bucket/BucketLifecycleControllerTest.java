package com.example.osmu.bucket;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jayway.jsonpath.JsonPath;
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
class BucketLifecycleControllerTest {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanPutGetAndDeleteBucketLifecycleConfiguration() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-bucket";
        createBucket(token, bucketName);

        String lifecycleXml = """
                <LifecycleConfiguration>
                  <Rule>
                    <ID>Bucket raw trash</ID>
                    <Status>Enabled</Status>
                    <Filter>
                      <And>
                        <Prefix>videos/raw/</Prefix>
                        <Tag><Key>stage</Key><Value>raw</Value></Tag>
                      </And>
                    </Filter>
                    <Expiration><Days>10</Days></Expiration>
                  </Rule>
                </LifecycleConfiguration>
                """;

        String putResponse = mockMvc.perform(put("/api/buckets/{bucketName}/lifecycle", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(OBJECT_MAPPER.writeValueAsString(Map.of("xml", lifecycleXml))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.importedCount").value(1))
                .andExpect(jsonPath("$.data.rules[0].bucketName").value(bucketName))
                .andExpect(jsonPath("$.data.rules[0].name").value("Bucket raw trash"))
                .andExpect(jsonPath("$.data.rules[0].targetType").value("TRASH_OBJECT"))
                .andExpect(jsonPath("$.data.rules[0].prefix").value("videos/raw/"))
                .andExpect(jsonPath("$.data.rules[0].tags.stage").value("raw"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String firstRuleId = JsonPath.read(putResponse, "$.data.rules[0].ruleId");

        mockMvc.perform(get("/api/buckets/{bucketName}/lifecycle", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ruleCount").value(1))
                .andExpect(jsonPath("$.data.xml").value(org.hamcrest.Matchers.containsString("Bucket raw trash")))
                .andExpect(jsonPath("$.data.xml").value(org.hamcrest.Matchers.containsString("<Expiration>")));

        String replacementXml = """
                <LifecycleConfiguration>
                  <Rule>
                    <ID>Bucket versions</ID>
                    <Status>Enabled</Status>
                    <Filter><Prefix>videos/</Prefix></Filter>
                    <NoncurrentVersionExpiration><NoncurrentDays>30</NoncurrentDays></NoncurrentVersionExpiration>
                  </Rule>
                </LifecycleConfiguration>
                """;

        mockMvc.perform(put("/api/buckets/{bucketName}/lifecycle", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(OBJECT_MAPPER.writeValueAsString(Map.of("xml", replacementXml))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.importedCount").value(1))
                .andExpect(jsonPath("$.data.rules[0].bucketName").value(bucketName))
                .andExpect(jsonPath("$.data.rules[0].targetType").value("OBJECT_VERSION"));

        mockMvc.perform(get("/api/admin/object-lifecycle/rules")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[?(@.ruleId == '%s')]".formatted(firstRuleId)).isEmpty());

        mockMvc.perform(delete("/api/buckets/{bucketName}/lifecycle", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/buckets/{bucketName}/lifecycle", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ruleCount").value(0));

        mockMvc.perform(get("/api/admin/audit-logs")
                        .header("Authorization", "Bearer " + token)
                        .param("eventType", "BUCKET_LIFECYCLE_DELETE")
                        .param("targetId", bucketName)
                        .param("limit", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].actorId").value("admin"));
    }

    @Test
    void adminCanUseRawXmlBucketLifecycleConfiguration() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-xml-bucket";
        createBucket(token, bucketName);

        String lifecycleXml = """
                <LifecycleConfiguration>
                  <Rule>
                    <ID>Raw XML versions</ID>
                    <Status>Enabled</Status>
                    <Filter><Prefix>archive/</Prefix></Filter>
                    <NoncurrentVersionExpiration><NoncurrentDays>90</NoncurrentDays></NoncurrentVersionExpiration>
                  </Rule>
                </LifecycleConfiguration>
                """;

        mockMvc.perform(put("/api/buckets/{bucketName}/lifecycle", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content(lifecycleXml))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/buckets/{bucketName}/lifecycle", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<LifecycleConfiguration")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Raw XML versions")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<NoncurrentVersionExpiration>")));

        mockMvc.perform(get("/api/buckets/{bucketName}/lifecycle", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.ruleCount").value(1))
                .andExpect(jsonPath("$.data.xml").value(org.hamcrest.Matchers.containsString("Raw XML versions")));
    }

    @Test
    void adminCanUseS3StyleLifecycleQueryAlias() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-query-bucket";
        createBucket(token, bucketName);

        String lifecycleXml = """
                <LifecycleConfiguration>
                  <Rule>
                    <ID>Query lifecycle</ID>
                    <Status>Enabled</Status>
                    <Filter><Prefix>media/</Prefix></Filter>
                    <Expiration><Days>21</Days></Expiration>
                  </Rule>
                </LifecycleConfiguration>
                """;

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content(lifecycleXml))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Query lifecycle")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Expiration>")));

        mockMvc.perform(delete("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isNotFound())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>NoSuchLifecycleConfiguration</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>The lifecycle configuration does not exist.</Message>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<BucketName>" + bucketName + "</BucketName>")));
    }

    @Test
    void missingS3BucketLifecycleBodyReturnsMissingRequestBodyError() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-missing-body-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>MissingRequestBodyError</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>Request body is empty.</Message>")));
    }

    @Test
    void unexpectedS3BucketLifecycleRootReturnsMalformedXml() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-invalid-root-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <NotLifecycleConfiguration>
                                  <Rule>
                                    <ID>Wrong root</ID>
                                    <Status>Enabled</Status>
                                    <Filter><Prefix>tmp/</Prefix></Filter>
                                    <Expiration><Days>7</Days></Expiration>
                                  </Rule>
                                </NotLifecycleConfiguration>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>MalformedXML</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>The XML you provided was not well-formed or did not validate against our published schema.</Message>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isNotFound())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>NoSuchLifecycleConfiguration</Code>")));
    }

    @Test
    void invalidS3BucketLifecycleStatusReturnsMalformedXml() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-invalid-status-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <LifecycleConfiguration>
                                  <Rule>
                                    <ID>Missing status</ID>
                                    <Filter><Prefix>tmp/</Prefix></Filter>
                                    <Expiration><Days>7</Days></Expiration>
                                  </Rule>
                                </LifecycleConfiguration>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>MalformedXML</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>The XML you provided was not well-formed or did not validate against our published schema.</Message>")));

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <LifecycleConfiguration>
                                  <Rule>
                                    <ID>Invalid status</ID>
                                    <Status>Paused</Status>
                                    <Filter><Prefix>tmp/</Prefix></Filter>
                                    <Expiration><Days>7</Days></Expiration>
                                  </Rule>
                                </LifecycleConfiguration>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>MalformedXML</Code>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isNotFound())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>NoSuchLifecycleConfiguration</Code>")));
    }

    @Test
    void invalidS3BucketLifecycleFilterShapeReturnsMalformedXml() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-invalid-filter-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <LifecycleConfiguration>
                                  <Rule>
                                    <ID>Invalid filter shape</ID>
                                    <Status>Enabled</Status>
                                    <Filter>
                                      <Prefix>tmp/</Prefix>
                                      <Tag><Key>stage</Key><Value>raw</Value></Tag>
                                    </Filter>
                                    <Expiration><Days>7</Days></Expiration>
                                  </Rule>
                                </LifecycleConfiguration>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>MalformedXML</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>The XML you provided was not well-formed or did not validate against our published schema.</Message>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isNotFound())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>NoSuchLifecycleConfiguration</Code>")));
    }

    @Test
    void unsupportedS3BucketLifecycleObjectSizeFilterReturnsInvalidRequest() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-unsupported-filter-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <LifecycleConfiguration>
                                  <Rule>
                                    <ID>Unsupported object size filter</ID>
                                    <Status>Enabled</Status>
                                    <Filter><ObjectSizeGreaterThan>1024</ObjectSizeGreaterThan></Filter>
                                    <Expiration><Days>7</Days></Expiration>
                                  </Rule>
                                </LifecycleConfiguration>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>InvalidRequest</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>Unsupported Lifecycle filter predicate ObjectSizeGreaterThan.</Message>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isNotFound())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>NoSuchLifecycleConfiguration</Code>")));
    }

    @Test
    void unsupportedS3BucketLifecycleActionReturnsInvalidRequest() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-unsupported-action-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <LifecycleConfiguration>
                                  <Rule>
                                    <ID>Unsupported transition</ID>
                                    <Status>Enabled</Status>
                                    <Filter><Prefix>tmp/</Prefix></Filter>
                                    <Transition>
                                      <Days>30</Days>
                                      <StorageClass>GLACIER</StorageClass>
                                    </Transition>
                                  </Rule>
                                </LifecycleConfiguration>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>InvalidRequest</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>Unsupported Lifecycle action Transition.</Message>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isNotFound())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>NoSuchLifecycleConfiguration</Code>")));
    }

    @Test
    void multipleS3BucketLifecycleActionsReturnInvalidRequest() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-multiple-actions-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <LifecycleConfiguration>
                                  <Rule>
                                    <ID>Multiple actions</ID>
                                    <Status>Enabled</Status>
                                    <Filter><Prefix>tmp/</Prefix></Filter>
                                    <Expiration><Days>7</Days></Expiration>
                                    <NoncurrentVersionExpiration><NoncurrentDays>30</NoncurrentDays></NoncurrentVersionExpiration>
                                  </Rule>
                                </LifecycleConfiguration>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>InvalidRequest</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>Unsupported Lifecycle action combination.</Message>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isNotFound())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>NoSuchLifecycleConfiguration</Code>")));
    }

    @Test
    void invalidS3BucketLifecycleTagRestrictionsReturnInvalidRequest() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-invalid-tag-bucket";
        createBucket(token, bucketName);
        String longTagKey = "k".repeat(129);
        String longTagValue = "v".repeat(257);
        String elevenTags = java.util.stream.IntStream.rangeClosed(1, 11)
                .mapToObj(index -> "<Tag><Key>k" + index + "</Key><Value>v" + index + "</Value></Tag>")
                .collect(java.util.stream.Collectors.joining("\n"));

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <LifecycleConfiguration>
                                  <Rule>
                                    <ID>Invalid tag key</ID>
                                    <Status>Enabled</Status>
                                    <Filter><Tag><Key>%s</Key><Value>raw</Value></Tag></Filter>
                                    <Expiration><Days>7</Days></Expiration>
                                  </Rule>
                                </LifecycleConfiguration>
                                """.formatted(longTagKey)))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>InvalidRequest</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>Invalid Lifecycle tag key.</Message>")));

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <LifecycleConfiguration>
                                  <Rule>
                                    <ID>Invalid tag value</ID>
                                    <Status>Enabled</Status>
                                    <Filter><Tag><Key>stage</Key><Value>%s</Value></Tag></Filter>
                                    <Expiration><Days>7</Days></Expiration>
                                  </Rule>
                                </LifecycleConfiguration>
                                """.formatted(longTagValue)))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>InvalidRequest</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>Invalid Lifecycle tag value.</Message>")));

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <LifecycleConfiguration>
                                  <Rule>
                                    <ID>Duplicate tag key</ID>
                                    <Status>Enabled</Status>
                                    <Filter>
                                      <And>
                                        <Tag><Key>stage</Key><Value>raw</Value></Tag>
                                        <Tag><Key>stage</Key><Value>cold</Value></Tag>
                                      </And>
                                    </Filter>
                                    <Expiration><Days>7</Days></Expiration>
                                  </Rule>
                                </LifecycleConfiguration>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>InvalidRequest</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>Duplicate Lifecycle tag key is not allowed.</Message>")));

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <LifecycleConfiguration>
                                  <Rule>
                                    <ID>Too many tags</ID>
                                    <Status>Enabled</Status>
                                    <Filter><And>%s</And></Filter>
                                    <Expiration><Days>7</Days></Expiration>
                                  </Rule>
                                </LifecycleConfiguration>
                                """.formatted(elevenTags)))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>InvalidRequest</Code>")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Message>Lifecycle tags can contain at most 10 pairs.</Message>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "Bearer " + token)
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isNotFound())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>NoSuchLifecycleConfiguration</Code>")));
    }

    @Test
    void accessKeyWithAdminScopeCanUseS3StyleLifecycleQueryAlias() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-key-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "ADMIN");

        String lifecycleXml = """
                <LifecycleConfiguration>
                  <Rule>
                    <ID>Access key lifecycle</ID>
                    <Status>Enabled</Status>
                    <Filter><Prefix>exports/</Prefix></Filter>
                    <Expiration><Days>14</Days></Expiration>
                  </Rule>
                </LifecycleConfiguration>
                """;

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .contentType(MediaType.APPLICATION_XML)
                        .content(lifecycleXml))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Access key lifecycle")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("Authorization", "AWS4-HMAC-SHA256 Credential=%s/20260613/us-east-1/s3/aws4_request, SignedHeaders=host, Signature=dummy".formatted(credentials.accessKey()))
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Access key lifecycle")));

        mockMvc.perform(delete("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isNoContent());
    }

    @Test
    void accessKeyWithoutAdminScopeCannotUseS3StyleLifecycleQueryAlias() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "lifecycle-key-denied-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ");

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("lifecycle", "")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isForbidden())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<Code>AccessDenied</Code>")));
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

    private AccessKeyCredentials createAccessKey(String token, String bucketName, String permission) throws Exception {
        String response = mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "lifecycle-alias-key",
                                  "bucketScopes": [
                                    {
                                      "bucketName": "%s",
                                      "permissions": ["%s"]
                                    }
                                  ],
                                  "expiresAt": null
                                }
                                """.formatted(bucketName, permission)))
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
