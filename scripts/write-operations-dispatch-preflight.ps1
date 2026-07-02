param(
    [string] $UnblockPlanPath = ".\.osmu-run\latest-operations-invocation-unblock-plan.json",
    [string] $JsonOutputPath = ".\.osmu-run\latest-operations-dispatch-preflight.json",
    [string] $MarkdownOutputPath = ".\.osmu-run\latest-operations-dispatch-preflight.md",
    [int[]] $ActionOrder = @(),
    [string[]] $Placeholder = @(),
    [string] $BackupTimestamp = "",
    [string] $RestoreApiBase = "",
    [string] $AdminLoginId = "",
    [string] $AdminPassword = "",
    [string] $ExpectedObjectCount = "",
    [switch] $ConfirmOperatorApproval,
    [switch] $KubeconfigSecretConfirmed,
    [switch] $CheckGitHubCli,
    [string] $GitHubCliPath = "",
    [string] $GitHubRepository = "",
    [string] $GitHubRef = "main",
    [string] $DefaultBranchRef = "origin/main",
    [switch] $CheckGitRefSafety,
    [switch] $NoWrite
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-Utf8Text([string] $PathValue) {
    $resolvedPath = Resolve-ProjectPath $PathValue
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false, $true))
}
function Get-JsonProperty([object] $Object, [string] $Name) {
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-Text([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return ""
    }
    return [string] $value
}

function Get-Int([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return 0
    }
    try {
        return [int] $value
    }
    catch {
        return 0
    }
}

function Get-Bool([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return $false
    }
    return [System.Convert]::ToBoolean($value)
}

function Get-Array([object] $Object, [string] $Name) {
    $value = Get-JsonProperty $Object $Name
    if ($null -eq $value) {
        return @()
    }
    if ($value -is [System.Array]) {
        return @($value)
    }
    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
        return @($value)
    }
    return @($value)
}

function Add-UniqueString([System.Collections.Generic.List[string]] $List, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }
    if (-not $List.Contains($Value)) {
        $List.Add($Value)
    }
}

function Add-Check([System.Collections.ArrayList] $Checks, [string] $Code, [string] $Status, [string] $Message) {
    $Checks.Add([ordered]@{
        code = $Code
        status = $Status
        message = $Message
    }) | Out-Null
}

function New-PlaceholderMap {
    $map = @{}
    foreach ($entry in $Placeholder) {
        if ([string]::IsNullOrWhiteSpace($entry)) {
            continue
        }
        $separatorIndex = $entry.IndexOf("=")
        if ($separatorIndex -le 0) {
            throw "Placeholder entries must use '<placeholder>=value' format. Invalid entry: $entry"
        }
        $name = $entry.Substring(0, $separatorIndex).Trim()
        $value = $entry.Substring($separatorIndex + 1)
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $map[$name] = $value
        }
    }
    return $map
}

function Get-InputValue([string] $Parameter, [string] $PlaceholderName, [hashtable] $PlaceholderMap) {
    switch ($Parameter) {
        "BackupTimestamp" { return $BackupTimestamp }
        "RestoreApiBase" { return $RestoreApiBase }
        "AdminLoginId" { return $AdminLoginId }
        "AdminPassword" { return $AdminPassword }
        "ExpectedObjectCount" { return $ExpectedObjectCount }
        "Placeholder" {
            if ($PlaceholderMap.ContainsKey($PlaceholderName)) {
                return [string] $PlaceholderMap[$PlaceholderName]
            }
            return ""
        }
        default {
            if ($PlaceholderMap.ContainsKey($PlaceholderName)) {
                return [string] $PlaceholderMap[$PlaceholderName]
            }
            return ""
        }
    }
}

function Get-InputValuePreview([string] $Parameter, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }
    if ($Parameter -eq "AdminPassword") {
        return "<redacted>"
    }
    return $Value
}

function Test-SafeInputValue([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $true
    }
    $unsafeFragments = @("`r", "`n", ";", "&&", "||", "|", "'", '"', '`', '$(', '@(')
    foreach ($fragment in $unsafeFragments) {
        if ($Value.Contains($fragment)) {
            return $false
        }
    }
    return -not ($Value -match '(^|\s)(\d|\*)?>{1,2}(\s|$)')
}

function Test-KnownInputValue([string] $Parameter, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $true
    }
    switch ($Parameter) {
        "BackupTimestamp" { return $Value -match '^\d{8}T\d{6}Z$' }
        "RestoreApiBase" { return $Value -match '^https?://[^\s]+$' }
        "ExpectedObjectCount" { return $Value -match '^\d+$' }
        default { return $true }
    }
}

function Get-InputCommandPart([string] $Parameter, [string] $PlaceholderName, [string] $Value) {
    $valueForCommand = if ($Parameter -eq "AdminPassword") { "<redacted>" } else { $Value }
    if ($Parameter -eq "Placeholder") {
        return "-Placeholder '$PlaceholderName=$valueForCommand'"
    }
    return "-$Parameter $valueForCommand"
}

function Join-ActionOrders([int[]] $Orders) {
    if ($null -eq $Orders -or $Orders.Count -eq 0) {
        return ""
    }
    return ($Orders | ForEach-Object { [string] $_ }) -join ","
}

function Quote-PowerShellArgument([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "''"
    }
    if ($Value -match '^[A-Za-z0-9_./:\\-]+$') {
        return $Value
    }
    return "'" + $Value.Replace("'", "''") + "'"
}

function Resolve-GitHubCliCandidate([string] $PathValue) {
    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ""
    }
    try {
        if ([System.IO.Path]::IsPathRooted($PathValue)) {
            return [System.IO.Path]::GetFullPath($PathValue)
        }
        return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $PathValue))
    }
    catch {
        return $PathValue
    }
}

function Add-GitHubCliPathArgument([System.Collections.Generic.List[string]] $Parts, [string] $ResolvedPath) {
    if ([string]::IsNullOrWhiteSpace($ResolvedPath)) {
        return
    }
    $Parts.Add("-GitHubCliPath $(Quote-PowerShellArgument $ResolvedPath)")
}

function Get-WorkflowName([string] $Command) {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return ""
    }
    $match = [regex]::Match($Command.Trim(), "^gh\s+workflow\s+run\s+([^\s]+)")
    if (-not $match.Success) {
        return ""
    }
    $workflow = $match.Groups[1].Value
    if ($workflow.Contains("/") -or $workflow.Contains("\")) {
        return [System.IO.Path]::GetFileName($workflow)
    }
    return $workflow
}

