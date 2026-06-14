package com.example.osmu.storage.minio;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.storage", name = "mode", havingValue = "minio")
public class MinioBucketCorsProvisioner {

    private static final Logger log = LoggerFactory.getLogger(MinioBucketCorsProvisioner.class);
    private static final Duration COMMAND_TIMEOUT = Duration.ofSeconds(30);

    private final String mcPath;
    private final String alias;
    private final String endpoint;
    private final String rootAccessKey;
    private final String rootSecretKey;
    private final boolean enabled;
    private final List<String> allowedOrigins;
    private final Set<String> appliedBuckets = ConcurrentHashMap.newKeySet();

    public MinioBucketCorsProvisioner(
            @Value("${osmu.storage.endpoint}") String endpoint,
            @Value("${osmu.storage.access-key}") String accessKey,
            @Value("${osmu.storage.secret-key}") String secretKey,
            @Value("${osmu.storage.cors.enabled:false}") boolean enabled,
            @Value("${osmu.storage.cors.allowed-origins:http://localhost:5173,http://127.0.0.1:5173}") String allowedOrigins,
            @Value("${osmu.storage.cors.mc-path:${osmu.access-key.minio.mc-path:mc}}") String mcPath,
            @Value("${osmu.storage.cors.minio-alias:${osmu.access-key.minio.alias:osmu-minio}}") String alias
    ) {
        this.endpoint = endpoint;
        this.rootAccessKey = accessKey;
        this.rootSecretKey = secretKey;
        this.enabled = enabled;
        this.allowedOrigins = parseAllowedOrigins(allowedOrigins);
        this.mcPath = mcPath;
        this.alias = alias;
    }

    public void apply(String bucketName) {
        if (!enabled || appliedBuckets.contains(bucketName)) {
            return;
        }
        Path corsFile = null;
        try {
            ensureAlias();
            corsFile = Files.createTempFile("osmu-minio-cors-", ".xml");
            Files.writeString(corsFile, corsXml(), StandardCharsets.UTF_8);
            runRequired("set bucket CORS", "cors", "set", alias + "/" + bucketName, corsFile.toString());
            appliedBuckets.add(bucketName);
        } catch (Exception exception) {
            log.warn("MinIO bucket CORS provisioning skipped for bucket {}: {}", bucketName, exception.getMessage());
        } finally {
            deleteCorsFile(corsFile);
        }
    }

    private void ensureAlias() {
        runRequired("set alias", "alias", "set", alias, endpoint, rootAccessKey, rootSecretKey);
    }

    private CommandResult run(String... args) {
        List<String> command = new ArrayList<>();
        command.add(mcPath);
        command.add("--json");
        command.addAll(List.of(args));

        try {
            Process process = new ProcessBuilder(command)
                    .redirectErrorStream(true)
                    .start();
            boolean finished = process.waitFor(COMMAND_TIMEOUT.toSeconds(), TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                return new CommandResult(-1, "command timed out");
            }
            String output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
            return new CommandResult(process.exitValue(), output);
        } catch (Exception exception) {
            throw new IllegalStateException("mc command failed: " + exception.getMessage(), exception);
        }
    }

    private void runRequired(String operation, String... args) {
        CommandResult result = run(args);
        if (result.exitCode() != 0) {
            throw new IllegalStateException(operation + " failed: " + result.output());
        }
    }

    private String corsXml() {
        return """
                <CORSConfiguration>
                  <CORSRule>
                %s
                    <AllowedMethod>GET</AllowedMethod>
                    <AllowedMethod>PUT</AllowedMethod>
                    <AllowedMethod>POST</AllowedMethod>
                    <AllowedMethod>DELETE</AllowedMethod>
                    <AllowedMethod>HEAD</AllowedMethod>
                    <AllowedHeader>*</AllowedHeader>
                    <ExposeHeader>ETag</ExposeHeader>
                    <ExposeHeader>x-amz-request-id</ExposeHeader>
                    <ExposeHeader>x-amz-id-2</ExposeHeader>
                    <ExposeHeader>x-amz-version-id</ExposeHeader>
                    <MaxAgeSeconds>3000</MaxAgeSeconds>
                  </CORSRule>
                </CORSConfiguration>
                """.formatted(allowedOriginXml());
    }

    private String allowedOriginXml() {
        return allowedOrigins.stream()
                .map(origin -> "    <AllowedOrigin>" + escapeXml(origin) + "</AllowedOrigin>")
                .reduce((left, right) -> left + "\n" + right)
                .orElse("    <AllowedOrigin>http://localhost:5173</AllowedOrigin>");
    }

    private String escapeXml(String value) {
        return value
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&apos;");
    }

    private List<String> parseAllowedOrigins(String value) {
        List<String> origins = Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isBlank())
                .distinct()
                .toList();
        return origins.isEmpty() ? List.of("http://localhost:5173") : origins;
    }

    private void deleteCorsFile(Path corsFile) {
        if (corsFile == null) {
            return;
        }
        try {
            Files.deleteIfExists(corsFile);
        } catch (Exception ignored) {
            // Temporary file cleanup failure does not affect CORS provisioning result.
        }
    }

    private record CommandResult(int exitCode, String output) {
    }
}
