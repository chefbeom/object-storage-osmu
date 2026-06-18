package com.example.osmu.storageexpansion;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class StorageExpansionGitOpsPrRunner {

    private static final int MAX_CAPTURED_OUTPUT_LENGTH = 16000;
    private static final Pattern URL_PATTERN = Pattern.compile("https?://\\S+");

    private final boolean enabled;
    private final String repositoryPath;
    private final String gitPath;
    private final String ghPath;
    private final String baseBranch;
    private final Duration timeout;

    public StorageExpansionGitOpsPrRunner(
            @Value("${osmu.storage-expansion.gitops-pr-runner.enabled:false}") boolean enabled,
            @Value("${osmu.storage-expansion.gitops-pr-runner.repository-path:}") String repositoryPath,
            @Value("${osmu.storage-expansion.gitops-pr-runner.git-path:git}") String gitPath,
            @Value("${osmu.storage-expansion.gitops-pr-runner.gh-path:gh}") String ghPath,
            @Value("${osmu.storage-expansion.gitops-pr-runner.base-branch:main}") String baseBranch,
            @Value("${osmu.storage-expansion.gitops-pr-runner.timeout-seconds:60}") long timeoutSeconds
    ) {
        this.enabled = enabled;
        this.repositoryPath = repositoryPath == null ? "" : repositoryPath.trim();
        this.gitPath = gitPath;
        this.ghPath = ghPath;
        this.baseBranch = baseBranch == null || baseBranch.isBlank() ? "main" : baseBranch.trim();
        this.timeout = Duration.ofSeconds(Math.max(1L, timeoutSeconds));
    }

    public Result run(StorageExpansionGitOpsPlanResponse plan, List<ArtifactFile> files) {
        String commandText = commandText(plan);
        if (!enabled) {
            return new Result(
                    "SKIPPED",
                    commandText,
                    "Storage expansion GitOps PR runner disabled. Set OSMU_STORAGE_EXPANSION_GITOPS_PR_RUNNER_ENABLED=true to execute.",
                    null,
                    null,
                    false,
                    null
            );
        }
        if (repositoryPath.isBlank()) {
            return new Result("FAILED", commandText, "Storage expansion GitOps PR runner repository path is not configured.", null, -1, false, "REPOSITORY_CONFIG");
        }
        Path repository = Path.of(repositoryPath).toAbsolutePath().normalize();
        if (!Files.isDirectory(repository)) {
            return new Result("FAILED", commandText, "Storage expansion GitOps repository path does not exist: " + repository, null, -1, false, "REPOSITORY_CONFIG");
        }
        try {
            List<CommandResult> results = new ArrayList<>();
            results.add(runCommand(repository, List.of(gitPath, "checkout", "-B", plan.branchName())));
            Result failure = failureResult(commandText, results);
            if (failure != null) {
                return failure;
            }
            writeFiles(repository, files);
            results.add(runCommand(repository, gitAddCommand(plan.changedFiles())));
            failure = failureResult(commandText, results);
            if (failure != null) {
                return failure;
            }
            results.add(runCommand(repository, List.of(gitPath, "commit", "-m", plan.commitMessage())));
            failure = failureResult(commandText, results);
            if (failure != null) {
                return failure;
            }
            results.add(runCommand(repository, List.of(gitPath, "push", "-u", "origin", plan.branchName())));
            failure = failureResult(commandText, results);
            if (failure != null) {
                return failure;
            }
            results.add(runCommand(repository, List.of(
                    ghPath,
                    "pr",
                    "create",
                    "--title",
                    plan.pullRequestTitle(),
                    "--body",
                    plan.pullRequestBody(),
                    "--base",
                    baseBranch,
                    "--head",
                    plan.branchName()
            )));
            String output = combinedOutput(results);
            CommandResult failed = firstFailure(results);
            if (failed != null) {
                return new Result("FAILED", commandText, output, firstUrl(output), failed.exitCode(), failed.timedOut(), classifyFailure(failed, output));
            }
            return new Result("SUCCESS", commandText, output, firstUrl(output), 0, false, null);
        } catch (IOException exception) {
            return new Result("FAILED", commandText, "Storage expansion GitOps PR runner failed while preparing repository: " + exception.getMessage(), null, -1, false, "REPOSITORY_CONFIG");
        }
    }

    private void writeFiles(Path repository, List<ArtifactFile> files) throws IOException {
        for (ArtifactFile file : files) {
            Path target = repository.resolve(file.path()).normalize();
            if (!target.startsWith(repository)) {
                throw new IOException("GitOps artifact path escapes repository: " + file.path());
            }
            Files.createDirectories(target.getParent());
            Files.writeString(target, file.content(), StandardCharsets.UTF_8);
        }
    }

    private List<String> gitAddCommand(List<String> changedFiles) {
        List<String> command = new ArrayList<>();
        command.add(gitPath);
        command.add("add");
        command.addAll(changedFiles);
        return command;
    }

    private CommandResult runCommand(Path repository, List<String> command) {
        Path outputPath = null;
        try {
            outputPath = Files.createTempFile("osmu-gitops-pr-runner-", ".log");
            Process process = new ProcessBuilder(command)
                    .directory(repository.toFile())
                    .redirectErrorStream(true)
                    .redirectOutput(outputPath.toFile())
                    .start();
            boolean finished = process.waitFor(timeout.toSeconds(), TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                return new CommandResult(commandText(command), readOutput(outputPath), -1, true);
            }
            return new CommandResult(commandText(command), readOutput(outputPath), process.exitValue(), false);
        } catch (Exception exception) {
            return new CommandResult(commandText(command), exception.getMessage(), -1, false);
        } finally {
            if (outputPath != null) {
                try {
                    Files.deleteIfExists(outputPath);
                } catch (IOException ignored) {
                    // Temporary output cleanup should not change recorded runner result.
                }
            }
        }
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

    private String combinedOutput(List<CommandResult> results) {
        return String.join("\n\n", results.stream()
                .map(result -> """
                        $ %s
                        %s

                        exitCode: %d
                        timedOut: %s
                        """.formatted(
                        result.command(),
                        result.output() == null || result.output().isBlank() ? "(no output)" : result.output(),
                        result.exitCode(),
                        result.timedOut()
                ).trim())
                .toList());
    }

    private CommandResult firstFailure(List<CommandResult> results) {
        return results.stream()
                .filter(result -> result.exitCode() != 0 || result.timedOut())
                .findFirst()
                .orElse(null);
    }

    private Result failureResult(String commandText, List<CommandResult> results) {
        CommandResult failed = firstFailure(results);
        if (failed == null) {
            return null;
        }
        String output = combinedOutput(results);
        return new Result("FAILED", commandText, output, firstUrl(output), failed.exitCode(), failed.timedOut(), classifyFailure(failed, output));
    }

    private String classifyFailure(CommandResult failed, String output) {
        if (failed.timedOut()) {
            return "TIMEOUT";
        }
        String text = ((failed.command() == null ? "" : failed.command()) + "\n" + (output == null ? "" : output))
                .toLowerCase();
        if (text.contains("gh006") || text.contains("branch protection") || text.contains("protected branch")) {
            return "BRANCH_PROTECTION";
        }
        if (text.contains("not logged in") || text.contains("gh auth login") || text.contains("authentication")
                || text.contains("bad credentials") || text.contains("could not read username")) {
            return "AUTHENTICATION";
        }
        if (text.contains("403") || text.contains("permission denied") || text.contains("resource not accessible")
                || text.contains("insufficient scopes") || text.contains("not allowed")) {
            return "AUTHORIZATION";
        }
        if (text.contains("nothing to commit") || text.contains("no changes added")) {
            return "NO_CHANGES";
        }
        if (text.contains("local changes would be overwritten") || text.contains("untracked working tree files would be overwritten")) {
            return "DIRTY_WORKTREE";
        }
        if (text.contains("cannot run program") || text.contains("no such file") || text.contains("not found")) {
            return "TOOL_MISSING";
        }
        return "UNKNOWN";
    }

    private String commandText(StorageExpansionGitOpsPlanResponse plan) {
        return "%s checkout -B %s && %s add %s && %s commit -m \"%s\" && %s push -u origin %s && %s pr create --title \"%s\" --base %s --head %s"
                .formatted(
                        gitPath,
                        plan.branchName(),
                        gitPath,
                        String.join(" ", plan.changedFiles()),
                        gitPath,
                        plan.commitMessage(),
                        gitPath,
                        plan.branchName(),
                        ghPath,
                        plan.pullRequestTitle(),
                        baseBranch,
                        plan.branchName()
                );
    }

    private String commandText(List<String> command) {
        return String.join(" ", command.stream().map(this::quoteIfNeeded).toList());
    }

    private String quoteIfNeeded(String value) {
        return value.contains(" ") ? "\"%s\"".formatted(value) : value;
    }

    private String firstUrl(String value) {
        if (value == null) {
            return null;
        }
        Matcher matcher = URL_PATTERN.matcher(value);
        return matcher.find() ? matcher.group().replaceAll("[,.)]+$", "") : null;
    }

    public record ArtifactFile(String path, String content) {
    }

    public record Result(
            String result,
            String command,
            String output,
            String externalUrl,
            Integer exitCode,
            boolean timedOut,
            String failureReason
    ) {
    }

    private record CommandResult(
            String command,
            String output,
            int exitCode,
            boolean timedOut
    ) {
    }
}