function Normalize-GitHubRepositorySlug([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }
    $trimmed = $Value.Trim()
    if ($trimmed -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        if ($trimmed.EndsWith(".git", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $trimmed.Substring(0, $trimmed.Length - 4)
        }
        return $trimmed
    }
    if ($trimmed -match '^https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?/?$') {
        return $matches[1]
    }
    if ($trimmed -match '^git@github\.com:([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?$') {
        return $matches[1]
    }
    return ""
}

function Resolve-GitHubRepositorySlug([string] $ExplicitRepository) {
    $explicit = Normalize-GitHubRepositorySlug $ExplicitRepository
    if (-not [string]::IsNullOrWhiteSpace($explicit)) {
        return $explicit
    }
    $environmentRepository = Normalize-GitHubRepositorySlug $env:GITHUB_REPOSITORY
    if (-not [string]::IsNullOrWhiteSpace($environmentRepository)) {
        return $environmentRepository
    }
    try {
        $remote = git -C $root config --get remote.origin.url 2>$null
        return Normalize-GitHubRepositorySlug ([string] $remote)
    }
    catch {
        return ""
    }
}

function Invoke-GitText([string[]] $Arguments) {
    try {
        $output = & git -C $root @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) {
            return @()
        }
        return @($output)
    }
    catch {
        return @()
    }
}

