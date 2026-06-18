package com.example.osmu.storageexpansion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class StorageExpansionGitOpsPrRunnerTest {

    @TempDir
    private Path tempDir;

    @Test
    void enabledRunnerWritesArtifactsAndCapturesPullRequestUrl() throws Exception {
        Path repository = Files.createDirectory(tempDir.resolve("repo"));
        Files.createDirectory(repository.resolve(".git"));
        Path log = tempDir.resolve("commands.log");
        Path git = fakeCommand("git", log, null);
        Path gh = fakeCommand("gh", log, "https://git.example/osmu/pull/42");
        StorageExpansionGitOpsPrRunner runner = new StorageExpansionGitOpsPrRunner(
                true,
                repository.toString(),
                git.toString(),
                gh.toString(),
                "main",
                3
        );

        StorageExpansionGitOpsPrRunner.Result result = runner.run(plan(), files());

        assertEquals("SUCCESS", result.result());
        assertEquals("https://git.example/osmu/pull/42", result.externalUrl());
        assertEquals(0, result.exitCode());
        assertFalse(result.timedOut());
        assertEquals(null, result.failureReason());
        assertTrue(Files.readString(repository.resolve("infra/gitops/storage-expansion/pool-7/tenant-patch.yaml")).contains("kind: Tenant"));
        assertTrue(Files.readString(repository.resolve("infra/gitops/storage-expansion/pool-7/helm-values.yaml")).contains("volumeSize"));
        String commandLog = Files.readString(log);
        String normalizedCommandLog = commandLog.replace("\"", "");
        assertTrue(normalizedCommandLog.contains("git checkout -B storage-expansion/pool-7"));
        assertTrue(normalizedCommandLog.contains("git add infra/gitops/storage-expansion/pool-7/tenant-patch.yaml"));
        assertTrue(normalizedCommandLog.contains("git commit -m [Feat][I] : storage expansion pool-7 GitOps manifest draft"));
        assertTrue(normalizedCommandLog.contains("git push -u origin storage-expansion/pool-7"));
        assertTrue(normalizedCommandLog.contains("gh pr create --title [I] Storage expansion pool-7 GitOps draft"));
        assertTrue(result.output().contains("https://git.example/osmu/pull/42"));
    }

    @Test
    void enabledRunnerClassifiesBranchProtectionFailure() throws Exception {
        Path repository = Files.createDirectory(tempDir.resolve("repo"));
        Files.createDirectory(repository.resolve(".git"));
        Path log = tempDir.resolve("commands.log");
        Path git = fakeCommand("git", log, null, "push", "remote: GH006: Protected branch update failed");
        Path gh = fakeCommand("gh", log, "https://git.example/osmu/pull/42");
        StorageExpansionGitOpsPrRunner runner = new StorageExpansionGitOpsPrRunner(
                true,
                repository.toString(),
                git.toString(),
                gh.toString(),
                "main",
                3
        );

        StorageExpansionGitOpsPrRunner.Result result = runner.run(plan(), files());

        assertEquals("FAILED", result.result());
        assertEquals("BRANCH_PROTECTION", result.failureReason());
        assertEquals(1, result.exitCode());
        assertTrue(result.output().contains("GH006"));
        String commandLog = Files.readString(log);
        assertTrue(commandLog.contains("git push -u origin storage-expansion/pool-7"));
        assertFalse(commandLog.contains("gh pr create"));
    }

    @Test
    void enabledRunnerRejectsArtifactPathEscapingRepository() throws Exception {
        Path repository = Files.createDirectory(tempDir.resolve("repo"));
        Files.createDirectory(repository.resolve(".git"));
        Path log = tempDir.resolve("commands.log");
        Path git = fakeCommand("git", log, null);
        Path gh = fakeCommand("gh", log, "https://git.example/osmu/pull/42");
        StorageExpansionGitOpsPrRunner runner = new StorageExpansionGitOpsPrRunner(
                true,
                repository.toString(),
                git.toString(),
                gh.toString(),
                "main",
                3
        );

        StorageExpansionGitOpsPrRunner.Result result = runner.run(
                plan(),
                List.of(new StorageExpansionGitOpsPrRunner.ArtifactFile("../outside.yaml", "bad"))
        );

        assertEquals("FAILED", result.result());
        assertEquals("REPOSITORY_CONFIG", result.failureReason());
        assertTrue(result.output().contains("escapes repository"));
        assertFalse(Files.exists(tempDir.resolve("outside.yaml")));
    }

    private StorageExpansionGitOpsPlanResponse plan() {
        return new StorageExpansionGitOpsPlanResponse(
                7,
                "pool-7",
                "APPROVED",
                true,
                true,
                "storage-expansion/pool-7",
                "[Feat][I] : storage expansion pool-7 GitOps manifest draft",
                "[I] Storage expansion pool-7 GitOps draft",
                "Storage expansion GitOps draft body",
                "infra/gitops/storage-expansion/pool-7/tenant-patch.yaml",
                "infra/gitops/storage-expansion/pool-7/helm-values.yaml",
                "a".repeat(64),
                List.of(
                        "infra/gitops/storage-expansion/pool-7/tenant-patch.yaml",
                        "infra/gitops/storage-expansion/pool-7/helm-values.yaml",
                        "infra/gitops/storage-expansion/pool-7/README.md"
                ),
                List.of("Review dry-run")
        );
    }

    private List<StorageExpansionGitOpsPrRunner.ArtifactFile> files() {
        return List.of(
                new StorageExpansionGitOpsPrRunner.ArtifactFile("infra/gitops/storage-expansion/pool-7/tenant-patch.yaml", "kind: Tenant\n"),
                new StorageExpansionGitOpsPrRunner.ArtifactFile("infra/gitops/storage-expansion/pool-7/helm-values.yaml", "volumeSize: 50Gi\n"),
                new StorageExpansionGitOpsPrRunner.ArtifactFile("infra/gitops/storage-expansion/pool-7/README.md", "# pool-7\n")
        );
    }

    private Path fakeCommand(String commandName, Path log, String output) throws IOException {
        return fakeCommand(commandName, log, output, null, null);
    }

    private Path fakeCommand(String commandName, Path log, String output, String failArg, String failOutput) throws IOException {
        boolean windows = System.getProperty("os.name").toLowerCase().contains("win");
        Path command = tempDir.resolve(windows ? commandName + ".cmd" : commandName);
        String content = windows
                ? windowsCommand(commandName, log, output, failArg, failOutput)
                : shellCommand(commandName, log, output, failArg, failOutput);
        Files.writeString(command, content);
        command.toFile().setExecutable(true, false);
        return command;
    }

    private String shellCommand(String commandName, Path log, String output, String failArg, String failOutput) {
        String stdout = output == null ? "" : "printf '%s\\n' \"" + output + "\"\n";
        String failure = failArg == null ? "" : """
                if [ "$1" = "%s" ]; then
                  printf '%%s\\n' "%s"
                  exit 1
                fi
                """.formatted(failArg, failOutput);
        return """
                #!/bin/sh
                printf '%%s\\n' "%s $*" >> "%s"
                %s%sexit 0
                """.formatted(commandName, log, failure, stdout);
    }

    private String windowsCommand(String commandName, Path log, String output, String failArg, String failOutput) {
        String stdout = output == null ? "" : "echo " + output + "\r\n";
        String failure = failArg == null ? "" : """
                if "%%1"=="%s" (
                  echo %s
                  exit /b 1
                )
                """.formatted(failArg, failOutput);
        return """
                @echo off
                echo %s %%*>>"%s"
                %s%sexit /b 0
                """.formatted(commandName, log, failure, stdout);
    }
}
