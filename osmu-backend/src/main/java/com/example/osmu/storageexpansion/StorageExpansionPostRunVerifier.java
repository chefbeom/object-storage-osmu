package com.example.osmu.storageexpansion;

import com.example.osmu.object.StoredObjectData;
import com.example.osmu.object.StoredObjectRecord;
import com.example.osmu.storage.ObjectStorageAdapter;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class StorageExpansionPostRunVerifier {

    private final ObjectStorageAdapter storageAdapter;
    private final boolean enabled;
    private final String bucketPrefix;

    public StorageExpansionPostRunVerifier(
            ObjectStorageAdapter storageAdapter,
            @Value("${osmu.storage-expansion.post-run-verifier.enabled:true}") boolean enabled,
            @Value("${osmu.storage-expansion.post-run-verifier.bucket-prefix:osmu-expansion-smoke}") String bucketPrefix
    ) {
        this.storageAdapter = storageAdapter;
        this.enabled = enabled;
        this.bucketPrefix = bucketPrefix;
    }

    public StorageExpansionPostRunVerification verify(String phase, long requestId, boolean databaseHealthy) {
        if (!enabled) {
            return new StorageExpansionPostRunVerification(true, "Post-run verifier disabled.", "postRun=DISABLED");
        }
        String bucketName = bucketName(phase, requestId);
        String objectKey = "post-run/%s-%d.txt".formatted(phase.toLowerCase(), requestId);
        byte[] content = "osmu storage expansion %s smoke %d".formatted(phase, requestId).getBytes(StandardCharsets.UTF_8);
        boolean storageHealthy = false;
        boolean putOk = false;
        boolean getOk = false;
        boolean listOk = false;
        try {
            storageHealthy = storageAdapter.isHealthy();
            if (!databaseHealthy) {
                return result(false, phase, databaseHealthy, storageHealthy, putOk, getOk, listOk, "database health DOWN");
            }
            if (!storageHealthy) {
                return result(false, phase, databaseHealthy, storageHealthy, putOk, getOk, listOk, "object storage health DOWN");
            }
            storageAdapter.createBucket(bucketName);
            StoredObjectRecord written = storageAdapter.putObject(bucketName, objectKey, content, "text/plain");
            putOk = objectKey.equals(written.key()) && written.sizeBytes() == content.length;
            StoredObjectData loaded = storageAdapter.getObject(bucketName, objectKey);
            getOk = loaded.content() != null
                    && new String(loaded.content(), StandardCharsets.UTF_8).equals(new String(content, StandardCharsets.UTF_8));
            List<StoredObjectRecord> listed = storageAdapter.listObjects(bucketName, "post-run/");
            listOk = listed.stream().anyMatch(object -> objectKey.equals(object.key()));
            return result(putOk && getOk && listOk, phase, databaseHealthy, storageHealthy, putOk, getOk, listOk, null);
        } catch (Exception exception) {
            return result(false, phase, databaseHealthy, storageHealthy, putOk, getOk, listOk, exception.getMessage());
        } finally {
            cleanup(bucketName, objectKey);
        }
    }

    private StorageExpansionPostRunVerification result(
            boolean success,
            String phase,
            boolean databaseHealthy,
            boolean storageHealthy,
            boolean putOk,
            boolean getOk,
            boolean listOk,
            String error
    ) {
        String summary = """
                Post-run verification:
                phase: %s
                databaseHealth: %s
                storageHealth: %s
                s3Put: %s
                s3Get: %s
                s3List: %s
                result: %s
                error: %s
                """.formatted(
                phase,
                databaseHealthy ? "UP" : "DOWN",
                storageHealthy ? "UP" : "DOWN",
                putOk ? "PASS" : "FAIL",
                getOk ? "PASS" : "FAIL",
                listOk ? "PASS" : "FAIL",
                success ? "SUCCESS" : "FAILED",
                error == null || error.isBlank() ? "-" : error
        ).trim();
        String notes = "postRun=%s, database=%s, storage=%s, s3Put=%s, s3Get=%s, s3List=%s"
                .formatted(
                        success ? "SUCCESS" : "FAILED",
                        databaseHealthy ? "UP" : "DOWN",
                        storageHealthy ? "UP" : "DOWN",
                        putOk ? "PASS" : "FAIL",
                        getOk ? "PASS" : "FAIL",
                        listOk ? "PASS" : "FAIL"
                );
        return new StorageExpansionPostRunVerification(success, summary, notes);
    }

    private String bucketName(String phase, long requestId) {
        String normalizedPrefix = bucketPrefix == null || bucketPrefix.isBlank()
                ? "osmu-expansion-smoke"
                : bucketPrefix.trim().toLowerCase().replaceAll("[^a-z0-9-]", "-");
        String normalizedPhase = phase == null || phase.isBlank()
                ? "run"
                : phase.trim().toLowerCase().replaceAll("[^a-z0-9-]", "-");
        String phaseSegment = stripEdgeHyphens(normalizedPhase);
        if (phaseSegment.length() > 20) {
            phaseSegment = stripEdgeHyphens(phaseSegment.substring(0, 20));
        }
        String suffix = "-%s-%d".formatted(phaseSegment, requestId);
        int maxPrefixLength = Math.max(3, 63 - suffix.length());
        String prefix = stripEdgeHyphens(normalizedPrefix);
        if (prefix.length() > maxPrefixLength) {
            prefix = stripEdgeHyphens(prefix.substring(0, maxPrefixLength));
        }
        if (prefix.length() < 3) {
            prefix = "osmu";
        }
        return prefix + suffix;
    }

    private String stripEdgeHyphens(String value) {
        String stripped = value.replaceAll("^-+", "").replaceAll("-+$", "");
        return stripped.isBlank() ? "osmu" : stripped;
    }

    private void cleanup(String bucketName, String objectKey) {
        try {
            storageAdapter.deleteObject(bucketName, objectKey);
        } catch (Exception ignored) {
            // Verification cleanup should not hide the verifier result.
        }
        try {
            storageAdapter.deleteBucket(bucketName);
        } catch (Exception ignored) {
            // Verification cleanup should not hide the verifier result.
        }
    }
}