function Test-GitObjectExists([string] $ObjectSpec) {
    if ([string]::IsNullOrWhiteSpace($ObjectSpec)) {
        return $false
    }
    try {
        & git -C $root cat-file -e $ObjectSpec 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Normalize-GitRefName([string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }
    $trimmed = $Value.Trim()
    if ($trimmed.StartsWith("refs/heads/", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $trimmed.Substring("refs/heads/".Length)
    }
    return $trimmed
}

function Get-RemoteHeadCommit([string] $RemoteName, [string] $BranchName) {
    if ([string]::IsNullOrWhiteSpace($RemoteName) -or [string]::IsNullOrWhiteSpace($BranchName)) {
        return ""
    }
    $remoteRef = "refs/heads/$BranchName"
    $line = [string] ((Invoke-GitText @("ls-remote", "--heads", $RemoteName, $remoteRef) | Select-Object -First 1))
    if ([string]::IsNullOrWhiteSpace($line)) {
        return ""
    }
    if ($line -match '^\s*([0-9a-fA-F]{40})\s+') {
        return $matches[1].ToLowerInvariant()
    }
    return ""
}

function Get-GitRefSafetyReport([string] $ExpectedGitHubRef, [bool] $Enabled) {
    $report = [ordered]@{
        checked = [bool] $Enabled
        status = "skipped"
        githubRef = $ExpectedGitHubRef
        currentBranch = ""
        commitSha = ""
        shortCommitSha = ""
        upstreamRef = ""
        upstreamCommitSha = ""
        aheadCount = 0
        behindCount = 0
        workingTreeDirty = $false
        githubRefMatchesCurrentBranch = $false
        githubRefLikelyContainsCommit = $false
        suggestedGitHubRef = ""
        suggestedPushCommand = ""
        note = "Git ref safety check skipped."
    }
    if (-not $Enabled) {
        return $report
    }
    if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
        $report.status = "review-required"
        $report.note = "Git executable was not found; verify the GitHub ref manually before dispatch."
        return $report
    }

    $branch = [string] ((Invoke-GitText @("branch", "--show-current") | Select-Object -First 1))
    $commit = [string] ((Invoke-GitText @("rev-parse", "HEAD") | Select-Object -First 1))
    $upstream = [string] ((Invoke-GitText @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}") | Select-Object -First 1))
    $upstreamCommit = if ([string]::IsNullOrWhiteSpace($upstream)) { "" } else { [string] ((Invoke-GitText @("rev-parse", $upstream) | Select-Object -First 1)) }
    $dirty = @(Invoke-GitText @("status", "--porcelain")).Count -gt 0
    $ahead = 0
    $behind = 0
    if (-not [string]::IsNullOrWhiteSpace($upstream)) {
        $countLine = [string] ((Invoke-GitText @("rev-list", "--left-right", "--count", "$upstream...HEAD") | Select-Object -First 1))
        if ($countLine -match '^\s*(\d+)\s+(\d+)\s*$') {
            $behind = [int] $matches[1]
            $ahead = [int] $matches[2]
        }
    }
    $shortSha = if ($commit.Length -ge 8) { $commit.Substring(0, 8) } else { $commit }
    $expectedRef = Normalize-GitRefName $ExpectedGitHubRef
    $refMatchesBranch = -not [string]::IsNullOrWhiteSpace($branch) -and $expectedRef -eq $branch
    $suggestedRef = if ([string]::IsNullOrWhiteSpace($shortSha)) { "codex/operations-readiness" } else { "codex/operations-readiness-$shortSha" }
    $remoteRefCommit = ""
    $remoteRefMatchesCommit = $false
    if (-not $dirty -and -not $refMatchesBranch -and -not [string]::IsNullOrWhiteSpace($expectedRef) -and -not [string]::IsNullOrWhiteSpace($commit)) {
        $remoteRefCommit = Get-RemoteHeadCommit "origin" $expectedRef
        $remoteRefMatchesCommit = -not [string]::IsNullOrWhiteSpace($remoteRefCommit) -and $remoteRefCommit -eq $commit.ToLowerInvariant()
    }

    $report.currentBranch = $branch
    $report.commitSha = $commit
    $report.shortCommitSha = $shortSha
    $report.upstreamRef = $upstream
    $report.upstreamCommitSha = $upstreamCommit
    $report.aheadCount = $ahead
    $report.behindCount = $behind
    $report.workingTreeDirty = $dirty
    $report.githubRefMatchesCurrentBranch = $refMatchesBranch
    $report.githubRefLikelyContainsCommit = ($refMatchesBranch -and -not [string]::IsNullOrWhiteSpace($upstream) -and $ahead -eq 0) -or $remoteRefMatchesCommit
    $report.suggestedGitHubRef = $suggestedRef
    if (-not $dirty) {
        $report.suggestedPushCommand = "git push origin HEAD:refs/heads/$suggestedRef"
    }

    if ([string]::IsNullOrWhiteSpace($commit)) {
        $report.status = "review-required"
        $report.note = "Could not resolve the local HEAD commit; verify the GitHub ref manually before dispatch."
    }
    elseif ([string]::IsNullOrWhiteSpace($branch)) {
        $report.status = "review-required"
        $report.note = "Detached HEAD detected; push the commit to a named branch and pass that branch with -GitHubRef before dispatch. Suggested ref: $suggestedRef."
    }
    elseif ($dirty) {
        $report.status = "action-required"
        $aheadNote = if ($ahead -gt 0 -and -not [string]::IsNullOrWhiteSpace($upstream)) { " Current branch '$branch' is also $ahead commit(s) ahead of '$upstream'." } else { "" }
        $report.note = "Working tree has uncommitted changes; GitHub Actions will only run committed content from GitHubRef '$ExpectedGitHubRef', not local dirty files.$aheadNote Commit or intentionally exclude the changes, rerun preflight, then push a branch and dispatch that ref. Suggested ref after commit: $suggestedRef."
    }
    elseif ($remoteRefMatchesCommit) {
        $report.status = "ready"
        $report.suggestedPushCommand = ""
        $report.note = "Remote GitHubRef '$ExpectedGitHubRef' resolves to local commit $shortSha on origin."
    }
    elseif (-not $refMatchesBranch) {
        $report.status = "review-required"
        $report.note = "GitHubRef '$ExpectedGitHubRef' does not match current branch '$branch'. Ensure the selected ref contains commit $shortSha before dispatch. Suggested ref: $suggestedRef."
    }
    elseif ([string]::IsNullOrWhiteSpace($upstream)) {
        $report.status = "review-required"
        $report.note = "Current branch '$branch' has no upstream; push the commit before dispatch. Suggested command: $($report.suggestedPushCommand)."
    }
    elseif ($ahead -gt 0) {
        $report.status = "action-required"
        $report.note = "Current branch '$branch' is $ahead commit(s) ahead of '$upstream'; GitHubRef '$ExpectedGitHubRef' may not contain commit $shortSha yet. Push a branch and rerun preflight with that -GitHubRef before dispatch. Suggested command: $($report.suggestedPushCommand)."
    }
    else {
        $report.status = "ready"
        $report.githubRefLikelyContainsCommit = $true
        $report.note = "GitHubRef '$ExpectedGitHubRef' appears aligned with local commit $shortSha."
    }
    return $report
}

function Get-GitHubWorkflowDispatchUrl([string] $RepositorySlug, [string] $WorkflowName) {
    if ([string]::IsNullOrWhiteSpace($RepositorySlug) -or [string]::IsNullOrWhiteSpace($WorkflowName)) {
        return ""
    }
    return "https://github.com/$RepositorySlug/actions/workflows/$WorkflowName"
}

function Get-WorkflowSecrets([string] $WorkflowPath) {
    if (-not (Test-Path -LiteralPath $WorkflowPath)) {
        return @()
    }
    $content = Read-Utf8Text $WorkflowPath
    $secrets = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($content, "secrets\.([A-Za-z_][A-Za-z0-9_]*)")) {
        Add-UniqueString $secrets $match.Groups[1].Value
    }
    return @($secrets)
}

function Test-WorkflowCommandFlag([string] $Command, [string] $FlagName) {
    if ([string]::IsNullOrWhiteSpace($Command) -or [string]::IsNullOrWhiteSpace($FlagName)) {
        return $false
    }
    return $Command.ToLowerInvariant().Contains("$($FlagName.ToLowerInvariant())=true")
}

function Test-WorkflowCommandValue([string] $Command, [string] $InputName, [string] $InputValue) {
    if ([string]::IsNullOrWhiteSpace($Command) -or [string]::IsNullOrWhiteSpace($InputName) -or [string]::IsNullOrWhiteSpace($InputValue)) {
        return $false
    }
    return $Command.ToLowerInvariant().Contains("$($InputName.ToLowerInvariant())=$($InputValue.ToLowerInvariant())")
}

function Get-RequiredWorkflowSecrets([string] $WorkflowName, [string] $Command, [object] $Action, [string] $WorkflowPath) {
    $secrets = New-Object System.Collections.Generic.List[string]
    $name = $WorkflowName.ToLowerInvariant()
    $needsKubeconfig = Get-Bool $Action "needsKubeconfigSecretConfirmation"

    switch ($name) {
        "storage-expansion-finalizer-ci.yml" {
            if ($needsKubeconfig -or (Test-WorkflowCommandFlag $Command "run_live")) {
                Add-UniqueString $secrets "OSMU_KUBECONFIG_BASE64"
            }
            if ((Test-WorkflowCommandFlag $Command "run_backend_dry_run_runner") -or (Test-WorkflowCommandFlag $Command "run_backend_apply")) {
                Add-UniqueString $secrets "OSMU_ADMIN_PASSWORD"
            }
        }
        "kubernetes-ha-dr-readiness-ci.yml" {
            if ($needsKubeconfig -or (Test-WorkflowCommandFlag $Command "run_live")) {
                Add-UniqueString $secrets "OSMU_KUBECONFIG_BASE64"
            }
        }
        "kubernetes-dr-finalizer-ci.yml" {
            if ($needsKubeconfig -or (Test-WorkflowCommandFlag $Command "run_live")) {
                Add-UniqueString $secrets "OSMU_KUBECONFIG_BASE64"
            }
            if ((Test-WorkflowCommandFlag $Command "confirm_restore") -and -not (Test-WorkflowCommandFlag $Command "skip_restore_smoke")) {
                Add-UniqueString $secrets "OSMU_ADMIN_PASSWORD"
            }
        }
        "operations-readiness-finalizer-ci.yml" {
            if ($needsKubeconfig -or (Test-WorkflowCommandFlag $Command "run_live")) {
                Add-UniqueString $secrets "OSMU_KUBECONFIG_BASE64"
            }
            if (Test-WorkflowCommandFlag $Command "confirm_restore") {
                Add-UniqueString $secrets "OSMU_ADMIN_PASSWORD"
            }
        }
        "iam-rbac-finalizer-ci.yml" {
            if ($needsKubeconfig -or (Test-WorkflowCommandFlag $Command "run_live") -or (Test-WorkflowCommandFlag $Command "run_kubernetes_live_auth")) {
                Add-UniqueString $secrets "OSMU_KUBECONFIG_BASE64"
            }
        }
        "kubernetes-operations-report-sync-ci.yml" {
            if ($needsKubeconfig -or (Test-WorkflowCommandFlag $Command "run_live") -or (Test-WorkflowCommandFlag $Command "apply")) {
                Add-UniqueString $secrets "OSMU_KUBECONFIG_BASE64"
            }
        }
        "enterprise-auth-smoke-ci.yml" {
            if (Test-WorkflowCommandFlag $Command "run_live") {
                Add-UniqueString $secrets "OSMU_ENTERPRISE_AUTH_ADMIN_PASSWORD"
            }
            if (Test-WorkflowCommandFlag $Command "require_ldap") {
                Add-UniqueString $secrets "OSMU_ENTERPRISE_AUTH_LDAP_LOGIN_ID"
                Add-UniqueString $secrets "OSMU_ENTERPRISE_AUTH_LDAP_PASSWORD"
            }
            if (Test-WorkflowCommandFlag $Command "require_oidc") {
                Add-UniqueString $secrets "OSMU_ENTERPRISE_AUTH_OIDC_CALLBACK_CODE"
                Add-UniqueString $secrets "OSMU_ENTERPRISE_AUTH_OIDC_CALLBACK_STATE"
            }
            if (Test-WorkflowCommandFlag $Command "confirm_jit_provision") {
                Add-UniqueString $secrets "OSMU_ENTERPRISE_AUTH_JIT_PROVISION_JSON_BASE64"
            }
        }
        "manual-storage-backend-telemetry-evidence.yml" {
            if (Test-WorkflowCommandValue $Command "collection_mode" "live") {
                Add-UniqueString $secrets "OSMU_MINIO_ACCESS_KEY"
                Add-UniqueString $secrets "OSMU_MINIO_SECRET_KEY"
            }
            else {
                Add-UniqueString $secrets "OSMU_MINIO_ADMIN_INFO_JSON_BASE64"
            }
        }
        default {
            foreach ($secret in @(Get-WorkflowSecrets $WorkflowPath)) {
                Add-UniqueString $secrets $secret
            }
        }
    }

    return @($secrets)
}

$resolvedUnblockPlanPath = Resolve-ProjectPath $UnblockPlanPath
if (-not (Test-Path -LiteralPath $resolvedUnblockPlanPath)) {
    throw "Operations invocation unblock plan not found: $resolvedUnblockPlanPath"
}

$unblockPlan = Read-Utf8Text $resolvedUnblockPlanPath | ConvertFrom-Json
if ($unblockPlan.formatVersion -ne "osmu.operations-invocation-unblock-plan.v1") {
    throw "Unexpected operations invocation unblock plan formatVersion: $($unblockPlan.formatVersion)"
}

$checks = New-Object System.Collections.ArrayList
$selectedActions = New-Object System.Collections.ArrayList
$requiredInputs = New-Object System.Collections.ArrayList
$workflowFiles = New-Object System.Collections.ArrayList
$requiredSecrets = New-Object System.Collections.Generic.List[string]
$placeholderMap = New-PlaceholderMap
$resolvedGitHubCliPath = Resolve-GitHubCliCandidate $GitHubCliPath
$hasExplicitGitHubCliPath = -not [string]::IsNullOrWhiteSpace($resolvedGitHubCliPath)
$githubRepositorySlug = Resolve-GitHubRepositorySlug $GitHubRepository
$githubApiTokenPresent = (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) -or (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN))
$githubApiDispatchUnavailableReasons = New-Object System.Collections.Generic.List[string]
if (-not $githubApiTokenPresent) {
    Add-UniqueString $githubApiDispatchUnavailableReasons "GH_TOKEN or GITHUB_TOKEN is not set"
}
if ([string]::IsNullOrWhiteSpace($githubRepositorySlug)) {
    Add-UniqueString $githubApiDispatchUnavailableReasons "GitHub repository could not be resolved"
}
if ([string]::IsNullOrWhiteSpace($GitHubRef)) {
    Add-UniqueString $githubApiDispatchUnavailableReasons "GitHubRef is empty"
}
$githubApiDispatchAvailable = $githubApiDispatchUnavailableReasons.Count -eq 0
$gitRefSafety = Get-GitRefSafetyReport $GitHubRef ([bool] $CheckGitRefSafety)
$hasActionOrderFilter = $ActionOrder -and $ActionOrder.Count -gt 0
$githubCliAvailableForDispatch = $false

foreach ($action in @(Get-Array $unblockPlan "actions")) {
    $order = Get-Int $action "order"
    if ($hasActionOrderFilter -and -not ($ActionOrder -contains $order)) {
        continue
    }
    $selectedActions.Add($action) | Out-Null
}

if ($selectedActions.Count -eq 0) {
    Add-Check $checks "ACTION_SELECTION" "fail" "No actions were selected for dispatch preflight."
}
else {
    Add-Check $checks "ACTION_SELECTION" "pass" "$($selectedActions.Count) action(s) selected for dispatch preflight."
}

$needsKubeconfig = $false
$needsApproval = $false
$missingInputCount = 0
$ambiguousInputCount = 0
$unsafeInputCount = 0
$invalidInputCount = 0
$selectedOrders = New-Object System.Collections.Generic.List[int]
$commandParts = New-Object System.Collections.Generic.List[string]
$commandParts.Add("powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1")
Add-GitHubCliPathArgument $commandParts $resolvedGitHubCliPath

foreach ($action in @($selectedActions)) {
    $order = Get-Int $action "order"
    if ($order -gt 0) {
        $selectedOrders.Add($order)
    }
    if (Get-Bool $action "needsKubeconfigSecretConfirmation") {
        $needsKubeconfig = $true
    }
    if (Get-Bool $action "needsOperatorApprovalConfirmation") {
        $needsApproval = $true
    }

    $workflowName = Get-WorkflowName (Get-Text $action "command")
    if (-not [string]::IsNullOrWhiteSpace($workflowName)) {
        $workflowPath = Resolve-ProjectPath ".\.github\workflows\$workflowName"
        $workflowExists = Test-Path -LiteralPath $workflowPath
        $workflowDefaultBranchSpec = if ([string]::IsNullOrWhiteSpace($DefaultBranchRef)) { "" } else { "$DefaultBranchRef`:.github/workflows/$workflowName" }
        $workflowExistsOnDefaultBranch = (Test-GitObjectExists $workflowDefaultBranchSpec)
        $secrets = @(Get-RequiredWorkflowSecrets $workflowName (Get-Text $action "command") $action $workflowPath)
        $dispatchUrl = Get-GitHubWorkflowDispatchUrl $githubRepositorySlug $workflowName
        foreach ($secret in $secrets) {
            Add-UniqueString $requiredSecrets $secret
        }
        $workflowFiles.Add([ordered]@{
            actionOrder = $order
            workflow = $workflowName
            path = $workflowPath
            exists = $workflowExists
            defaultBranchRef = $DefaultBranchRef
            existsOnDefaultBranch = $workflowExistsOnDefaultBranch
            dispatchUrl = $dispatchUrl
            requiredSecrets = $secrets
        }) | Out-Null
    }

    foreach ($input in @(Get-Array $action "requiredInputs")) {
        $parameter = Get-Text $input "parameter"
        $placeholderName = Get-Text $input "placeholder"
        $value = Get-InputValue $parameter $placeholderName $placeholderMap
        $supplied = -not [string]::IsNullOrWhiteSpace($value)
        if (-not $supplied) {
            $missingInputCount++
        }
        $safeValue = (-not $supplied) -or (Test-SafeInputValue $value)
        if (-not $safeValue) {
            $unsafeInputCount++
        }
        $validValue = (-not $supplied) -or (Test-KnownInputValue $parameter $value)
        if (-not $validValue) {
            $invalidInputCount++
        }
        if (Get-Bool $input "ambiguousRepeatedPlaceholder") {
            $ambiguousInputCount++
        }
        $requiredInputs.Add([ordered]@{
            actionOrder = $order
            placeholder = $placeholderName
            parameter = $parameter
            valueTemplate = Get-Text $input "valueTemplate"
            workflowInputs = @(Get-Array $input "workflowInputs" | ForEach-Object { [string] $_ })
            supplied = $supplied
            safeValue = $safeValue
            validValue = $validValue
            valuePreview = Get-InputValuePreview $parameter $value
            ambiguousRepeatedPlaceholder = Get-Bool $input "ambiguousRepeatedPlaceholder"
            note = Get-Text $input "note"
        }) | Out-Null
    }
}

$inputTemplates = New-Object System.Collections.ArrayList
foreach ($action in @($selectedActions)) {
    $order = Get-Int $action "order"
    $workflowFile = @($workflowFiles | Where-Object { $_.actionOrder -eq $order } | Select-Object -First 1)
    $workflowName = ""
    $workflowSecrets = @()
    if ($workflowFile) {
        $workflowName = [string] $workflowFile.workflow
        $workflowSecrets = @($workflowFile.requiredSecrets | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) } | ForEach-Object { [string] $_ })
    }
    $workflowDispatchUrl = if ($workflowFile) { [string] $workflowFile.dispatchUrl } else { "" }

    $actionInputs = New-Object System.Collections.ArrayList
    foreach ($input in @($requiredInputs | Where-Object { $_.actionOrder -eq $order })) {
        $template = [string] $input.valueTemplate
        if ([string]::IsNullOrWhiteSpace($template)) {
            $template = [string] $input.placeholder
        }
        $actionInputs.Add([ordered]@{
            actionOrder = [int] $input.actionOrder
            placeholder = [string] $input.placeholder
            parameter = [string] $input.parameter
            valueTemplate = $template
            workflowInputs = @($input.workflowInputs | ForEach-Object { [string] $_ })
            supplied = [bool] $input.supplied
            safeValue = [bool] $input.safeValue
            validValue = [bool] $input.validValue
            valuePreview = [string] $input.valuePreview
            ambiguousRepeatedPlaceholder = [bool] $input.ambiguousRepeatedPlaceholder
            note = [string] $input.note
        }) | Out-Null
    }

    $operatorChecklist = New-Object System.Collections.Generic.List[string]
    if (Get-Bool $action "needsOperatorApprovalConfirmation") {
        $operatorChecklist.Add("Confirm operator approval")
    }
    if (Get-Bool $action "needsKubeconfigSecretConfirmation") {
        $operatorChecklist.Add("Confirm OSMU_KUBECONFIG_BASE64 secret readiness")
    }
    foreach ($secret in $workflowSecrets) {
        if (-not [string]::IsNullOrWhiteSpace($secret)) {
            $operatorChecklist.Add("Ensure GitHub secret $secret is configured")
        }
    }
    if ($actionInputs.Count -gt 0) {
        $operatorChecklist.Add("Fill $($actionInputs.Count) required input value(s)")
    }

    $workflowInputNames = New-Object System.Collections.Generic.List[string]
    $missingInputParameters = New-Object System.Collections.Generic.List[string]
    $unsafeInputParameters = New-Object System.Collections.Generic.List[string]
    $invalidInputParameters = New-Object System.Collections.Generic.List[string]
    foreach ($input in @($actionInputs)) {
        foreach ($workflowInputName in @($input.workflowInputs)) {
            Add-UniqueString $workflowInputNames ([string] $workflowInputName)
        }
        if (-not [bool] $input.supplied) {
            Add-UniqueString $missingInputParameters ([string] $input.parameter)
        }
        if (-not [bool] $input.safeValue) {
            Add-UniqueString $unsafeInputParameters ([string] $input.parameter)
        }
        if (-not [bool] $input.validValue) {
            Add-UniqueString $invalidInputParameters ([string] $input.parameter)
        }
    }
    $actionMissingInputCount = @($actionInputs | Where-Object { -not $_.supplied }).Count
    $actionUnsafeInputCount = @($actionInputs | Where-Object { -not $_.safeValue }).Count
    $actionInvalidInputCount = @($actionInputs | Where-Object { -not $_.validValue }).Count
    $actionAmbiguousInputCount = @($actionInputs | Where-Object { $_.ambiguousRepeatedPlaceholder }).Count
    $workflowReady = [string]::IsNullOrWhiteSpace($workflowName) -or ($workflowFile -and [bool] $workflowFile.exists)
    $operatorApprovalReady = (-not (Get-Bool $action "needsOperatorApprovalConfirmation")) -or [bool] $ConfirmOperatorApproval
    $kubeconfigReady = (-not (Get-Bool $action "needsKubeconfigSecretConfirmation")) -or [bool] $KubeconfigSecretConfirmed
    $readyToDispatch = $workflowReady -and $operatorApprovalReady -and $kubeconfigReady -and ($actionMissingInputCount -eq 0) -and ($actionUnsafeInputCount -eq 0) -and ($actionInvalidInputCount -eq 0) -and ($actionAmbiguousInputCount -eq 0)

    $inputTemplates.Add([ordered]@{
        actionOrder = $order
        name = Get-Text $action "name"
        category = Get-Text $action "category"
        actionType = Get-Text $action "actionType"
        commandMode = Get-Text $action "commandMode"
        workflow = $workflowName
        dispatchUrl = $workflowDispatchUrl
        needsOperatorApprovalConfirmation = Get-Bool $action "needsOperatorApprovalConfirmation"
        needsKubeconfigSecretConfirmation = Get-Bool $action "needsKubeconfigSecretConfirmation"
        requiredSecrets = @($workflowSecrets)
        workflowInputNames = @($workflowInputNames)
        readyToDispatch = $readyToDispatch
        missingInputCount = $actionMissingInputCount
        unsafeInputCount = $actionUnsafeInputCount
        invalidInputCount = $actionInvalidInputCount
        ambiguousInputCount = $actionAmbiguousInputCount
        missingInputParameters = @($missingInputParameters)
        unsafeInputParameters = @($unsafeInputParameters)
        invalidInputParameters = @($invalidInputParameters)
        inputs = @($actionInputs)
        operatorChecklist = @($operatorChecklist)
    }) | Out-Null
}

