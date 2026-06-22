param(
    [string] $MatrixPath = ".\dev-docs\s3-compatibility.md",
    [string] $ReadmePath = ".\README.md",
    [string] $ProductRequirementsPath = ".\PRODUCT_REQUIREMENTS.md",
    [string] $BackendDesignPath = ".\dev-docs\backend-design.md",
    [string] $ApiSpecPath = ".\dev-docs\api-spec.md",
    [string] $FeatureInventoryPath = ".\dev-docs\feature-inventory.md",
    [string] $RoadmapPath = ".\dev-docs\development-roadmap.md",
    [string] $PrototypeStatusPath = ".\dev-docs\prototype-status.md",
    [string] $TestCasesPath = ".\dev-docs\test-cases.md",
    [string] $MvpReleaseChecklistPath = ".\dev-docs\mvp-release-checklist.md",
    [string] $DocumentIndexPath = ".\dev-docs\document-index.md",
    [string] $DemoPackageNotesWriterPath = ".\scripts\write-mvp-demo-package-notes.ps1",
    [string] $MvpCompletionVerifierPath = ".\scripts\verify-mvp-completion.ps1"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath([string] $PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Read-RequiredText([string] $PathValue, [string] $Label) {
    $resolved = Resolve-ProjectPath $PathValue
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "$Label missing: $resolved"
    }
    return [pscustomobject]@{
        label = $Label
        path = $resolved
        text = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolved
    }
}

function Assert-Contains([object] $File, [string] $Expected) {
    if (-not $File.text.Contains($Expected)) {
        throw "$($File.label) does not contain expected text: $Expected"
    }
}

function Assert-NotContains([object] $File, [string] $Unexpected) {
    if ($File.text.IndexOf($Unexpected, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "$($File.label) contains overbroad S3 claim: $Unexpected"
    }
}

function Decode-Utf8Base64([string] $Value) {
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

$matrix = Read-RequiredText $MatrixPath "S3 compatibility matrix"
$readme = Read-RequiredText $ReadmePath "README"
$productRequirements = Read-RequiredText $ProductRequirementsPath "Product requirements"
$backendDesign = Read-RequiredText $BackendDesignPath "Backend design"
$apiSpec = Read-RequiredText $ApiSpecPath "API spec"
$featureInventory = Read-RequiredText $FeatureInventoryPath "Feature inventory"
$roadmap = Read-RequiredText $RoadmapPath "Development roadmap"
$prototypeStatus = Read-RequiredText $PrototypeStatusPath "Prototype status"
$testCases = Read-RequiredText $TestCasesPath "Test cases"
$releaseChecklist = Read-RequiredText $MvpReleaseChecklistPath "MVP release checklist"
$documentIndex = Read-RequiredText $DocumentIndexPath "Document index"
$demoPackageNotesWriter = Read-RequiredText $DemoPackageNotesWriterPath "MVP demo package notes writer"
$mvpCompletionVerifier = Read-RequiredText $MvpCompletionVerifierPath "MVP completion verifier"

Assert-Contains $matrix "## Product Boundary"
Assert-Contains $matrix "## Client Matrix"
Assert-Contains $matrix "## Verification Rule"
Assert-Contains $matrix "| AWS CLI | Supported smoke target |"
Assert-Contains $matrix '| MinIO Client `mc` | Supported smoke target |'
Assert-Contains $matrix "| boto3 | Supported smoke target |"
Assert-Contains $matrix "| AWS SDK JavaScript | Supported smoke target |"
Assert-Contains $matrix "Detailed AWS checksum negotiation/client-option parity is out of scope unless needed for a supported real-client smoke."
Assert-Contains $matrix "New S3 work should start from target-client replacement needs, not from chasing AWS edge parity for its own sake."
Assert-Contains $matrix "New S3 behavior is accepted into the roadmap only when it protects replacement use"

Assert-Contains $readme "dev-docs/s3-compatibility.md"
Assert-Contains $readme "verify-s3-client-smoke.ps1"
Assert-Contains $readme "verify-s3-compatibility-boundary.ps1"
Assert-Contains $readme (Decode-Utf8Base64 "64yA7LK07JqpIFMzLWNvbXBhdGlibGUgQVBJ")
Assert-Contains $readme (Decode-Utf8Base64 "QVdTIFMzIOyghOyytCDsiqTtjpnsnZgg7IS467aAIO2YuO2ZmOydhCDsoJztkogg66qp7ZGc66GcIOyCvOyngOuKlCDslYrripTri6Q=")

Assert-Contains $productRequirements "AWS SDK, boto3, AWS CLI, MinIO Client"
Assert-Contains $productRequirements "AWS S3"

Assert-Contains $backendDesign "not AWS S3 behavioral cloning"
Assert-Contains $backendDesign "real client smoke failures or OSMU product needs"
Assert-Contains $backendDesign "authoritative matrix for supported, partial, and unsupported S3 behavior"

Assert-Contains $apiSpec (Decode-Utf8Base64 "QVdTIFMzIOyghOyytCDrj5nsnpEg7Zi47ZmY7J2AIEFQSSDrqqntkZzqsIAg7JWE64uI64uk")

Assert-Contains $featureInventory (Decode-Utf8Base64 "QVdTIFMz66W8IOyTsOyngCDslYrqs6Ag7J6Q7LK0IOyKpO2GoOumrOyngOulvCDsmrTsmIHtlZjroKTripQg7KGw7KeB7JeQIOuMgOyytCDqsIDriqXtlZwg7IiY7KSA7J2YIFMzIO2YuO2ZmCDsoJHqt7wg7KCc6rO1")
Assert-Contains $featureInventory (Decode-Utf8Base64 "UzPripQgbWlncmF0aW9uIGNvbXBhdGliaWxpdHkgbGF5ZXI=")

Assert-Contains $roadmap "S3-compatible replacement layer"
Assert-Contains $roadmap "S3 client smoke"
Assert-Contains $roadmap "S3 replacement layer"
Assert-Contains $roadmap "### S3 Intake Gate"
Assert-Contains $roadmap (Decode-Utf8Base64 "7KeA7JuQIOuMgOyDgSByZWFsIGNsaWVudCBzbW9rZeqwgCDsi6TtjKjtlZzri6Qu")
Assert-Contains $roadmap (Decode-Utf8Base64 "6rOg6rCdIG1pZ3JhdGlvbiDrmJDripQg7IKs64K0IOyEnOu5hOyKpCDsoITtmZgg7Z2Q66aE7J20IOunie2ejOuLpC4=")
Assert-Contains $roadmap (Decode-Utf8Base64 "QVdTIOusuOyEnOydmCDshLjrtoAgY2hlY2tzdW0gbmVnb3RpYXRpb24=")
Assert-Contains $roadmap (Decode-Utf8Base64 "UzPripQg64yA7LK0IOyCrOyaqeydhCDqsIDriqXtlZjqsowg7ZWY64qUIOuztOyhsCDqs4TsuLU=")
Assert-Contains $roadmap (Decode-Utf8Base64 "QVdTIFMzIOyghOyytCDrs7XsoJzqsIAg7JWE64uI6528")

Assert-Contains $prototypeStatus "S3 compatibility role: replacement layer, not AWS edge parity"
Assert-Contains $prototypeStatus "S3-compatible replacement layer"
Assert-Contains $prototypeStatus "S3 replacement layer"

Assert-Contains $testCases "### TC-S3-COMPATIBILITY-BOUNDARY"
Assert-Contains $testCases "the roadmap contains the S3 intake gate"
Assert-Contains $testCases "broader checksum/client-option parity remains out of scope unless supported smoke fails"
Assert-Contains $testCases "remaining broader checksum negotiation gap explicitly kept out of scope unless supported real-client smoke fails"

Assert-Contains $releaseChecklist "verify-s3-compatibility-boundary.ps1"
Assert-Contains $documentIndex "verify-s3-compatibility-boundary.ps1"

Assert-Contains $demoPackageNotesWriter "## S3 Replacement Boundary"
Assert-Contains $demoPackageNotesWriter "It is not AWS S3 full behavioral parity"
Assert-Contains $demoPackageNotesWriter "dev-docs/s3-compatibility.md"

Assert-Contains $mvpCompletionVerifier "S3 replacement boundary verifier available"
Assert-Contains $mvpCompletionVerifier "S3 compatibility matrix preserves replacement boundary"
Assert-Contains $mvpCompletionVerifier "verify-s3-compatibility-boundary.ps1"

$filesToScan = @(
    $matrix,
    $readme,
    $productRequirements,
    $backendDesign,
    $apiSpec,
    $featureInventory,
    $roadmap,
    $prototypeStatus,
    $testCases,
    $releaseChecklist,
    $documentIndex,
    $demoPackageNotesWriter
)

$overbroadClaims = @(
    "100% AWS S3 compatible",
    "AWS S3 drop-in replacement",
    "complete AWS S3 compatibility",
    "full AWS S3 parity",
    "AWS S3 parity goal",
    "AWS S3 parity as a goal",
    (Decode-Utf8Base64 "QVdTIFMz7JmAIDEwMCUg7Zi47ZmY"),
    (Decode-Utf8Base64 "QVdTIFMzIOyZhOyghCDtmLjtmZjsnYQg67O07J6l"),
    (Decode-Utf8Base64 "QVdTIFMzIOyghOyytCDsiqTtjpkg7Zi47ZmYIOuztOyepQ=="),
    (Decode-Utf8Base64 "QVdTIFMzIOyghOyytCDrs7XsoJwg66qp7ZGc"),
    (Decode-Utf8Base64 "QVdTIFMzIOyEuOu2gCBwYXJpdHnrpbwg7KCc7ZKIIOuqqe2RnA==")
)

foreach ($file in $filesToScan) {
    foreach ($claim in $overbroadClaims) {
        Assert-NotContains $file $claim
    }
}

Write-Host "S3 compatibility boundary verified."
Write-Host "S3 compatibility matrix: $($matrix.path)"
