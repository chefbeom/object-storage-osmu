package com.example.osmu.storageexpansion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class StorageExpansionRunnerPreflightServiceTest {

    @TempDir
    private Path tempDir;

    @Test
    void gitOpsRunnerPreflightChecksRepositoryStatusAndGithubAuth() throws Exception {
        Path binDir = Files.createDirectory(tempDir.resolve("bin"));
        Path repositoryDir = Files.createDirectory(tempDir.resolve("gitops"));
        Files.createDirectory(repositoryDir.resolve(".git"));
        Path git = fakeCommand(binDir, "git");
        Path gh = fakeCommand(binDir, "gh");

        StorageExpansionRunnerPreflightResponse response = service(repositoryDir, git, gh).preflight();

        StorageExpansionRunnerPreflightCheck gitOpsCheck = gitOpsCheck(response);
        assertEquals("READY", response.status());
        assertTrue(response.ready());
        assertEquals(1, response.enabledRunnerCount());
        assertEquals(0, response.failedCheckCount());
        assertEquals("READY", gitOpsCheck.status());
        assertEquals("No action required.", gitOpsCheck.remediation());
        assertTrue(gitOpsCheck.commands().stream().anyMatch(command -> command.contains("status --short")));
        assertTrue(gitOpsCheck.commands().stream().anyMatch(command -> command.contains("auth status")));
    }

    @Test
    void gitOpsRunnerPreflightFailsWhenRepositoryHasNoGitMetadata() throws Exception {
        Path binDir = Files.createDirectory(tempDir.resolve("bin"));
        Path repositoryDir = Files.createDirectory(tempDir.resolve("gitops"));
        Path git = fakeCommand(binDir, "git");
        Path gh = fakeCommand(binDir, "gh");

        StorageExpansionRunnerPreflightResponse response = service(repositoryDir, git, gh).preflight();

        StorageExpansionRunnerPreflightCheck gitOpsCheck = gitOpsCheck(response);
        assertEquals("FAILED", response.status());
        assertFalse(response.ready());
        assertEquals(1, response.enabledRunnerCount());
        assertEquals(1, response.failedCheckCount());
        assertEquals("FAILED", gitOpsCheck.status());
        assertTrue(gitOpsCheck.detail().contains("missing .git metadata"));
        assertTrue(gitOpsCheck.remediation().contains("cloned Git repository"));
    }

    private StorageExpansionRunnerPreflightService service(Path repositoryDir, Path git, Path gh) {
        return new StorageExpansionRunnerPreflightService(
                false,
                false,
                false,
                true,
                "kubectl",
                "helm",
                tempDir.toString(),
                repositoryDir.toString(),
                git.toString(),
                gh.toString(),
                1
        );
    }

    private StorageExpansionRunnerPreflightCheck gitOpsCheck(StorageExpansionRunnerPreflightResponse response) {
        return response.checks().stream()
                .filter(check -> "gitops-pr".equals(check.id()))
                .findFirst()
                .orElseThrow();
    }

    private Path fakeCommand(Path binDir, String commandName) throws IOException {
        boolean windows = System.getProperty("os.name").toLowerCase().contains("win");
        Path command = binDir.resolve(windows ? commandName + ".cmd" : commandName);
        String content = windows ? "@echo off\r\nexit /b 0\r\n" : "#!/bin/sh\nexit 0\n";
        Files.writeString(command, content);
        command.toFile().setExecutable(true, false);
        return command;
    }
}