$readyInputTemplates = @($inputTemplates | Where-Object { [bool] $_.readyToDispatch })
$blockedInputTemplates = @($inputTemplates | Where-Object { -not [bool] $_.readyToDispatch })
$readyActionOrders = @($readyInputTemplates | ForEach-Object { [int] $_.actionOrder } | Where-Object { $_ -gt 0 })
$blockedActionOrders = @($blockedInputTemplates | ForEach-Object { [int] $_.actionOrder } | Where-Object { $_ -gt 0 })
$readySubsetCommandParts = New-Object System.Collections.Generic.List[string]
$readySubsetCommandParts.Add("powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\invoke-operations-evidence-plan.ps1")
Add-GitHubCliPathArgument $readySubsetCommandParts $resolvedGitHubCliPath
if ($readyActionOrders.Count -gt 0) {
    $readySubsetCommandParts.Add("-ActionOrder $(Join-ActionOrders @($readyActionOrders))")
}
$readySubsetNeedsKubeconfig = @($readyInputTemplates | Where-Object { [bool] $_.needsKubeconfigSecretConfirmation }).Count -gt 0
$readySubsetNeedsApproval = @($readyInputTemplates | Where-Object { [bool] $_.needsOperatorApprovalConfirmation }).Count -gt 0
if ($readySubsetNeedsKubeconfig) {
    $readySubsetCommandParts.Add("-KubeconfigSecretConfirmed")
}
if ($readySubsetNeedsApproval) {
    $readySubsetCommandParts.Add("-ConfirmOperatorApproval")
}
foreach ($input in @($requiredInputs | Where-Object { ($readyActionOrders -contains [int] $_.actionOrder) -and [bool] $_.supplied })) {
    $readySubsetCommandParts.Add((Get-InputCommandPart $input.parameter $input.placeholder $input.valuePreview))
}

