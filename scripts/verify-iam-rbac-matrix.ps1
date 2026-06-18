param(
    [string] $MatrixPath = ".\dev-docs\iam-rbac-matrix.md",
    [string] $SecurityDesignPath = ".\dev-docs\security-design.md",
    [string] $ApiSpecPath = ".\dev-docs\api-spec.md",
    [string] $FrontendDesignPath = ".\dev-docs\frontend-design.md",
    [string] $AdminRbacPolicyPath = ".\osmu-backend\src\main\java\com\example\osmu\auth\AdminRbacPolicy.java",
    [string] $DashboardLayoutServicePath = ".\osmu-backend\src\main\java\com\example\osmu\dashboard\DashboardLayoutService.java",
    [string] $HomeViewPath = ".\osmu-frontend\src\views\HomeView.vue"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-ProjectPath($path) {
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $root $path))
}

function Assert-True([bool] $condition, [string] $message) {
    if (-not $condition) {
        throw $message
    }
}

function Read-RequiredFile([string] $path, [string] $label) {
    $resolved = Resolve-ProjectPath $path
    Assert-True (Test-Path -LiteralPath $resolved) "$label not found: $resolved"
    $content = Get-Content -Raw -LiteralPath $resolved
    Assert-True (-not $content.Contains("`t")) "Tabs are not allowed in $label."
    return $content
}

function Assert-Contains([string] $content, [string] $expected, [string] $label) {
    Assert-True $content.Contains($expected) "$label does not contain expected text: $expected"
}

$matrix = Read-RequiredFile $MatrixPath "IAM/RBAC matrix"
Assert-Contains $matrix "# OSMU IAM/RBAC Matrix" "IAM/RBAC matrix"
Assert-Contains $matrix 'Role Definition' "IAM/RBAC matrix"
Assert-Contains $matrix 'Admin API Matrix' "IAM/RBAC matrix"
Assert-Contains $matrix 'Dashboard Panel Matrix' "IAM/RBAC matrix"
Assert-Contains $matrix 'accessMode' "IAM/RBAC matrix"
Assert-Contains $matrix 'allowedRoles' "IAM/RBAC matrix"
Assert-Contains $matrix 'Kubernetes And Operations Matrix' "IAM/RBAC matrix"
Assert-Contains $matrix '`ADMIN`' "IAM/RBAC matrix"
Assert-Contains $matrix '`ORG_ADMIN`' "IAM/RBAC matrix"
Assert-Contains $matrix '`USER`' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET /api/admin/users' "IAM/RBAC matrix"
Assert-Contains $matrix 'PATCH /api/admin/users/{userId}/status' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET /api/admin/organizations/usage' "IAM/RBAC matrix"
Assert-Contains $matrix '/api/admin/storage-expansion/**' "IAM/RBAC matrix"
Assert-Contains $matrix 'POST /api/admin/backup/restore-drill-evidence' "IAM/RBAC matrix"
Assert-Contains $matrix 'requests`, `sharing`, `quota`, `identity`, `lifecycle`, `retention`, `execution-retention`, `storage-expansion`' "IAM/RBAC matrix"
Assert-Contains $matrix 'AdminRbacPolicyTest' "IAM/RBAC matrix"
Assert-Contains $matrix 'DashboardLayoutControllerTest' "IAM/RBAC matrix"

$securityDesign = Read-RequiredFile $SecurityDesignPath "Security design"
Assert-Contains $securityDesign "AdminRbacPolicy" "Security design"
Assert-Contains $securityDesign "Dashboard widget catalog/layout/preset" "Security design"

$apiSpec = Read-RequiredFile $ApiSpecPath "API spec"
Assert-Contains $apiSpec '관리자 API인 `/api/admin/**`는 기본적으로 `ADMIN` role이 필요하다.' "API spec"
Assert-Contains $apiSpec 'adminOnly=true' "API spec"
Assert-Contains $apiSpec 'allowedRoles' "API spec"
Assert-Contains $apiSpec 'accessMode' "API spec"

$frontendDesign = Read-RequiredFile $FrontendDesignPath "Frontend design"
Assert-Contains $frontendDesign 'adminOnly' "Frontend design"
Assert-Contains $frontendDesign 'dashboard palette catalog와 저장 layout은 role 기준으로 필터링한다.' "Frontend design"

$adminRbacPolicy = Read-RequiredFile $AdminRbacPolicyPath "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/users")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("POST", "/api/admin/users")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.pattern("PATCH", "^/api/admin/users/\\d+/status$")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/organizations")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/organizations/usage")' "Admin RBAC policy"

$dashboardLayoutService = Read-RequiredFile $DashboardLayoutServicePath "Dashboard layout service"
Assert-Contains $dashboardLayoutService 'isWidgetAllowedForUser' "Dashboard layout service"
Assert-Contains $dashboardLayoutService 'Dashboard widget is admin-only.' "Dashboard layout service"
Assert-Contains $dashboardLayoutService '!item.adminOnly() || user.isAdmin()' "Dashboard layout service"
Assert-Contains $dashboardLayoutService 'List.of("ADMIN", "ORG_ADMIN", "USER")' "Dashboard layout service"
Assert-Contains $dashboardLayoutService '"read-only"' "Dashboard layout service"

$homeView = Read-RequiredFile $HomeViewPath "HomeView"
Assert-Contains $homeView 'dashboardWidgetCatalogForCurrentRole' "HomeView"
Assert-Contains $homeView '!widget.adminOnly || isAdmin.value' "HomeView"
Assert-Contains $homeView 'dashboardWidgetCatalogForRole.value.some((widget) => widget.id === dashboardWidgetToAdd.value)' "HomeView"
Assert-Contains $homeView 'dashboardWidgetAccessLabel' "HomeView"
Assert-Contains $homeView 'dashboardWidgetAllowedRoles' "HomeView"

Write-Host "IAM/RBAC matrix verified."
Write-Host "Matrix: $(Resolve-ProjectPath $MatrixPath)"
