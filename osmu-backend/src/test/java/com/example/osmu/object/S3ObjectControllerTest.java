package com.example.osmu.object;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.head;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.example.osmu.object.repository.ObjectVersionRepository;
import com.jayway.jsonpath.JsonPath;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import java.util.zip.CRC32C;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class S3ObjectControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectVersionRepository objectVersionRepository;

    @Test
    void accessKeyCanPutHeadGetAndDeleteObjectThroughS3StylePath() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-alias-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE", "DELETE");
        String uploadResource = "/api/s3/" + bucketName + "/docs/sample.txt";
        String uploadHostId = checksumBase64("SHA-256", "req-s3-upload-trace:" + uploadResource);

        MvcResult uploadResult = mockMvc.perform(put("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("X-Request-Id", "req-s3-upload-trace")
                        .header("x-amz-tagging", "project=osmu&stage=raw")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("hello s3 alias"))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-request-id", "req-s3-upload-trace"))
                .andExpect(header().string("x-amz-id-2", uploadHostId))
                .andExpect(header().string(HttpHeaders.ETAG, containsString("\"")))
                .andExpect(header().string("x-amz-tagging-count", "2"))
                .andReturn();
        String etag = uploadResult.getResponse().getHeader(HttpHeaders.ETAG);

        mockMvc.perform(head("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ETAG, etag))
                .andExpect(header().longValue(HttpHeaders.CONTENT_LENGTH, 14L))
                .andExpect(header().string("x-amz-tagging-count", "2"));

        MvcResult downloadResult = mockMvc.perform(get("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(downloadResult))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_PLAIN))
                .andExpect(header().string(HttpHeaders.ETAG, etag))
                .andExpect(header().string("X-OSMU-Tags", containsString("project=osmu")))
                .andExpect(content().string("hello s3 alias"));

        mockMvc.perform(head("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_NONE_MATCH, etag))
                .andExpect(status().isNotModified())
                .andExpect(header().string(HttpHeaders.ETAG, etag));

        mockMvc.perform(get("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_NONE_MATCH, etag))
                .andExpect(request().asyncNotStarted())
                .andExpect(status().isNotModified())
                .andExpect(header().string(HttpHeaders.ETAG, etag))
                .andExpect(header().doesNotExist(HttpHeaders.CONTENT_LENGTH));

        mockMvc.perform(head("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_MATCH, "\"different\""))
                .andExpect(status().isPreconditionFailed())
                .andExpect(header().string(HttpHeaders.ETAG, etag));

        mockMvc.perform(get("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_MATCH, "\"different\""))
                .andExpect(request().asyncNotStarted())
                .andExpect(status().isPreconditionFailed())
                .andExpect(header().string(HttpHeaders.ETAG, etag))
                .andExpect(header().doesNotExist(HttpHeaders.CONTENT_LENGTH));

        String futureHttpDate = DateTimeFormatter.RFC_1123_DATE_TIME.format(
                OffsetDateTime.now(ZoneOffset.UTC).plusDays(1)
        );
        String pastHttpDate = DateTimeFormatter.RFC_1123_DATE_TIME.format(
                OffsetDateTime.now(ZoneOffset.UTC).minusDays(1)
        );

        mockMvc.perform(head("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_MODIFIED_SINCE, futureHttpDate))
                .andExpect(status().isNotModified())
                .andExpect(header().string(HttpHeaders.ETAG, etag));

        mockMvc.perform(get("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_MODIFIED_SINCE, futureHttpDate))
                .andExpect(request().asyncNotStarted())
                .andExpect(status().isNotModified())
                .andExpect(header().string(HttpHeaders.ETAG, etag));

        mockMvc.perform(head("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_UNMODIFIED_SINCE, pastHttpDate))
                .andExpect(status().isPreconditionFailed())
                .andExpect(header().string(HttpHeaders.ETAG, etag));

        mockMvc.perform(get("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_UNMODIFIED_SINCE, pastHttpDate))
                .andExpect(request().asyncNotStarted())
                .andExpect(status().isPreconditionFailed())
                .andExpect(header().string(HttpHeaders.ETAG, etag));

        MvcResult matchingIfMatchWithStaleDateResult = mockMvc.perform(get("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_MATCH, etag)
                        .header(HttpHeaders.IF_UNMODIFIED_SINCE, pastHttpDate))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(matchingIfMatchWithStaleDateResult))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ETAG, etag))
                .andExpect(content().string("hello s3 alias"));

        mockMvc.perform(get("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_NONE_MATCH, etag)
                        .header(HttpHeaders.IF_MODIFIED_SINCE, pastHttpDate))
                .andExpect(request().asyncNotStarted())
                .andExpect(status().isNotModified())
                .andExpect(header().string(HttpHeaders.ETAG, etag));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_NONE_MATCH, "*")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("blocked overwrite"))
                .andExpect(status().isPreconditionFailed())
                .andExpect(content().string(containsString("<Code>PreconditionFailed</Code>")))
                .andExpect(content().string(containsString("<Message>At least one of the pre-conditions you specified did not hold</Message>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_MATCH, "\"different\"")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("blocked mismatch"))
                .andExpect(status().isPreconditionFailed())
                .andExpect(content().string(containsString("<Code>PreconditionFailed</Code>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/put-if-match-missing.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_MATCH, etag)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("blocked missing"))
                .andExpect(status().isPreconditionFailed())
                .andExpect(content().string(containsString("<Code>PreconditionFailed</Code>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/put-if-none-match.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_NONE_MATCH, "*")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("created with guard"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ETAG, containsString("\"")));

        MvcResult guardedOverwriteResult = mockMvc.perform(put("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.IF_MATCH, etag)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("hello s3 overwrite"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ETAG, containsString("\"")))
                .andReturn();
        String overwrittenEtag = guardedOverwriteResult.getResponse().getHeader(HttpHeaders.ETAG);

        MvcResult overwrittenDownloadResult = mockMvc.perform(get("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(overwrittenDownloadResult))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ETAG, overwrittenEtag))
                .andExpect(content().string("hello s3 overwrite"));

        mockMvc.perform(delete("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/s3/{bucketName}/docs/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isNotFound())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>NoSuchKey</Code>")))
                .andExpect(content().string(containsString("<Message>The specified key does not exist.</Message>")))
                .andExpect(content().string(containsString("<BucketName>" + bucketName + "</BucketName>")))
                .andExpect(content().string(containsString("<Key>docs/sample.txt</Key>")));
    }

    @Test
    void accessKeyCanCopyObjectFromSourceVersionId() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-copy-version-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");

        mockMvc.perform(put("/api/s3/{bucketName}/docs/source.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-tagging", "stage=archived")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("version one"))
                .andExpect(status().isOk());

        mockMvc.perform(put("/api/s3/{bucketName}/docs/source.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-tagging", "stage=current")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("version two"))
                .andExpect(status().isOk());

        String versionResponse = mockMvc.perform(get("/api/buckets/{bucketName}/objects/versions/docs/source.txt", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].sizeBytes").value(11))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String archivedVersionId = JsonPath.read(versionResponse, "$.data[0].versionId");
        String archivedMd5 = md5Hex("version one");

        mockMvc.perform(put("/api/s3/{bucketName}/docs/from-version.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(
                                "x-amz-copy-source",
                                "/" + bucketName + "/docs/source.txt?versionId=" + archivedVersionId
                        ))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(header().string(HttpHeaders.ETAG, "\"%s\"".formatted(archivedMd5)))
                .andExpect(content().string(containsString("<ETag>\"%s\"</ETag>".formatted(archivedMd5))));

        MvcResult copiedDownloadResult = mockMvc.perform(get("/api/s3/{bucketName}/docs/from-version.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(copiedDownloadResult))
                .andExpect(status().isOk())
                .andExpect(header().string("X-OSMU-Tags", containsString("stage=archived")))
                .andExpect(content().string("version one"));

        String currentSourceEtag = "\"%s\"".formatted(md5Hex("version two"));
        String pastHttpDate = DateTimeFormatter.RFC_1123_DATE_TIME.format(
                Instant.now().minusSeconds(60).atZone(ZoneOffset.UTC)
        );
        mockMvc.perform(put("/api/s3/{bucketName}/docs/copy-if-match-date.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-copy-source", "/" + bucketName + "/docs/source.txt")
                        .header("x-amz-copy-source-if-match", currentSourceEtag)
                        .header("x-amz-copy-source-if-unmodified-since", pastHttpDate))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<CopyObjectResult")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/copy-if-none-match-date.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-copy-source", "/" + bucketName + "/docs/source.txt")
                        .header("x-amz-copy-source-if-none-match", currentSourceEtag)
                        .header("x-amz-copy-source-if-modified-since", pastHttpDate))
                .andExpect(status().isPreconditionFailed())
                .andExpect(content().string(containsString("<Code>PreconditionFailed</Code>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/existing-target.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("target old"))
                .andExpect(status().isOk());
        String targetEtag = "\"%s\"".formatted(md5Hex("target old"));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/copy-if-none-match-absent.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-copy-source", "/" + bucketName + "/docs/source.txt")
                        .header(HttpHeaders.IF_NONE_MATCH, "*"))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<CopyObjectResult")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/existing-target.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-copy-source", "/" + bucketName + "/docs/source.txt")
                        .header(HttpHeaders.IF_NONE_MATCH, "*"))
                .andExpect(status().isPreconditionFailed())
                .andExpect(content().string(containsString("<Code>PreconditionFailed</Code>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/existing-target.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-copy-source", "/" + bucketName + "/docs/source.txt")
                        .header(HttpHeaders.IF_MATCH, targetEtag))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<CopyObjectResult")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/copy-if-match-missing.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-copy-source", "/" + bucketName + "/docs/source.txt")
                        .header(HttpHeaders.IF_MATCH, targetEtag))
                .andExpect(status().isPreconditionFailed())
                .andExpect(content().string(containsString("<Code>PreconditionFailed</Code>")));
    }

    @Test
    void copyObjectCopiesAndReplacesUserMetadata() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-copy-user-metadata-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");
        String sourceBody = "metadata source";
        String sourceSha1 = checksumBase64("SHA-1", sourceBody);
        String copiedSha256 = checksumBase64("SHA-256", sourceBody);

        mockMvc.perform(put("/api/s3/{bucketName}/docs/source-metadata.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-meta-owner", "platform")
                        .header("x-amz-meta-color", "blue")
                        .header("x-amz-checksum-sha1", sourceSha1)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(sourceBody))
                .andExpect(status().isOk());

        mockMvc.perform(head("/api/s3/{bucketName}/docs/source-metadata.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-meta-owner", "platform"))
                .andExpect(header().string("x-amz-meta-color", "blue"))
                .andExpect(header().string("x-amz-checksum-sha1", sourceSha1));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/copied-metadata.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-copy-source", "/" + bucketName + "/docs/source-metadata.txt"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(header().string("x-amz-checksum-sha1", sourceSha1))
                .andExpect(content().string(containsString("<ChecksumSHA1>%s</ChecksumSHA1>".formatted(sourceSha1))));

        mockMvc.perform(head("/api/s3/{bucketName}/docs/copied-metadata.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-meta-owner", "platform"))
                .andExpect(header().string("x-amz-meta-color", "blue"))
                .andExpect(header().string("x-amz-checksum-sha1", sourceSha1));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/copied-sha256.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-copy-source", "/" + bucketName + "/docs/source-metadata.txt")
                        .header("x-amz-checksum-algorithm", "SHA256"))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-checksum-sha256", copiedSha256))
                .andExpect(header().doesNotExist("x-amz-checksum-sha1"))
                .andExpect(content().string(containsString("<ChecksumSHA256>%s</ChecksumSHA256>".formatted(copiedSha256))));

        mockMvc.perform(head("/api/s3/{bucketName}/docs/copied-sha256.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-checksum-sha256", copiedSha256))
                .andExpect(header().doesNotExist("x-amz-checksum-sha1"));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/copied-sha512.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-copy-source", "/" + bucketName + "/docs/source-metadata.txt")
                        .header("x-amz-checksum-algorithm", "SHA512"))
                .andExpect(status().isBadRequest())
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/replaced-metadata.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-copy-source", "/" + bucketName + "/docs/source-metadata.txt")
                        .header("x-amz-metadata-directive", "REPLACE")
                        .header("x-amz-meta-color", "green")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML));

        mockMvc.perform(head("/api/s3/{bucketName}/docs/replaced-metadata.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE))
                .andExpect(header().string("x-amz-meta-color", "green"))
                .andExpect(header().doesNotExist("x-amz-meta-owner"));
    }

    @Test
    void accessKeyCanUploadWithContentMd5AndRejectMismatch() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-content-md5-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");
        String body = "checksum body";

        mockMvc.perform(put("/api/s3/{bucketName}/docs/checksum.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("Content-MD5", contentMd5(body))
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ETAG, "\"%s\"".formatted(md5Hex(body))));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/bad-checksum.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("Content-MD5", contentMd5("different body"))
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>BadDigest</Code>")));

        mockMvc.perform(get("/api/s3/{bucketName}/docs/bad-checksum.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isNotFound())
                .andExpect(content().string(containsString("<Code>NoSuchKey</Code>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/invalid-checksum.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("Content-MD5", "not-valid-base64")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidDigest</Code>")));
    }

    @Test
    void accessKeyCanUploadWithSdkChecksumAlgorithm() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-sdk-checksum-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");
        String body = "sdk checksum body";
        String sha256 = checksumBase64("SHA-256", body);
        String crc32c = checksumCrc32cBase64(body);

        mockMvc.perform(put("/api/s3/{bucketName}/docs/sdk-checksum.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-sdk-checksum-algorithm", "SHA256")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-checksum-sha256", sha256));

        mockMvc.perform(head("/api/s3/{bucketName}/docs/sdk-checksum.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-checksum-sha256", sha256));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<ChecksumAlgorithm>SHA256</ChecksumAlgorithm>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/sdk-checksum-mismatch.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-sdk-checksum-algorithm", "SHA256")
                        .header("x-amz-checksum-crc32c", crc32c)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>BadDigest</Code>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/sdk-checksum-unsupported.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-sdk-checksum-algorithm", "SHA512")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));
    }

    @Test
    void accessKeyCanUploadWithCrc64NvmeChecksum() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-crc64nvme-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");
        String body = "123456789";
        String checksum = "rosUhgp5mIg=";

        mockMvc.perform(put("/api/s3/{bucketName}/docs/crc64nvme.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-checksum-crc64nvme", checksum)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-checksum-crc64nvme", checksum));

        mockMvc.perform(head("/api/s3/{bucketName}/docs/crc64nvme.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-checksum-crc64nvme", checksum));

        MvcResult downloadResult = mockMvc.perform(get("/api/s3/{bucketName}/docs/crc64nvme.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(downloadResult))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-checksum-crc64nvme", checksum))
                .andExpect(content().string(body));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<ChecksumAlgorithm>CRC64NVME</ChecksumAlgorithm>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/bad-crc64nvme.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-checksum-crc64nvme", checksum)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("different"))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>BadDigest</Code>")));
    }

    @Test
    void accessKeyCanUploadAwsChunkedStreamingPayload() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-aws-chunked-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");
        String decodedBody = "chunked body!";
        String chunkSignature = "0".repeat(64);
        String finalChunkSignature = "1".repeat(64);
        String encodedBody = "d;chunk-signature=" + chunkSignature + "\r\n"
                + decodedBody
                + "\r\n0;chunk-signature=" + finalChunkSignature + "\r\n\r\n";

        mockMvc.perform(put("/api/s3/{bucketName}/docs/chunked.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD")
                        .header("x-amz-decoded-content-length", decodedBody.getBytes(StandardCharsets.UTF_8).length)
                        .header(HttpHeaders.CONTENT_ENCODING, "aws-chunked")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(encodedBody.getBytes(StandardCharsets.UTF_8)))
                .andExpect(status().isOk());

        MvcResult downloadResult = mockMvc.perform(get("/api/s3/{bucketName}/docs/chunked.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(downloadResult))
                .andExpect(status().isOk())
                .andExpect(content().string(decodedBody));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/chunked-too-long.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD")
                        .header("x-amz-decoded-content-length", decodedBody.getBytes(StandardCharsets.UTF_8).length - 1)
                        .header(HttpHeaders.CONTENT_ENCODING, "aws-chunked")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(encodedBody.getBytes(StandardCharsets.UTF_8)))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));

        mockMvc.perform(put("/api/s3/{bucketName}/docs/chunked-too-short.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD")
                        .header("x-amz-decoded-content-length", decodedBody.getBytes(StandardCharsets.UTF_8).length + 1)
                        .header(HttpHeaders.CONTENT_ENCODING, "aws-chunked")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(encodedBody.getBytes(StandardCharsets.UTF_8)))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));

        String missingSignatureBody = "d\r\n"
                + decodedBody
                + "\r\n0;chunk-signature=" + finalChunkSignature + "\r\n\r\n";
        mockMvc.perform(put("/api/s3/{bucketName}/docs/chunked-missing-signature.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD")
                        .header("x-amz-decoded-content-length", decodedBody.getBytes(StandardCharsets.UTF_8).length)
                        .header(HttpHeaders.CONTENT_ENCODING, "aws-chunked")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(missingSignatureBody.getBytes(StandardCharsets.UTF_8)))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));

        String invalidFinalSignatureBody = "d;chunk-signature=" + chunkSignature + "\r\n"
                + decodedBody
                + "\r\n0;chunk-signature=nothex\r\n\r\n";
        mockMvc.perform(put("/api/s3/{bucketName}/docs/chunked-invalid-final-signature.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD")
                        .header("x-amz-decoded-content-length", decodedBody.getBytes(StandardCharsets.UTF_8).length)
                        .header(HttpHeaders.CONTENT_ENCODING, "aws-chunked")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(invalidFinalSignatureBody.getBytes(StandardCharsets.UTF_8)))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));

        String trailerChecksum = checksumBase64("SHA-256", decodedBody);
        String trailerBody = "d;chunk-signature=" + chunkSignature + "\r\n"
                + decodedBody
                + "\r\n0;chunk-signature=" + finalChunkSignature + "\r\n"
                + "x-amz-checksum-sha256:" + trailerChecksum + "\r\n\r\n";
        mockMvc.perform(put("/api/s3/{bucketName}/docs/chunked-trailer-checksum.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD")
                        .header("x-amz-decoded-content-length", decodedBody.getBytes(StandardCharsets.UTF_8).length)
                        .header("x-amz-trailer", "x-amz-checksum-sha256")
                        .header(HttpHeaders.CONTENT_ENCODING, "aws-chunked")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(trailerBody.getBytes(StandardCharsets.UTF_8)))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-checksum-sha256", trailerChecksum));

        mockMvc.perform(head("/api/s3/{bucketName}/docs/chunked-trailer-checksum.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-checksum-sha256", trailerChecksum));

        String badTrailerBody = "d;chunk-signature=" + chunkSignature + "\r\n"
                + decodedBody
                + "\r\n0;chunk-signature=" + finalChunkSignature + "\r\n"
                + "x-amz-checksum-sha256:" + checksumBase64("SHA-256", "different") + "\r\n\r\n";
        mockMvc.perform(put("/api/s3/{bucketName}/docs/chunked-bad-trailer-checksum.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD")
                        .header("x-amz-decoded-content-length", decodedBody.getBytes(StandardCharsets.UTF_8).length)
                        .header("x-amz-trailer", "x-amz-checksum-sha256")
                        .header(HttpHeaders.CONTENT_ENCODING, "aws-chunked")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(badTrailerBody.getBytes(StandardCharsets.UTF_8)))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>BadDigest</Code>")));

        String crc64Body = "9;chunk-signature=" + chunkSignature + "\r\n"
                + "123456789"
                + "\r\n0;chunk-signature=" + finalChunkSignature + "\r\n"
                + "x-amz-checksum-crc64nvme:rosUhgp5mIg=\r\n\r\n";
        mockMvc.perform(put("/api/s3/{bucketName}/docs/chunked-trailer-crc64nvme.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("x-amz-content-sha256", "STREAMING-AWS4-HMAC-SHA256-PAYLOAD")
                        .header("x-amz-decoded-content-length", "123456789".getBytes(StandardCharsets.UTF_8).length)
                        .header("x-amz-trailer", "x-amz-checksum-crc64nvme")
                        .header(HttpHeaders.CONTENT_ENCODING, "aws-chunked")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(crc64Body.getBytes(StandardCharsets.UTF_8)))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-checksum-crc64nvme", "rosUhgp5mIg="));
    }

    @Test
    void awsSigV4HeaderAuthVerifiesAwsChunkedStreamingSignatureChain() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-sigv4-chunked-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");
        String decodedBody = "sigv4 chunked body";
        String objectPath = "/api/s3/" + bucketName + "/docs/sigv4-chunked.txt";
        String streamPayloadHash = "STREAMING-AWS4-HMAC-SHA256-PAYLOAD";
        String amzDate = sigV4AmzDateNow();
        String date = amzDate.substring(0, 8);
        String credentialScope = date + "/us-east-1/s3/aws4_request";
        Map<String, String> signedHeaders = new TreeMap<>();
        signedHeaders.put("content-encoding", "aws-chunked");
        signedHeaders.put("host", "localhost");
        signedHeaders.put("x-amz-content-sha256", streamPayloadHash);
        signedHeaders.put("x-amz-date", amzDate);
        signedHeaders.put("x-amz-decoded-content-length", String.valueOf(decodedBody.getBytes(StandardCharsets.UTF_8).length));
        String authorization = sigV4Authorization(
                "PUT",
                objectPath,
                "",
                streamPayloadHash,
                credentials,
                amzDate,
                signedHeaders
        );
        String encodedBody = signedAwsChunkedBody(
                decodedBody,
                signingKey(credentials.secretKey(), date),
                amzDate,
                credentialScope,
                seedSignature(authorization)
        );

        mockMvc.perform(put(objectPath)
                        .header(HttpHeaders.HOST, "localhost")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .header("x-amz-date", amzDate)
                        .header("x-amz-content-sha256", streamPayloadHash)
                        .header("x-amz-decoded-content-length", decodedBody.getBytes(StandardCharsets.UTF_8).length)
                        .header(HttpHeaders.CONTENT_ENCODING, "aws-chunked")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(encodedBody.getBytes(StandardCharsets.UTF_8)))
                .andExpect(status().isOk());

        MvcResult downloadResult = mockMvc.perform(get("/api/s3/{bucketName}/docs/sigv4-chunked.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(downloadResult))
                .andExpect(status().isOk())
                .andExpect(content().string(decodedBody));

        String tamperedBody = encodedBody.replace(decodedBody, "sigv4 chunked bodY");
        mockMvc.perform(put(objectPath)
                        .header(HttpHeaders.HOST, "localhost")
                        .header(HttpHeaders.AUTHORIZATION, authorization)
                        .header("x-amz-date", amzDate)
                        .header("x-amz-content-sha256", streamPayloadHash)
                        .header("x-amz-decoded-content-length", decodedBody.getBytes(StandardCharsets.UTF_8).length)
                        .header(HttpHeaders.CONTENT_ENCODING, "aws-chunked")
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(tamperedBody.getBytes(StandardCharsets.UTF_8)))
                .andExpect(status().isForbidden())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>AccessDenied</Code>")))
                .andExpect(content().string(containsString("<Message>Access Denied</Message>")));
    }

    @Test
    void accessKeyCanUseMultiDeleteWithGenericContentTypeAndTrailingSlash() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-multi-delete-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE", "DELETE");
        putS3Object(bucketName, "docs/delete-me.txt", "delete me", credentials);

        mockMvc.perform(post("/api/s3/{bucketName}/", bucketName)
                        .queryParam("delete", "")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .contentType(MediaType.APPLICATION_OCTET_STREAM)
                        .content("""
                                <Delete>
                                  <Object><Key>docs/delete-me.txt</Key></Object>
                                </Delete>
                                """))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Deleted><Key>docs/delete-me.txt</Key></Deleted>")));

        mockMvc.perform(get("/api/s3/{bucketName}/docs/delete-me.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isNotFound())
                .andExpect(content().string(containsString("<Code>NoSuchKey</Code>")));
    }

    @Test
    void accessKeyCanListObjectsThroughS3ListObjectsV2Xml() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-list-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");

        putS3Object(bucketName, "docs/a.txt", "a", credentials);
        putS3Object(bucketName, "docs/nested/b.txt", "b", credentials);
        putS3Object(bucketName, "images/c.txt", "c", credentials);

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .queryParam("prefix", "docs/")
                        .queryParam("delimiter", "/")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<ListBucketResult xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">")))
                .andExpect(content().string(containsString("<Name>%s</Name>".formatted(bucketName))))
                .andExpect(content().string(containsString("<Prefix>docs/</Prefix>")))
                .andExpect(content().string(containsString("<Key>docs/a.txt</Key>")))
                .andExpect(content().string(containsString("<ETag>\"")))
                .andExpect(content().string(containsString("<CommonPrefixes><Prefix>docs/nested/</Prefix></CommonPrefixes>")))
                .andExpect(content().string(not(containsString("<Key>images/c.txt</Key>"))))
                .andExpect(content().string(not(containsString("<Key>docs/nested/b.txt</Key>"))));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .queryParam("max-keys", "1")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<IsTruncated>true</IsTruncated>")))
                .andExpect(content().string(containsString("<NextContinuationToken>docs/a.txt</NextContinuationToken>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .queryParam("max-keys", "1")
                        .queryParam("continuation-token", "docs/a.txt")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<ContinuationToken>docs/a.txt</ContinuationToken>")))
                .andExpect(content().string(containsString("<Key>docs/nested/b.txt</Key>")));
    }

    @Test
    void accessKeyCanListObjectsThroughS3ListObjectsV1Xml() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-list-v1-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");

        putS3Object(bucketName, "docs/a.txt", "a", credentials);
        putS3Object(bucketName, "docs/nested/b.txt", "b", credentials);
        putS3Object(bucketName, "images/c.txt", "c", credentials);

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("prefix", "docs/")
                        .queryParam("delimiter", "/")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<ListBucketResult xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">")))
                .andExpect(content().string(containsString("<Name>%s</Name>".formatted(bucketName))))
                .andExpect(content().string(containsString("<Prefix>docs/</Prefix>")))
                .andExpect(content().string(containsString("<Marker></Marker>")))
                .andExpect(content().string(containsString("<Key>docs/a.txt</Key>")))
                .andExpect(content().string(containsString("<ETag>\"")))
                .andExpect(content().string(containsString("<CommonPrefixes><Prefix>docs/nested/</Prefix></CommonPrefixes>")))
                .andExpect(content().string(not(containsString("<Key>images/c.txt</Key>"))))
                .andExpect(content().string(not(containsString("<Key>docs/nested/b.txt</Key>"))));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("max-keys", "1")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<IsTruncated>true</IsTruncated>")))
                .andExpect(content().string(containsString("<NextMarker>docs/a.txt</NextMarker>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("max-keys", "1")
                        .queryParam("marker", "docs/a.txt")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<Marker>docs/a.txt</Marker>")))
                .andExpect(content().string(containsString("<Key>docs/nested/b.txt</Key>")));
    }

    @Test
    void accessKeyCanListObjectsWithUrlEncoding() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-list-encoding-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");

        putS3Object(bucketName, "docs/special file(1).txt", "body", credentials);

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("prefix", "docs/")
                        .queryParam("encoding-type", "url")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<EncodingType>url</EncodingType>")))
                .andExpect(content().string(containsString("<Prefix>docs%2F</Prefix>")))
                .andExpect(content().string(containsString("<Key>docs%2Fspecial%20file%281%29.txt</Key>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .queryParam("prefix", "docs/")
                        .queryParam("encoding-type", "url")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<EncodingType>url</EncodingType>")))
                .andExpect(content().string(containsString("<Prefix>docs%2F</Prefix>")))
                .andExpect(content().string(containsString("<Key>docs%2Fspecial%20file%281%29.txt</Key>")));
    }

    @Test
    void accessKeyCanListObjectsWithOwnerWhenRequested() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-list-owner-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");

        putS3Object(bucketName, "docs/owner.txt", "body", credentials);

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .queryParam("fetch-owner", "true")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<Owner><ID>1</ID><DisplayName>admin</DisplayName></Owner>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("fetch-owner", "true")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<Owner><ID>1</ID><DisplayName>admin</DisplayName></Owner>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(not(containsString("<Owner>"))));
    }

    @Test
    void accessKeyCanUseAwsMaxKeysLimit() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-list-max-keys-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");

        putS3Object(bucketName, "docs/max-keys.txt", "body", credentials);

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("max-keys", "1000")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<MaxKeys>1000</MaxKeys>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .queryParam("max-keys", "1000")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<MaxKeys>1000</MaxKeys>")));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .queryParam("max-keys", "1001")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isBadRequest())
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));
    }

    @Test
    void accessKeyCanCheckBucketAndLocationThroughS3StylePath() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-bucket-location-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "WRITE");

        mockMvc.perform(head("/api/s3/{bucketName}", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-bucket-region", "us-east-1"));

        mockMvc.perform(get("/api/s3/{bucketName}", bucketName)
                        .queryParam("location", "")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-bucket-region", "us-east-1"))
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<LocationConstraint xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">us-east-1</LocationConstraint>")));
    }

    @Test
    void bearerCanCreateAndAccessKeyCanDeleteBucketThroughS3StylePath() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-bucket-create-delete-bucket";

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.LOCATION, "/" + bucketName))
                .andExpect(header().string("x-amz-bucket-region", "us-east-1"));

        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "ADMIN");

        mockMvc.perform(head("/api/s3/{bucketName}", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-bucket-region", "us-east-1"));

        mockMvc.perform(delete("/api/s3/{bucketName}", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isNoContent())
                .andExpect(header().string("x-amz-bucket-region", "us-east-1"));

        mockMvc.perform(head("/api/s3/{bucketName}", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void bearerCanCreateBucketWithS3LocationConstraintXml() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-bucket-location-create-bucket";
        String invalidBucketName = "s3-bucket-location-invalid-bucket";

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <CreateBucketConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                                  <LocationConstraint>us-east-1</LocationConstraint>
                                </CreateBucketConfiguration>
                                """))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.LOCATION, "/" + bucketName))
                .andExpect(header().string("x-amz-bucket-region", "us-east-1"));

        mockMvc.perform(head("/api/s3/{bucketName}", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-bucket-region", "us-east-1"));

        mockMvc.perform(put("/api/s3/{bucketName}", invalidBucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <CreateBucketConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                                  <LocationConstraint>eu-west-1</LocationConstraint>
                                </CreateBucketConfiguration>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));

        mockMvc.perform(head("/api/s3/{bucketName}", invalidBucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void createBucketRejectsInvalidCreateBucketConfigurationXml() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String invalidRootBucketName = "s3-bucket-invalid-root-create";
        String duplicateLocationBucketName = "s3-bucket-duplicate-location";

        mockMvc.perform(put("/api/s3/{bucketName}", invalidRootBucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <Bucket xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                                  <LocationConstraint>us-east-1</LocationConstraint>
                                </Bucket>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));

        mockMvc.perform(head("/api/s3/{bucketName}", invalidRootBucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());

        mockMvc.perform(put("/api/s3/{bucketName}", duplicateLocationBucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_XML)
                        .content("""
                                <CreateBucketConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
                                  <LocationConstraint>us-east-1</LocationConstraint>
                                  <LocationConstraint>us-east-1</LocationConstraint>
                                </CreateBucketConfiguration>
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));

        mockMvc.perform(head("/api/s3/{bucketName}", duplicateLocationBucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void createBucketRejectsUnsupportedAclObjectLockAndOwnershipControls() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");

        expectUnsupportedCreateBucketHeader(token, "s3-bucket-public-acl", "x-amz-acl", "public-read");
        expectUnsupportedCreateBucketHeader(token, "s3-bucket-grant-acl", "x-amz-grant-read", "id=\"abc\"");
        expectUnsupportedCreateBucketHeader(token, "s3-bucket-object-lock", "x-amz-bucket-object-lock-enabled", "true");
        expectUnsupportedCreateBucketHeader(token, "s3-bucket-object-owner", "x-amz-object-ownership", "ObjectWriter");
        expectUnsupportedCreateBucketHeader(token, "s3-bucket-account-ns", "x-amz-bucket-namespace", "account-regional");

        String safeNoopBucketName = "s3-bucket-safe-noop-controls";
        mockMvc.perform(put("/api/s3/{bucketName}", safeNoopBucketName)
                        .header("Authorization", "Bearer " + token)
                        .header("x-amz-acl", "private")
                        .header("x-amz-bucket-object-lock-enabled", "false")
                        .header("x-amz-object-ownership", "BucketOwnerEnforced")
                        .header("x-amz-bucket-namespace", "global"))
                .andExpect(status().isOk())
                .andExpect(header().string("x-amz-bucket-region", "us-east-1"));
    }

    private void expectUnsupportedCreateBucketHeader(
            String token,
            String bucketName,
            String headerName,
            String headerValue
    ) throws Exception {
        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .header(headerName, headerValue))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidRequest</Code>")));

        mockMvc.perform(head("/api/s3/{bucketName}", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void createBucketReturnsS3DuplicateBucketCodes() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        String ownerLoginId = "s3-create-duplicate-owner";
        String bucketName = "s3-bucket-duplicate-create-bucket";
        createUser(adminToken, ownerLoginId, ownerLoginId + "@example.com");
        String ownerToken = loginAndReturnAccessToken(ownerLoginId, "user-password");

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isOk());

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isConflict())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>BucketAlreadyOwnedByYou</Code>")))
                .andExpect(content().string(containsString("<Message>Your previous request to create the named bucket succeeded and you already own it.</Message>")));

        mockMvc.perform(put("/api/s3/{bucketName}", bucketName)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isConflict())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>BucketAlreadyExists</Code>")))
                .andExpect(content().string(containsString("<Message>The requested bucket name is not available. "
                        + "The bucket namespace is shared by all users of the system. "
                        + "Please select a different name and try again.</Message>")));
    }

    @Test
    void bucketLevelRequestsRejectInvalidS3BucketNames() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        List<String> invalidBucketNames = List.of(
                "BadBucket",
                "ab",
                "bucket..name",
                "bucket-.name",
                "192.168.5.4",
                "xn--bucket",
                "sthree-bucket",
                "amzn-s3-demo-bucket",
                "bucket-s3alias",
                "bucket--ol-s3",
                "bucket.mrap",
                "bucket--x-s3",
                "bucket--table-s3",
                "bucket-an"
        );

        for (String invalidBucketName : invalidBucketNames) {
            mockMvc.perform(put("/api/s3/{bucketName}", invalidBucketName)
                            .header("Authorization", "Bearer " + token))
                    .andExpect(status().isBadRequest())
                    .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                    .andExpect(content().string(containsString("<Code>InvalidBucketName</Code>")))
                    .andExpect(content().string(containsString("<Message>The specified bucket is not valid.</Message>")));
        }

        mockMvc.perform(delete("/api/s3/{bucketName}", "bucket--x-s3")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>InvalidBucketName</Code>")))
                .andExpect(content().string(containsString("<Message>The specified bucket is not valid.</Message>")));
    }

    @Test
    void deleteBucketReturnsBucketNotEmptyForNonEmptyBucket() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-bucket-not-empty-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "ADMIN", "WRITE");
        putS3Object(bucketName, "docs/object.txt", "not empty", credentials);

        mockMvc.perform(delete("/api/s3/{bucketName}", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isConflict())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>BucketNotEmpty</Code>")))
                .andExpect(content().string(containsString("<Message>The bucket you tried to delete is not empty.</Message>")));
    }

    @Test
    void deleteBucketReturnsBucketNotEmptyWhenRetainedVersionsExist() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-bucket-retained-version-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "ADMIN");
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        objectVersionRepository.save(bucketName, new ObjectVersionRecord(
                "retained-version-id",
                "docs/retained.txt",
                ".osmu/versions/retained-version-id",
                12L,
                MediaType.TEXT_PLAIN_VALUE,
                now,
                now,
                Map.of(),
                Map.of()
        ));

        mockMvc.perform(delete("/api/s3/{bucketName}", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isConflict())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>BucketNotEmpty</Code>")))
                .andExpect(content().string(containsString("<Message>The bucket you tried to delete is not empty.</Message>")));

        mockMvc.perform(head("/api/s3/{bucketName}", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());

        objectVersionRepository.deleteByBucketName(bucketName);
        mockMvc.perform(delete("/api/s3/{bucketName}", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(status().isNoContent());
    }

    @Test
    void accessKeyCanListScopedBucketsThroughS3Root() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-root-list-bucket-a";
        String otherBucketName = "s3-root-list-bucket-b";
        createBucket(token, bucketName);
        createBucket(token, otherBucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ");

        mockMvc.perform(get("/api/s3")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<ListAllMyBucketsResult xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">")))
                .andExpect(content().string(containsString("<Name>%s</Name>".formatted(bucketName))))
                .andExpect(content().string(not(containsString("<Name>%s</Name>".formatted(otherBucketName)))));
    }

    @Test
    void accessKeyCanUseS3ClientRootEndpointPathStyle() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-client-root-path-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE", "DELETE");

        mockMvc.perform(get("/")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Name>%s</Name>".formatted(bucketName))));

        mockMvc.perform(put("/{bucketName}/docs/root-endpoint.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("root endpoint"))
                .andExpect(status().isOk());

        MvcResult downloadResult = mockMvc.perform(get("/{bucketName}/docs/root-endpoint.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(downloadResult))
                .andExpect(status().isOk())
                .andExpect(content().string("root endpoint"));

        mockMvc.perform(get("/{bucketName}", bucketName)
                        .queryParam("list-type", "2")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("<Key>docs/root-endpoint.txt</Key>")));
    }

    @Test
    void accessKeyCanUseS3ClientRootEndpointVirtualHostedStyle() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-client-root-vhost-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");

        mockMvc.perform(put("/docs/virtual-hosted.txt")
                        .header(HttpHeaders.HOST, bucketName + ".localhost")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("virtual hosted root"))
                .andExpect(status().isOk());

        MvcResult downloadResult = mockMvc.perform(get("/docs/virtual-hosted.txt")
                        .header(HttpHeaders.HOST, bucketName + ".localhost")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey()))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(downloadResult))
                .andExpect(status().isOk())
                .andExpect(content().string("virtual hosted root"));
    }

    @Test
    void accessKeyCanUseRangeGetThroughS3StylePath() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-range-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "READ", "WRITE");
        putS3Object(bucketName, "video/sample.txt", "hello s3 alias", credentials);

        MvcResult middleRangeResult = mockMvc.perform(get("/api/s3/{bucketName}/video/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.RANGE, "bytes=6-7"))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(middleRangeResult))
                .andExpect(status().isPartialContent())
                .andExpect(header().string(HttpHeaders.ACCEPT_RANGES, "bytes"))
                .andExpect(header().string(HttpHeaders.CONTENT_RANGE, "bytes 6-7/14"))
                .andExpect(header().longValue(HttpHeaders.CONTENT_LENGTH, 2L))
                .andExpect(content().string("s3"));

        MvcResult suffixRangeResult = mockMvc.perform(get("/api/s3/{bucketName}/video/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.RANGE, "bytes=-5"))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(suffixRangeResult))
                .andExpect(status().isPartialContent())
                .andExpect(header().string(HttpHeaders.CONTENT_RANGE, "bytes 9-13/14"))
                .andExpect(content().string("alias"));

        mockMvc.perform(get("/api/s3/{bucketName}/video/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.RANGE, "bytes=0-4,9-13"))
                .andExpect(status().isRequestedRangeNotSatisfiable())
                .andExpect(content().string(containsString("<Code>InvalidRange</Code>")))
                .andExpect(content().string(containsString("<Message>The requested range cannot be satisfied.</Message>")));

        String currentEtag = "\"%s\"".formatted(md5Hex("hello s3 alias"));
        MvcResult matchingIfRangeResult = mockMvc.perform(get("/api/s3/{bucketName}/video/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.RANGE, "bytes=0-4")
                        .header("If-Range", currentEtag))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(matchingIfRangeResult))
                .andExpect(status().isPartialContent())
                .andExpect(header().string(HttpHeaders.CONTENT_RANGE, "bytes 0-4/14"))
                .andExpect(content().string("hello"));

        MvcResult staleIfRangeResult = mockMvc.perform(get("/api/s3/{bucketName}/video/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.RANGE, "bytes=0-4")
                        .header("If-Range", "\"stale-etag\""))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(staleIfRangeResult))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist(HttpHeaders.CONTENT_RANGE))
                .andExpect(content().string("hello s3 alias"));

        mockMvc.perform(get("/api/s3/{bucketName}/video/sample.txt", bucketName)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header(HttpHeaders.RANGE, "bytes=99-100"))
                .andExpect(status().isRequestedRangeNotSatisfiable())
                .andExpect(content().string(containsString("<Code>InvalidRange</Code>")))
                .andExpect(content().string(containsString("<Message>The requested range cannot be satisfied.</Message>")));
    }

    @Test
    void missingS3MultipartUploadReturnsNoSuchUploadXml() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-multipart-missing-upload-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials credentials = createAccessKey(token, bucketName, "WRITE");
        String missingUploadResource = "/api/s3/" + bucketName + "/video/missing.mp4?uploadId=missing-upload";
        String hostId = checksumBase64("SHA-256", "req-nosuchupload:" + missingUploadResource);

        mockMvc.perform(get("/api/s3/{bucketName}/video/missing.mp4", bucketName)
                        .queryParam("uploadId", "missing-upload")
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .header("X-Request-Id", "req-nosuchupload")
                        .accept(MediaType.APPLICATION_XML))
                .andExpect(status().isNotFound())
                .andExpect(header().string("x-amz-request-id", "req-nosuchupload"))
                .andExpect(header().string("x-amz-id-2", hostId))
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(containsString("<Code>NoSuchUpload</Code>")))
                .andExpect(content().string(containsString("<Message>The specified multipart upload does not exist. The upload ID might be invalid, or the multipart upload might have been aborted or completed.</Message>")))
                .andExpect(content().string(containsString("<BucketName>" + bucketName + "</BucketName>")))
                .andExpect(content().string(containsString("<Key>video/missing.mp4</Key>")))
                .andExpect(content().string(containsString("<UploadId>missing-upload</UploadId>")))
                .andExpect(content().string(containsString("<Resource>" + missingUploadResource + "</Resource>")))
                .andExpect(content().string(containsString("<RequestId>req-nosuchupload</RequestId>")))
                .andExpect(content().string(containsString("<HostId>" + hostId + "</HostId>")))
                .andExpect(content().string(not(containsString("<HostId>req-nosuchupload</HostId>"))));
    }

    @Test
    void accessKeyScopeControlsS3StyleObjectActions() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-scope-bucket";
        createBucket(token, bucketName);
        AccessKeyCredentials readOnly = createAccessKey(token, bucketName, "READ");

        mockMvc.perform(put("/api/s3/{bucketName}/blocked.txt", bucketName)
                        .header("X-OSMU-Access-Key", readOnly.accessKey())
                        .header("X-OSMU-Secret-Key", readOnly.secretKey())
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("blocked"))
                .andExpect(status().isForbidden())
                .andExpect(content().string(containsString("<Code>AccessDenied</Code>")))
                .andExpect(content().string(containsString("<Message>Access Denied</Message>")));

        AccessKeyCredentials writer = createAccessKey(token, bucketName, "WRITE");
        mockMvc.perform(put("/api/s3/{bucketName}/write-only.txt", bucketName)
                        .header("X-OSMU-Access-Key", writer.accessKey())
                        .header("X-OSMU-Secret-Key", writer.secretKey())
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("write-only"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/s3/{bucketName}/write-only.txt", bucketName)
                        .header("X-OSMU-Access-Key", writer.accessKey())
                        .header("X-OSMU-Secret-Key", writer.secretKey()))
                .andExpect(status().isForbidden())
                .andExpect(content().string(containsString("<Code>AccessDenied</Code>")))
                .andExpect(content().string(containsString("<Message>Access Denied</Message>")));
    }

    @Test
    void bearerTokenCanUseS3StyleObjectPath() throws Exception {
        String token = loginAndReturnAccessToken("admin", "password");
        String bucketName = "s3-object-jwt-bucket";
        createBucket(token, bucketName);

        mockMvc.perform(put("/api/s3/{bucketName}/jwt-object.txt", bucketName)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("jwt path"))
                .andExpect(status().isOk());

        MvcResult downloadResult = mockMvc.perform(get("/api/s3/{bucketName}/jwt-object.txt", bucketName)
                        .header("Authorization", "Bearer " + token))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(downloadResult))
                .andExpect(status().isOk())
                .andExpect(content().string("jwt path"));
    }

    private void putS3Object(String bucketName, String objectKey, String body, AccessKeyCredentials credentials) throws Exception {
        mockMvc.perform(put("/api/s3/{bucketName}/{objectKey}", bucketName, objectKey)
                        .header("X-OSMU-Access-Key", credentials.accessKey())
                        .header("X-OSMU-Secret-Key", credentials.secretKey())
                        .contentType(MediaType.TEXT_PLAIN)
                        .content(body))
                .andExpect(status().isOk());
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

    private void createUser(String adminToken, String loginId, String email) throws Exception {
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s",
                                  "name": "%s",
                                  "role": "USER",
                                  "password": "user-password"
                                }
                                """.formatted(loginId, email, loginId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.loginId").value(loginId));
    }

    private AccessKeyCredentials createAccessKey(String token, String bucketName, String... permissions) throws Exception {
        String permissionList = java.util.Arrays.stream(permissions)
                .map(permission -> "\"" + permission + "\"")
                .collect(java.util.stream.Collectors.joining(", "));
        String response = mockMvc.perform(post("/api/access-keys")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "s3-object-key",
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

    private String sigV4Authorization(
            String method,
            String path,
            String query,
            String payloadHash,
            AccessKeyCredentials credentials,
            String amzDate,
            Map<String, String> headers
    ) throws Exception {
        String date = amzDate.substring(0, 8);
        String signedHeaders = String.join(";", new TreeMap<>(headers).keySet());
        String canonicalHeaders = canonicalHeaders(headers);
        String canonicalRequest = method + "\n"
                + path + "\n"
                + query + "\n"
                + canonicalHeaders + "\n"
                + signedHeaders + "\n"
                + payloadHash;
        String scope = date + "/us-east-1/s3/aws4_request";
        String stringToSign = "AWS4-HMAC-SHA256\n"
                + amzDate + "\n"
                + scope + "\n"
                + sha256Hex(canonicalRequest);
        String signature = HexFormat.of().formatHex(hmac(signingKey(credentials.secretKey(), date), stringToSign));
        return "AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s"
                .formatted(credentials.accessKey(), scope, signedHeaders, signature);
    }

    private String signedAwsChunkedBody(
            String decodedBody,
            byte[] signingKey,
            String amzDate,
            String credentialScope,
            String seedSignature
    ) throws Exception {
        byte[] chunk = decodedBody.getBytes(StandardCharsets.UTF_8);
        String chunkSignature = awsChunkSignature(signingKey, amzDate, credentialScope, seedSignature, chunk);
        String finalChunkSignature = awsChunkSignature(signingKey, amzDate, credentialScope, chunkSignature, new byte[0]);
        return Integer.toHexString(chunk.length) + ";chunk-signature=" + chunkSignature + "\r\n"
                + decodedBody
                + "\r\n0;chunk-signature=" + finalChunkSignature + "\r\n\r\n";
    }

    private String awsChunkSignature(
            byte[] signingKey,
            String amzDate,
            String credentialScope,
            String previousSignature,
            byte[] chunk
    ) throws Exception {
        String stringToSign = "AWS4-HMAC-SHA256-PAYLOAD\n"
                + amzDate + "\n"
                + credentialScope + "\n"
                + previousSignature + "\n"
                + sha256Hex(new byte[0]) + "\n"
                + sha256Hex(chunk);
        return HexFormat.of().formatHex(hmac(signingKey, stringToSign));
    }

    private String seedSignature(String authorization) {
        String prefix = "Signature=";
        int index = authorization.indexOf(prefix);
        return authorization.substring(index + prefix.length());
    }

    private String sigV4PresignedQuery(
            String method,
            String path,
            AccessKeyCredentials credentials,
            String amzDate,
            Map<String, String> headers
    ) throws Exception {
        return sigV4PresignedQuery(method, path, credentials, amzDate, 604800, headers);
    }

    private String sigV4PresignedQuery(
            String method,
            String path,
            AccessKeyCredentials credentials,
            String amzDate,
            int expiresInSeconds,
            Map<String, String> headers
    ) throws Exception {
        String date = amzDate.substring(0, 8);
        String signedHeaders = String.join(";", new TreeMap<>(headers).keySet());
        String scope = date + "/us-east-1/s3/aws4_request";
        TreeMap<String, String> query = new TreeMap<>();
        query.put("X-Amz-Algorithm", "AWS4-HMAC-SHA256");
        query.put("X-Amz-Credential", credentials.accessKey() + "/" + scope);
        query.put("X-Amz-Date", amzDate);
        query.put("X-Amz-Expires", String.valueOf(expiresInSeconds));
        query.put("X-Amz-SignedHeaders", signedHeaders);
        String canonicalQuery = canonicalQuery(query);
        String canonicalRequest = method + "\n"
                + path + "\n"
                + canonicalQuery + "\n"
                + canonicalHeaders(headers) + "\n"
                + signedHeaders + "\n"
                + "UNSIGNED-PAYLOAD";
        String stringToSign = "AWS4-HMAC-SHA256\n"
                + amzDate + "\n"
                + scope + "\n"
                + sha256Hex(canonicalRequest);
        String signature = HexFormat.of().formatHex(hmac(signingKey(credentials.secretKey(), date), stringToSign));
        return canonicalQuery + "&X-Amz-Signature=" + signature;
    }

    private String sigV4AmzDateNow() {
        return sigV4AmzDate(Instant.now());
    }

    private String sigV4AmzDate(Instant instant) {
        return DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'")
                .withZone(ZoneOffset.UTC)
                .format(instant);
    }

    private String canonicalQuery(Map<String, String> query) {
        return query.entrySet().stream()
                .map(entry -> uriEncode(entry.getKey()) + "=" + uriEncode(entry.getValue()))
                .collect(java.util.stream.Collectors.joining("&"));
    }

    private String uriEncode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8)
                .replace("+", "%20")
                .replace("%2F", "%2F")
                .replace("*", "%2A")
                .replace("%7E", "~");
    }

    private String canonicalHeaders(Map<String, String> headers) {
        StringBuilder canonical = new StringBuilder();
        new TreeMap<>(headers).forEach((name, value) -> canonical
                .append(name.toLowerCase(Locale.ROOT))
                .append(':')
                .append(value.trim().replaceAll("\\s+", " "))
                .append('\n'));
        return canonical.toString();
    }

    private byte[] signingKey(String secretKey, String date) throws Exception {
        byte[] dateKey = hmac(("AWS4" + secretKey).getBytes(StandardCharsets.UTF_8), date);
        byte[] regionKey = hmac(dateKey, "us-east-1");
        byte[] serviceKey = hmac(regionKey, "s3");
        return hmac(serviceKey, "aws4_request");
    }

    private byte[] hmac(byte[] key, String value) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(key, "HmacSHA256"));
        return mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
    }

    private String sha256Hex(String value) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
    }

    private String sha256Hex(byte[] value) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value));
    }

    private String checksumBase64(String algorithm, String value) throws Exception {
        return Base64.getEncoder().encodeToString(MessageDigest.getInstance(algorithm).digest(value.getBytes(StandardCharsets.UTF_8)));
    }

    private String checksumCrc32cBase64(String value) {
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        CRC32C checksum = new CRC32C();
        checksum.update(bytes, 0, bytes.length);
        return Base64.getEncoder().encodeToString(intDigest(checksum.getValue()));
    }

    private byte[] intDigest(long value) {
        long normalized = value & 0xffffffffL;
        return new byte[]{
                (byte) (normalized >>> 24),
                (byte) (normalized >>> 16),
                (byte) (normalized >>> 8),
                (byte) normalized
        };
    }

    private String contentMd5(String value) throws Exception {
        return Base64.getEncoder().encodeToString(md5(value));
    }

    private String md5Hex(String value) throws Exception {
        return HexFormat.of().formatHex(md5(value));
    }

    private byte[] md5(String value) throws Exception {
        return MessageDigest.getInstance("MD5").digest(value.getBytes(StandardCharsets.UTF_8));
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