if ($selectedOrders.Count -gt 0) {
    $commandParts.Add("-ActionOrder $(Join-ActionOrders @($selectedOrders))")
}
if ($needsKubeconfig) {
    if ($KubeconfigSecretConfirmed) {
        Add-Check $checks "KUBECONFIG_SECRET_CONFIRMED" "pass" "Kubeconfig secret readiness was operator-confirmed."
        $commandParts.Add("-KubeconfigSecretConfirmed")
    }
    else {
        Add-Check $checks "KUBECONFIG_SECRET_CONFIRMED" "fail" "Selected actions require OSMU_KUBECONFIG_BASE64 readiness confirmation."
    }
}
else {
    Add-Check $checks "KUBECONFIG_SECRET_CONFIRMED" "pass" "Selected actions do not require kubeconfig secret confirmation."
}

if ($needsApproval) {
    if ($ConfirmOperatorApproval) {
        Add-Check $checks "OPERATOR_APPROVAL_CONFIRMED" "pass" "Operator approval was confirmed."
        $commandParts.Add("-ConfirmOperatorApproval")
    }
    else {
        Add-Check $checks "OPERATOR_APPROVAL_CONFIRMED" "fail" "Selected actions require explicit operator approval confirmation."
    }
}
else {
    Add-Check $checks "OPERATOR_APPROVAL_CONFIRMED" "pass" "Selected actions do not require operator approval confirmation."
}

