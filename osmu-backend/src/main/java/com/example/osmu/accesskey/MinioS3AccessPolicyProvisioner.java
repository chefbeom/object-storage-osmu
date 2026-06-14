package com.example.osmu.accesskey;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.access-key", name = "provisioning-mode", havingValue = "minio")
public class MinioS3AccessPolicyProvisioner implements S3AccessPolicyProvisioner {

    private static final Duration COMMAND_TIMEOUT = Duration.ofSeconds(30);

    private final String mcPath;
    private final String alias;
    private final String endpoint;
    private final String rootAccessKey;
    private final String rootSecretKey;

    public MinioS3AccessPolicyProvisioner(
            @Value("${osmu.storage.endpoint}") String endpoint,
            @Value("${osmu.storage.access-key}") String accessKey,
            @Value("${osmu.storage.secret-key}") String secretKey,
            @Value("${osmu.access-key.minio.mc-path:mc}") String mcPath,
            @Value("${osmu.access-key.minio.alias:osmu-minio}") String alias
    ) {
        this.endpoint = endpoint;
        this.rootAccessKey = accessKey;
        this.rootSecretKey = secretKey;
        this.mcPath = mcPath;
        this.alias = alias;
    }

    @Override
    public void provision(AccessKeyRecord accessKey, String secretKey, S3AccessPolicy policy) {
        Path policyFile = null;
        try {
            ensureAlias();
            policyFile = Files.createTempFile("osmu-policy-", ".json");
            Files.writeString(policyFile, policy.policyDocument(), StandardCharsets.UTF_8);
            runRequired("create policy", "admin", "policy", "create", alias, policy.policyName(), policyFile.toString());
            runRequired("create user", "admin", "user", "add", alias, accessKey.accessKey(), secretKey);
            runRequired("attach policy", "admin", "policy", "attach", alias, policy.policyName(), "--user", accessKey.accessKey());
        } catch (Exception exception) {
            cleanupAfterFailedProvision(accessKey);
            throw storageException(exception);
        } finally {
            deletePolicyFile(policyFile);
        }
    }

    @Override
    public void syncPolicy(AccessKeyRecord accessKey, S3AccessPolicy policy) {
        Path policyFile = null;
        try {
            ensureAlias();
            policyFile = Files.createTempFile("osmu-policy-", ".json");
            Files.writeString(policyFile, policy.policyDocument(), StandardCharsets.UTF_8);
            runOptional("remove policy", "admin", "policy", "rm", alias, policy.policyName());
            runRequired("create policy", "admin", "policy", "create", alias, policy.policyName(), policyFile.toString());
            runRequired("attach policy", "admin", "policy", "attach", alias, policy.policyName(), "--user", accessKey.accessKey());
        } catch (Exception exception) {
            throw storageException(exception);
        } finally {
            deletePolicyFile(policyFile);
        }
    }

    @Override
    public void deactivate(AccessKeyRecord accessKey) {
        try {
            ensureAlias();
            runOptional("remove user", "admin", "user", "rm", alias, accessKey.accessKey());
            runOptional("remove policy", "admin", "policy", "rm", alias, accessKey.policyName());
        } catch (Exception exception) {
            throw storageException(exception);
        }
    }

    @Override
    public boolean isHealthy() {
        try {
            ensureAlias();
            runRequired("admin info", "admin", "info", alias);
            return true;
        } catch (Exception exception) {
            return false;
        }
    }

    private void ensureAlias() {
        runRequired("set alias", "alias", "set", alias, endpoint, rootAccessKey, rootSecretKey);
    }

    private void cleanupAfterFailedProvision(AccessKeyRecord accessKey) {
        try {
            runOptional("cleanup user", "admin", "user", "rm", alias, accessKey.accessKey());
            runOptional("cleanup policy", "admin", "policy", "rm", alias, accessKey.policyName());
        } catch (RuntimeException ignored) {
            // Keep original provisioning failure.
        }
    }

    private void runRequired(String operation, String... args) {
        CommandResult result = run(args);
        if (result.exitCode() != 0) {
            throw new IllegalStateException(operation + " failed: " + result.output());
        }
    }

    private void runOptional(String operation, String... args) {
        CommandResult result = run(args);
        if (result.exitCode() == 0 || isMissingResource(result.output())) {
            return;
        }
        throw new IllegalStateException(operation + " failed: " + result.output());
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

    private boolean isMissingResource(String output) {
        String normalized = output == null ? "" : output.toLowerCase(Locale.ROOT);
        return normalized.contains("not found")
                || normalized.contains("does not exist")
                || normalized.contains("no such")
                || normalized.contains("cannot find");
    }

    private void deletePolicyFile(Path policyFile) {
        if (policyFile == null) {
            return;
        }
        try {
            Files.deleteIfExists(policyFile);
        } catch (Exception ignored) {
            // Temporary file cleanup failure does not affect provisioning result.
        }
    }

    private ApiException storageException(Exception exception) {
        return new ApiException(ApiErrorCode.STORAGE_ERROR, "MinIO access key provisioning failed: " + exception.getMessage());
    }

    private record CommandResult(int exitCode, String output) {
    }
}
