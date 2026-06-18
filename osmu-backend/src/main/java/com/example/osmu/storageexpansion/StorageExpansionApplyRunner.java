package com.example.osmu.storageexpansion;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class StorageExpansionApplyRunner {

    private static final int MAX_CAPTURED_OUTPUT_LENGTH = 16000;

    private final boolean enabled;
    private final String kubectlPath;
    private final String helmPath;
    private final String helmChartPath;
    private final String namespace;
    private final Duration timeout;

    public StorageExpansionApplyRunner(
            @Value("${osmu.storage-expansion.apply-runner.enabled:false}") boolean enabled,
            @Value("${osmu.storage-expansion.runner.kubectl-path:kubectl}") String kubectlPath,
            @Value("${osmu.storage-expansion.runner.helm-path:helm}") String helmPath,
            @Value("${osmu.storage-expansion.runner.helm-chart-path:./infra/helm/osmu}") String helmChartPath,
            @Value("${osmu.storage-expansion.runner.namespace:osmu}") String namespace,
            @Value("${osmu.storage-expansion.runner.timeout-seconds:30}") long timeoutSeconds
    ) {
        this.enabled = enabled;
        this.kubectlPath = kubectlPath;
        this.helmPath = helmPath;
        this.helmChartPath = helmChartPath;
        this.namespace = namespace;
        this.timeout = Duration.ofSeconds(Math.max(1L, timeoutSeconds));
    }

    public Result run(String applyType, StorageExpansionManifestResponse manifest, String bundleYaml) {
        Path workingDirectory = null;
        try {
            workingDirectory = Files.createTempDirectory("osmu-storage-expansion-apply-");
            Path bundlePath = workingDirectory.resolve("osmu-storage-expansion-%s-bundle.yaml".formatted(manifest.poolName()));
            Path valuesPath = workingDirectory.resolve("helm-values.yaml");
            Files.writeString(bundlePath, bundleYaml, StandardCharsets.UTF_8);
            Files.writeString(valuesPath, manifest.helmValuesPatchYaml(), StandardCharsets.UTF_8);
            List<String> command = command(applyType, bundlePath, valuesPath);
            String commandText = commandText(command);
            if (!enabled) {
                return new Result("SKIPPED", commandText, "Storage expansion apply runner disabled. Set OSMU_STORAGE_EXPANSION_APPLY_RUNNER_ENABLED=true to execute.", null, false);
            }
            return runCommand(command, workingDirectory, commandText);
        } catch (IOException exception) {
            return new Result("FAILED", "-", "Storage expansion apply runner failed before command start: " + exception.getMessage(), -1, false);
        } finally {
            deleteRecursively(workingDirectory);
        }
    }

    private Result runCommand(List<String> command, Path workingDirectory, String commandText) {
        Path outputPath = workingDirectory.resolve("apply-output.log");
        try {
            Process process = new ProcessBuilder(command)
                    .directory(workingDirectory.toFile())
                    .redirectErrorStream(true)
                    .redirectOutput(outputPath.toFile())
                    .start();
            boolean finished = process.waitFor(timeout.toSeconds(), TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                String output = readOutput(outputPath);
                return new Result("FAILED", commandText, appendRunnerSummary(output, -1, true), -1, true);
            }
            int exitCode = process.exitValue();
            String output = readOutput(outputPath);
            return new Result(exitCode == 0 ? "SUCCESS" : "FAILED", commandText, appendRunnerSummary(output, exitCode, false), exitCode, false);
        } catch (Exception exception) {
            return new Result("FAILED", commandText, "Storage expansion apply command failed: " + exception.getMessage(), -1, false);
        }
    }

    private List<String> command(String applyType, Path bundlePath, Path valuesPath) {
        if ("HELM_UPGRADE".equals(applyType)) {
            return List.of(helmPath, "upgrade", "osmu-minio", helmChartPath, "-f", valuesPath.toString());
        }
        return List.of(kubectlPath, "-n", namespace, "apply", "--server-side", "-f", bundlePath.toString());
    }

    private String commandText(List<String> command) {
        return String.join(" ", command.stream()
                .map(this::quoteIfNeeded)
                .toList());
    }

    private String quoteIfNeeded(String value) {
        return value.contains(" ") ? "\"%s\"".formatted(value) : value;
    }

    private String readOutput(Path outputPath) throws IOException {
        if (!Files.exists(outputPath)) {
            return "";
        }
        String output = Files.readString(outputPath, StandardCharsets.UTF_8).trim();
        if (output.length() <= MAX_CAPTURED_OUTPUT_LENGTH) {
            return output;
        }
        return output.substring(0, MAX_CAPTURED_OUTPUT_LENGTH) + "\n[output truncated]";
    }

    private String appendRunnerSummary(String output, int exitCode, boolean timedOut) {
        return """
                %s

                Apply runner summary:
                exitCode: %d
                timedOut: %s
                timeoutSeconds: %d
                """.formatted(output == null || output.isBlank() ? "(no output)" : output, exitCode, timedOut, timeout.toSeconds()).trim();
    }

    private void deleteRecursively(Path path) {
        if (path == null || !Files.exists(path)) {
            return;
        }
        try {
            try (var candidates = Files.walk(path)) {
                candidates.sorted(Comparator.reverseOrder())
                        .forEach(candidate -> {
                            try {
                                Files.deleteIfExists(candidate);
                            } catch (IOException ignored) {
                                // Temporary apply files should not affect recorded command result.
                            }
                        });
            }
        } catch (IOException ignored) {
            // Temporary apply files should not affect recorded command result.
        }
    }

    public record Result(
            String result,
            String command,
            String output,
            Integer exitCode,
            boolean timedOut
    ) {
    }
}