if ($missingInputCount -eq 0) {
    Add-Check $checks "REQUIRED_INPUTS_SUPPLIED" "pass" "All required placeholder values were supplied."
}
else {
    Add-Check $checks "REQUIRED_INPUTS_SUPPLIED" "fail" "$missingInputCount required placeholder value(s) are missing."
}

if ($unsafeInputCount -eq 0) {
    Add-Check $checks "SAFE_INPUT_VALUES" "pass" "All supplied placeholder values pass the invocation command guard."
}
else {
    Add-Check $checks "SAFE_INPUT_VALUES" "fail" "$unsafeInputCount supplied placeholder value(s) would fail the invocation command guard."
}

if ($invalidInputCount -eq 0) {
    Add-Check $checks "KNOWN_INPUT_VALUE_SHAPES" "pass" "Known placeholder values match expected shapes."
}
else {
    Add-Check $checks "KNOWN_INPUT_VALUE_SHAPES" "fail" "$invalidInputCount known placeholder value(s) have invalid shape."
}

foreach ($input in @($requiredInputs)) {
    if (-not $input.supplied) {
        continue
    }
    $commandParts.Add((Get-InputCommandPart $input.parameter $input.placeholder $input.valuePreview))
}

$missingWorkflowFiles = @($workflowFiles | Where-Object { -not $_.exists })
if ($missingWorkflowFiles.Count -eq 0) {
    Add-Check $checks "WORKFLOW_FILES_PRESENT" "pass" "All selected workflow files exist locally."
}
else {
    Add-Check $checks "WORKFLOW_FILES_PRESENT" "fail" "$($missingWorkflowFiles.Count) selected workflow file(s) are missing."
}

$missingDefaultBranchWorkflowFiles = @($workflowFiles | Where-Object { -not $_.existsOnDefaultBranch })
if ([string]::IsNullOrWhiteSpace($DefaultBranchRef)) {
    Add-Check $checks "DEFAULT_BRANCH_WORKFLOW_FILES_PRESENT" "warn" "Default branch ref check skipped because DefaultBranchRef is blank."
}
elseif ($missingDefaultBranchWorkflowFiles.Count -eq 0) {
    Add-Check $checks "DEFAULT_BRANCH_WORKFLOW_FILES_PRESENT" "pass" "All selected workflow files exist on default branch ref $DefaultBranchRef."
}
else {
    Add-Check $checks "DEFAULT_BRANCH_WORKFLOW_FILES_PRESENT" "fail" "$($missingDefaultBranchWorkflowFiles.Count) selected workflow file(s) are missing from default branch ref $DefaultBranchRef; workflow_dispatch requires the workflow file to exist on the default branch before dispatch."
}

if ($CheckGitHubCli -or $hasExplicitGitHubCliPath) {
    if ($hasExplicitGitHubCliPath) {
        if (Test-Path -LiteralPath $resolvedGitHubCliPath) {
            $githubCliAvailableForDispatch = $true
            Add-Check $checks "GITHUB_CLI_AVAILABLE" "pass" "GitHub CLI found at explicit path $resolvedGitHubCliPath."
        }
        else {
            Add-Check $checks "GITHUB_CLI_AVAILABLE" "fail" "GitHub CLI was not found at explicit path $resolvedGitHubCliPath."
        }
    }
    else {
        $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
        if ($null -eq $ghCommand) {
            if ($githubApiDispatchAvailable) {
                Add-Check $checks "GITHUB_CLI_AVAILABLE" "warn" "GitHub CLI was not found on PATH; REST API dispatch is available through GH_TOKEN/GITHUB_TOKEN."
            }
            else {
                Add-Check $checks "GITHUB_CLI_AVAILABLE" "fail" "GitHub CLI was not found on PATH and REST API dispatch is unavailable: $($githubApiDispatchUnavailableReasons -join '; ')."
            }
        }
        else {
            $githubCliAvailableForDispatch = $true
            Add-Check $checks "GITHUB_CLI_AVAILABLE" "pass" "GitHub CLI found at $($ghCommand.Source)."
        }
    }
}
else {
    Add-Check $checks "GITHUB_CLI_AVAILABLE" "warn" "GitHub CLI availability check skipped. Run with -CheckGitHubCli or provide -GitHubCliPath before live dispatch."
}

if ($githubApiDispatchAvailable) {
    Add-Check $checks "GITHUB_API_DISPATCH_AVAILABLE" "pass" "REST API dispatch prerequisites are present for $githubRepositorySlug on ref $GitHubRef."
}
else {
    Add-Check $checks "GITHUB_API_DISPATCH_AVAILABLE" "warn" "REST API dispatch is unavailable: $($githubApiDispatchUnavailableReasons -join '; ')."
}

