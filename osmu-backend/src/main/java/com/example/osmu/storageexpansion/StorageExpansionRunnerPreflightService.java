package com.example.osmu.storageexpansion;

import java.time.Duration;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class StorageExpansionRunnerPreflightService {

    private final boolean dryRunRunnerEnabled;
    private final boolean applyRunnerEnabled;
    private final boolean rollbackRunnerEnabled;
    private final boolean gitOpsPrRunnerEnabled;
    private final String kubectlPath;
    private final String helmPath;
    private final String helmChartPath;
    private final String gitOpsRepositoryPath;
    private final String gitPath;
    private final String ghPath;
    private final Duration timeout;

    public StorageExpansionRunnerPreflightService(
            @Value("${osmu.storage-expansion.runner.enabled:false}") boolean dryRunRunnerEnabled,
            @Value("${osmu.storage-expansion.apply-runner.enabled:false}") boolean applyRunnerEnabled,
            @Value("${osmu.storage-expansion.rollback-runner.enabled:false}") boolean rollbackRunnerEnabled,
            @Value("${osmu.storage-expansion.gitops-pr-runner.enabled:false}") boolean gitOpsPrRunnerEnabled,
            @Value("${osmu.storage-expansion.runner.kubectl-path:kubectl}") String kubectlPath,
            @Value("${osmu.storage-expansion.runner.helm-path:helm}") String helmPath,
            @Value("${osmu.storage-expansion.runner.helm-chart-path:./infra/helm/osmu}") String helmChartPath,
            @Value("${osmu.storage-expansion.gitops-pr-runner.repository-path:}") String gitOpsRepositoryPath,
            @Value("${osmu.storage-expansion.gitops-pr-runner.git-path:git}") String gitPath,
            @Value("${osmu.storage-expansion.gitops-pr-runner.gh-path:gh}") String ghPath,
            @Value("${osmu.storage-expansion.runner.preflight-timeout-seconds:3}") long timeoutSeconds
    ) {
        this.dryRunRunnerEnabled = dryRunRunnerEnabled;
        this.applyRunnerEnabled = applyRunnerEnabled;
        this.rollbackRunnerEnabled = rollbackRunnerEnabled;
        this.gitOpsPrRunnerEnabled = gitOpsPrRunnerEnabled;
        this.kubectlPath = kubectlPath;
        this.helmPath = helmPath;
        this.helmChartPath = helmChartPath;
        this.gitOpsRepositoryPath = gitOpsRepositoryPath == null ? "" : gitOpsRepositoryPath.trim();
        this.gitPath = gitPath;
        this.ghPath = ghPath;
        this.timeout = Duration.ofSeconds(Math.max(1L, timeoutSeconds));
    }

    public StorageExpansionRunnerPreflightResponse preflight() {
        List<StorageExpansionRunnerPreflightCheck> checks = List.of(
                runnerCheck(
                        "dry-run",
                        "Dry-run runner",
                        dryRunRunnerEnabled,
                        "Set OSMU_STORAGE_EXPANSION_RUNNER_ENABLED=true to execute kubectl/helm dry-runs.",
                        List.of(
                                probe("kubectl", kubectlPath, "version", "--client=true"),
                                probe("helm", helmPath, "version", "--short"),
                                probe("helm diff", helmPath, "diff", "version")
                        )
                ),
                runnerCheck(
                        "apply",
                        "Apply runner",
                        applyRunnerEnabled,
                        "Set OSMU_STORAGE_EXPANSION_APPLY_RUNNER_ENABLED=true to execute kubectl apply or helm upgrade.",
                        List.of(
                                probe("kubectl", kubectlPath, "version", "--client=true"),
                                probe("helm", helmPath, "version", "--short"),
                                pathProbe("helm chart", helmChartPath)
                        )
                ),
                runnerCheck(
                        "rollback",
                        "Rollback runner",
                        rollbackRunnerEnabled,
                        "Set OSMU_STORAGE_EXPANSION_ROLLBACK_RUNNER_ENABLED=true to execute helm rollback or kubectl rollout undo.",
                        List.of(
                                probe("kubectl", kubectlPath, "version", "--client=true"),
                                probe("helm", helmPath, "version", "--short")
                        )
                ),
                runnerCheck(
                        "gitops-pr",
                        "GitOps PR runner",
                        gitOpsPrRunnerEnabled,
                        "Set OSMU_STORAGE_EXPANSION_GITOPS_PR_RUNNER_ENABLED=true and configure OSMU_STORAGE_EXPANSION_GITOPS_REPOSITORY_PATH.",
                        List.of(
                                probe("git", gitPath, "--version"),
                                gitRepositoryProbe("gitops repository", gitOpsRepositoryPath),
                                probe("git repository status", gitPath, "-C", gitOpsRepositoryPath, "status", "--short"),
                                probe("gh", ghPath, "--version"),
                                probe("gh auth", ghPath, "auth", "status")
                        )
                )
        );
        int enabledRunnerCount = (int) checks.stream().filter(StorageExpansionRunnerPreflightCheck::enabled).count();
        int failedCheckCount = (int) checks.stream().filter(check -> "FAILED".equals(check.status())).count();
        String status = enabledRunnerCount == 0 ? "DISABLED" : failedCheckCount > 0 ? "FAILED" : "READY";
        return new StorageExpansionRunnerPreflightResponse(
                status,
                "READY".equals(status),
                enabledRunnerCount,
                failedCheckCount,
                checks
        );
    }

    private StorageExpansionRunnerPreflightCheck runnerCheck(
            String id,
            String label,
            boolean enabled,
            String disabledDetail,
            List<Probe> probes
    ) {
        if (!enabled) {
            return new StorageExpansionRunnerPreflightCheck(id, label, false, "DISABLED", disabledDetail, disabledDetail, List.of());
        }
        List<String> failures = new ArrayList<>();
        List<String> commands = new ArrayList<>();
        for (Probe probe : probes) {
            ProbeResult result = runProbe(probe);
            commands.add(result.command());
            if (!result.ok()) {
                failures.add("%s: %s".formatted(probe.label(), result.detail()));
            }
        }
        if (failures.isEmpty()) {
            return new StorageExpansionRunnerPreflightCheck(
                    id,
                    label,
                    true,
                    "READY",
                    "All required tools/configuration are available.",
                    "No action required.",
                    commands
            );
        }
        return new StorageExpansionRunnerPreflightCheck(
                id,
                label,
                true,
                "FAILED",
                String.join("; ", failures),
                remediation(id, failures),
                commands
        );
    }

    private String remediation(String id, List<String> failures) {
        String detail = String.join("; ", failures).toLowerCase();
        if (detail.contains("path not configured")) {
            return "Configure the required runner path and restart the backend.";
        }
        if (detail.contains("path does not exist")) {
            return "Create the configured path or update the matching OSMU_STORAGE_EXPANSION_* path setting.";
        }
        if (detail.contains("missing .git metadata")) {
            return "Point OSMU_STORAGE_EXPANSION_GITOPS_REPOSITORY_PATH to a cloned Git repository.";
        }
        if (detail.contains("auth status") || detail.contains("gh auth")) {
            return "Run gh auth login or provide a token with repository and pull request permissions for the service account.";
        }
        if (detail.contains("exitcode") || detail.contains("cannot run program") || detail.contains("no such file")) {
            return "Install the required CLI tools on the backend host or update kubectl/helm/git/gh path settings.";
        }
        if ("gitops-pr".equals(id)) {
            return "Verify GitOps repository path, git/gh binaries, and service account GitHub authentication.";
        }
        if ("apply".equals(id)) {
            return "Verify kubectl/helm binaries, Helm chart path, and Kubernetes access for the backend service account.";
        }
        if ("dry-run".equals(id)) {
            return "Verify kubectl/helm binaries and helm-diff plugin before running server dry-runs.";
        }
        if ("rollback".equals(id)) {
            return "Verify kubectl/helm binaries and Kubernetes access before running rollback.";
        }
        return "Inspect the failed command output and update runner configuration.";
    }

    private ProbeResult runProbe(Probe probe) {
        if (probe.kind() == ProbeKind.PATH) {
            return runPathProbe(probe.command());
        }
        if (probe.kind() == ProbeKind.GIT_REPOSITORY) {
            return runGitRepositoryProbe(probe.command());
        }
        if (probe.command() == null || probe.command().isBlank()) {
            return new ProbeResult(false, "-", "command not configured");
        }
        List<String> command = new ArrayList<>();
        command.add(probe.command());
        command.addAll(probe.args());
        String commandText = String.join(" ", command);
        try {
            Process process = new ProcessBuilder(command)
                    .redirectErrorStream(true)
                    .start();
            boolean finished = process.waitFor(timeout.toSeconds(), TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                return new ProbeResult(false, commandText, "timed out after %ds".formatted(timeout.toSeconds()));
            }
            int exitCode = process.exitValue();
            return new ProbeResult(exitCode == 0, commandText, exitCode == 0 ? "ok" : "exitCode=" + exitCode);
        } catch (Exception exception) {
            return new ProbeResult(false, commandText, exception.getMessage());
        }
    }

    private ProbeResult runPathProbe(String configuredPath) {
        if (configuredPath == null || configuredPath.isBlank()) {
            return new ProbeResult(false, "-", "path not configured");
        }
        Path path = Path.of(configuredPath).toAbsolutePath().normalize();
        return Files.exists(path)
                ? new ProbeResult(true, path.toString(), "exists")
                : new ProbeResult(false, path.toString(), "path does not exist");
    }

    private ProbeResult runGitRepositoryProbe(String configuredPath) {
        if (configuredPath == null || configuredPath.isBlank()) {
            return new ProbeResult(false, "-", "path not configured");
        }
        Path path = Path.of(configuredPath).toAbsolutePath().normalize();
        if (!Files.exists(path)) {
            return new ProbeResult(false, path.toString(), "path does not exist");
        }
        if (!Files.isDirectory(path)) {
            return new ProbeResult(false, path.toString(), "path is not a directory");
        }
        Path gitMetadata = path.resolve(".git");
        if (!Files.exists(gitMetadata)) {
            return new ProbeResult(false, path.toString(), "missing .git metadata");
        }
        return new ProbeResult(true, path.toString(), "git repository ready");
    }

    private Probe probe(String label, String command, String... args) {
        return new Probe(label, command, List.of(args), ProbeKind.COMMAND);
    }

    private Probe pathProbe(String label, String path) {
        return new Probe(label, path, List.of(), ProbeKind.PATH);
    }

    private Probe gitRepositoryProbe(String label, String path) {
        return new Probe(label, path, List.of(), ProbeKind.GIT_REPOSITORY);
    }

    private enum ProbeKind {
        COMMAND,
        PATH,
        GIT_REPOSITORY
    }

    private record Probe(String label, String command, List<String> args, ProbeKind kind) {
    }

    private record ProbeResult(boolean ok, String command, String detail) {
    }
}