if ($ambiguousInputCount -gt 0) {
    Add-Check $checks "AMBIGUOUS_PLACEHOLDERS" "warn" "$ambiguousInputCount repeated generic placeholder input(s) need operator review."
}
else {
    Add-Check $checks "AMBIGUOUS_PLACEHOLDERS" "pass" "No repeated generic placeholder inputs detected."
}

if ($gitRefSafety.checked) {
    if ($gitRefSafety.status -eq "action-required") {
        Add-Check $checks "GITHUB_REF_SYNC" "fail" $gitRefSafety.note
    }
    elseif ($gitRefSafety.status -eq "ready") {
        Add-Check $checks "GITHUB_REF_SYNC" "pass" $gitRefSafety.note
    }
    else {
        Add-Check $checks "GITHUB_REF_SYNC" "warn" $gitRefSafety.note
    }
}

$failedCheckCount = @($checks | Where-Object { $_.status -eq "fail" }).Count
$warningCheckCount = @($checks | Where-Object { $_.status -eq "warn" }).Count
$result = if ($failedCheckCount -gt 0) { "action-required" } else { "ready" }
$readyPlanCommand = if ($failedCheckCount -eq 0) { $commandParts -join " " } else { "" }
$githubCliUnavailable = ($CheckGitHubCli -or $hasExplicitGitHubCliPath) -and -not $githubCliAvailableForDispatch
$executeCommand = if ($failedCheckCount -eq 0 -and -not $githubCliUnavailable) { "$readyPlanCommand -Execute" } else { "" }
$readySubsetPlanCommand = if ($readyActionOrders.Count -gt 0) { $readySubsetCommandParts -join " " } else { "" }
$readySubsetExecuteCommand = if (-not [string]::IsNullOrWhiteSpace($readySubsetPlanCommand) -and -not $githubCliUnavailable) { "$readySubsetPlanCommand -Execute" } else { "" }
$apiExecuteCommand = if (-not [string]::IsNullOrWhiteSpace($readyPlanCommand) -and -not [string]::IsNullOrWhiteSpace($githubRepositorySlug)) { "$readyPlanCommand -UseGitHubApi -GitHubRepository $githubRepositorySlug -GitHubRef $GitHubRef -Execute" } else { "" }
$readySubsetApiExecuteCommand = if (-not [string]::IsNullOrWhiteSpace($readySubsetPlanCommand) -and -not [string]::IsNullOrWhiteSpace($githubRepositorySlug)) { "$readySubsetPlanCommand -UseGitHubApi -GitHubRepository $githubRepositorySlug -GitHubRef $GitHubRef -Execute" } else { "" }
$generatedAt = [DateTimeOffset]::Now.ToString("o")

$report = [ordered]@{
    formatVersion = "osmu.operations-dispatch-preflight.v1"
    generatedAt = $generatedAt
    result = $result
    sourceUnblockPlan = $resolvedUnblockPlanPath
    sourceResult = Get-Text $unblockPlan "result"
    sourcePassedCount = Get-Int $unblockPlan "sourcePassedCount"
    sourcePendingCount = Get-Int $unblockPlan "sourcePendingCount"
    sourceTotalCount = Get-Int $unblockPlan "sourceTotalCount"
    sourceCheckCount = Get-Int $unblockPlan "sourceCheckCount"
    selectedActionCount = $selectedActions.Count
    selectedActionOrders = @($selectedOrders | ForEach-Object { [int] $_ })
    readyActionCount = $readyActionOrders.Count
    readyActionOrders = @($readyActionOrders | ForEach-Object { [int] $_ })
    blockedActionCount = $blockedActionOrders.Count
    blockedActionOrders = @($blockedActionOrders | ForEach-Object { [int] $_ })
    needsKubeconfigSecretConfirmation = $needsKubeconfig
    needsOperatorApprovalConfirmation = $needsApproval
    requiredInputCount = $requiredInputs.Count
    missingInputCount = $missingInputCount
    ambiguousInputCount = $ambiguousInputCount
    unsafeInputCount = $unsafeInputCount
    invalidInputCount = $invalidInputCount
    requiredGitHubSecrets = @($requiredSecrets)
    githubCliPath = $resolvedGitHubCliPath
    githubCliAvailableForDispatch = $githubCliAvailableForDispatch
    githubRepository = $githubRepositorySlug
    githubRef = $GitHubRef
    defaultBranchRef = $DefaultBranchRef
    githubApiTokenPresent = [bool] $githubApiTokenPresent
    githubApiDispatchAvailable = [bool] $githubApiDispatchAvailable
    githubApiDispatchUnavailableReasons = @($githubApiDispatchUnavailableReasons | ForEach-Object { [string] $_ })
    gitRefSafety = $gitRefSafety
    workflowFiles = @($workflowFiles)
    checks = @($checks)
    failedCheckCount = $failedCheckCount
    warningCheckCount = $warningCheckCount
    readyPlanCommand = $readyPlanCommand
    executeCommand = $executeCommand
    apiExecuteCommand = $apiExecuteCommand
    readySubsetPlanCommand = $readySubsetPlanCommand
    readySubsetExecuteCommand = $readySubsetExecuteCommand
    readySubsetApiExecuteCommand = $readySubsetApiExecuteCommand
    requiredInputs = @($requiredInputs)
    inputTemplates = @($inputTemplates)
    decisionRule = "Run the ready plan command first without -Execute. Use the execute command only after this preflight is ready and operator-approved live dispatch is intended; use GitHub CLI auth or -UseGitHubApi with GH_TOKEN/GITHUB_TOKEN. When readyActionCount is lower than selectedActionCount, the ready subset commands may be used to plan or execute only actions whose input templates are readyToDispatch=true."
}

$markdownLines = @(
    "# OSMU Operations Dispatch Preflight",
    "",
    "Generated at: $generatedAt",
    "Result: $result",
    "Source unblock plan: $resolvedUnblockPlanPath",
    "Source result: $($report.sourceResult)",
    "Source counts: passed=$($report.sourcePassedCount) pending=$($report.sourcePendingCount) total=$($report.sourceTotalCount) checks=$($report.sourceCheckCount)",
    "",
    "## Summary",
    "",
    "- Selected actions: $($report.selectedActionCount)",
    "- Ready actions: $($report.readyActionCount) ($(if ($readyActionOrders.Count -gt 0) { Join-ActionOrders @($readyActionOrders) } else { 'none' }))",
    "- Blocked actions: $($report.blockedActionCount) ($(if ($blockedActionOrders.Count -gt 0) { Join-ActionOrders @($blockedActionOrders) } else { 'none' }))",
    "- Missing inputs: $missingInputCount",
    "- Unsafe inputs: $unsafeInputCount",
    "- Invalid inputs: $invalidInputCount",
    "- Failed checks: $failedCheckCount",
    "- Warning checks: $warningCheckCount",
    "- Required GitHub secrets: $(if ($requiredSecrets.Count -gt 0) { @($requiredSecrets) -join ', ' } else { 'none detected' })",
    "- GitHub CLI path: $(if ([string]::IsNullOrWhiteSpace($resolvedGitHubCliPath)) { 'PATH lookup' } else { $resolvedGitHubCliPath })",
    "- GitHub CLI available for dispatch: $githubCliAvailableForDispatch",
    "- GitHub repository: $(if ([string]::IsNullOrWhiteSpace($githubRepositorySlug)) { 'unknown' } else { $githubRepositorySlug })",
    "- GitHub ref: $GitHubRef",
    "- Default branch ref: $(if ([string]::IsNullOrWhiteSpace($DefaultBranchRef)) { 'not checked' } else { $DefaultBranchRef })",
    "- GitHub API token present: $githubApiTokenPresent",
    "- GitHub API dispatch available: $githubApiDispatchAvailable",
    ""
)
if ($gitRefSafety.checked) {
    $gitRefSuggestedPushCommand = if ([string]::IsNullOrWhiteSpace($gitRefSafety.suggestedPushCommand)) { "n/a until the working tree is clean and preflight is rerun" } else { "``$($gitRefSafety.suggestedPushCommand)``" }
    $markdownLines += @(
        "## Git Ref Safety",
        "",
        "- Status: $($gitRefSafety.status)",
        "- Current branch: $($gitRefSafety.currentBranch)",
        "- Commit SHA: $($gitRefSafety.commitSha)",
        "- Upstream ref: $(if ([string]::IsNullOrWhiteSpace($gitRefSafety.upstreamRef)) { 'none' } else { $gitRefSafety.upstreamRef })",
        "- Ahead/behind: ahead=$($gitRefSafety.aheadCount), behind=$($gitRefSafety.behindCount)",
        "- Working tree dirty: $($gitRefSafety.workingTreeDirty)",
        "- Suggested GitHub ref: $($gitRefSafety.suggestedGitHubRef)",
        "- Suggested push command: $gitRefSuggestedPushCommand",
        "- Note: $($gitRefSafety.note)",
        ""
    )
}
if (-not [string]::IsNullOrWhiteSpace($readyPlanCommand)) {
    $markdownLines += "- Ready plan command: ``$readyPlanCommand``"
}
if (-not [string]::IsNullOrWhiteSpace($executeCommand)) {
    $markdownLines += "- Execute command: ``$executeCommand``"
}
if (-not [string]::IsNullOrWhiteSpace($apiExecuteCommand)) {
    $markdownLines += "- API execute command: ``$apiExecuteCommand``"
}
if (-not [string]::IsNullOrWhiteSpace($readySubsetPlanCommand)) {
    $markdownLines += "- Ready subset plan command: ``$readySubsetPlanCommand``"
}
if (-not [string]::IsNullOrWhiteSpace($readySubsetExecuteCommand)) {
    $markdownLines += "- Ready subset execute command: ``$readySubsetExecuteCommand``"
}
if (-not [string]::IsNullOrWhiteSpace($readySubsetApiExecuteCommand)) {
    $markdownLines += "- Ready subset API execute command: ``$readySubsetApiExecuteCommand``"
}
$markdownLines += @(
    "",
    "## Checks",
    ""
)
foreach ($check in $checks) {
    $markdownLines += "- [$($check.status)] $($check.code): $($check.message)"
}
$markdownLines += @(
    "",
    "## Required Inputs",
    ""
)
if ($requiredInputs.Count -eq 0) {
    $markdownLines += "- none"
}
else {
    foreach ($input in $requiredInputs) {
        $markdownLines += "- action $($input.actionOrder): $($input.parameter) for $($input.placeholder) supplied=$($input.supplied) safe=$($input.safeValue) valid=$($input.validValue)"
    }
}
$markdownLines += @(
    "",
    "## Input Templates",
    ""
)
if ($inputTemplates.Count -eq 0) {
    $markdownLines += "- none"
}
else {
    foreach ($template in $inputTemplates) {
        $workflowLabel = if ([string]::IsNullOrWhiteSpace($template.workflow)) { "local command" } else { $template.workflow }
        $secretLabel = if (@($template.requiredSecrets).Count -gt 0) { @($template.requiredSecrets) -join ', ' } else { 'none' }
        $workflowInputLabel = if (@($template.workflowInputNames).Count -gt 0) { @($template.workflowInputNames) -join ', ' } else { 'none' }
        $dispatchLabel = if ([string]::IsNullOrWhiteSpace($template.dispatchUrl)) { "none" } else { $template.dispatchUrl }
        $markdownLines += "- action $($template.actionOrder) - $($template.name): workflow=$workflowLabel, dispatchUrl=$dispatchLabel, readyToDispatch=$($template.readyToDispatch), missingInputs=$($template.missingInputCount), unsafeInputs=$($template.unsafeInputCount), invalidInputs=$($template.invalidInputCount), workflowInputs=$workflowInputLabel, requiredSecrets=$secretLabel"
        foreach ($input in @($template.inputs)) {
            $workflowInputLabel = if (@($input.workflowInputs).Count -gt 0) { ", workflowInputs=$((@($input.workflowInputs) | ForEach-Object { [string] $_ }) -join ', ')" } else { "" }
            $markdownLines += "  - $($input.parameter) $($input.placeholder): template=$($input.valueTemplate), supplied=$($input.supplied)$workflowInputLabel"
        }
    }
}

$markdownLines += @(
    "",
    "## Workflow Dispatch URLs",
    ""
)
$dispatchWorkflows = @($workflowFiles | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_.dispatchUrl) })
if ($dispatchWorkflows.Count -eq 0) {
    $markdownLines += "- none"
}
else {
    foreach ($workflow in $dispatchWorkflows) {
        $defaultBranchLabel = if ([bool] $workflow.existsOnDefaultBranch) { "present" } else { "missing" }
        $markdownLines += "- action $($workflow.actionOrder) - $($workflow.workflow): $($workflow.dispatchUrl) (defaultBranch=$($workflow.defaultBranchRef), defaultBranchFile=$defaultBranchLabel)"
    }
}

if (-not $NoWrite) {
    $resolvedJsonOutputPath = Resolve-ProjectPath $JsonOutputPath
    $resolvedMarkdownOutputPath = Resolve-ProjectPath $MarkdownOutputPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedJsonOutputPath) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedMarkdownOutputPath) | Out-Null
    $report | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $resolvedJsonOutputPath -Encoding UTF8
    $markdownLines | Set-Content -LiteralPath $resolvedMarkdownOutputPath -Encoding UTF8
    Write-Host "Operations dispatch preflight JSON: $resolvedJsonOutputPath"
    Write-Host "Operations dispatch preflight markdown: $resolvedMarkdownOutputPath"
}

$report | ConvertTo-Json -Depth 18
