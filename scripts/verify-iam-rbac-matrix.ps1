param(
    [string] $MatrixPath = ".\dev-docs\iam-rbac-matrix.md",
    [string] $SecurityDesignPath = ".\dev-docs\security-design.md",
    [string] $ApiSpecPath = ".\dev-docs\api-spec.md",
    [string] $FrontendDesignPath = ".\dev-docs\frontend-design.md",
    [string] $AdminRbacPolicyPath = ".\osmu-backend\src\main\java\com\example\osmu\auth\AdminRbacPolicy.java",
    [string] $EnterpriseAuthPlanServicePath = ".\osmu-backend\src\main\java\com\example\osmu\auth\EnterpriseAuthPlanService.java",
    [string] $ChargebackPreviewServicePath = ".\osmu-backend\src\main\java\com\example\osmu\billing\ChargebackPreviewService.java",
    [string] $OidcAuthorizationServicePath = ".\osmu-backend\src\main\java\com\example\osmu\auth\OidcAuthorizationService.java",
    [string] $OidcClaimPreviewServicePath = ".\osmu-backend\src\main\java\com\example\osmu\auth\OidcClaimPreviewService.java",
    [string] $OidcJitProvisioningServicePath = ".\osmu-backend\src\main\java\com\example\osmu\auth\OidcJitProvisioningService.java",
    [string] $OidcLoginServicePath = ".\osmu-backend\src\main\java\com\example\osmu\auth\OidcLoginService.java",
    [string] $OidcIdTokenVerifierPath = ".\osmu-backend\src\main\java\com\example\osmu\auth\OidcIdTokenVerifier.java",
    [string] $LdapLoginServicePath = ".\osmu-backend\src\main\java\com\example\osmu\auth\LdapLoginService.java",
    [string] $DashboardLayoutServicePath = ".\osmu-backend\src\main\java\com\example\osmu\dashboard\DashboardLayoutService.java",
    [string] $HomeViewPath = ".\osmu-frontend\src\views\HomeView.vue",
    [string] $AdminPagePath = ".\osmu-frontend\src\components\admin\AdminPage.vue",
    [string] $BillingChargebackPanelPath = ".\osmu-frontend\src\components\admin\BillingChargebackPanel.vue"
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
Assert-Contains $matrix '`AUDITOR`' "IAM/RBAC matrix"
Assert-Contains $matrix '`USER`' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET /api/admin/users' "IAM/RBAC matrix"
Assert-Contains $matrix 'PATCH /api/admin/users/{userId}/status' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET /api/admin/organizations/usage' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET /api/admin/billing/pricing-policy' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET /api/admin/billing/chargeback-preview' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET /api/admin/billing/chargeback-alerts' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET /api/admin/billing/chargeback-preview/export.csv' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET /api/admin/billing/chargeback-invoice-draft/export.csv' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET/POST /api/admin/teams' "IAM/RBAC matrix"
Assert-Contains $matrix '`TEAM` subject' "IAM/RBAC matrix"
Assert-Contains $matrix 'GET /api/admin/security/enterprise-auth-plan' "IAM/RBAC matrix"
Assert-Contains $matrix 'POST /api/admin/security/enterprise-auth/claim-preview' "IAM/RBAC matrix"
Assert-Contains $matrix 'POST /api/admin/security/enterprise-auth/jit-provision' "IAM/RBAC matrix"
Assert-Contains $matrix 'AdminEnterpriseAuthPlanControllerTest' "IAM/RBAC matrix"
Assert-Contains $matrix 'AdminBillingControllerTest' "IAM/RBAC matrix"
Assert-Contains $matrix 'ChargebackPreviewServiceTest' "IAM/RBAC matrix"
Assert-Contains $matrix 'OidcClaimPreviewServiceTest' "IAM/RBAC matrix"
Assert-Contains $matrix 'OidcJitProvisioningServiceTest' "IAM/RBAC matrix"
Assert-Contains $matrix 'OidcLoginServiceTest' "IAM/RBAC matrix"
Assert-Contains $matrix 'LdapLoginServiceTest' "IAM/RBAC matrix"
Assert-Contains $matrix '/api/admin/storage-expansion/**' "IAM/RBAC matrix"
Assert-Contains $matrix 'POST /api/admin/backup/restore-drill-evidence' "IAM/RBAC matrix"
Assert-Contains $matrix 'Audit read-only' "IAM/RBAC matrix"
Assert-Contains $matrix '`requests`' "IAM/RBAC matrix"
Assert-Contains $matrix 'Admin operations' "IAM/RBAC matrix"
Assert-Contains $matrix 'AdminRbacPolicyTest' "IAM/RBAC matrix"
Assert-Contains $matrix 'DashboardLayoutControllerTest' "IAM/RBAC matrix"

$securityDesign = Read-RequiredFile $SecurityDesignPath "Security design"
Assert-Contains $securityDesign "AdminRbacPolicy" "Security design"
Assert-Contains $securityDesign "EnterpriseAuthPlanService" "Security design"
Assert-Contains $securityDesign "osmu_roles" "Security design"
Assert-Contains $securityDesign "Dashboard widget catalog/layout/preset" "Security design"
Assert-Contains $securityDesign "ChargebackPreviewService" "Security design"

$apiSpec = Read-RequiredFile $ApiSpecPath "API spec"
Assert-Contains $apiSpec '관리자 API인 `/api/admin/**`는 기본적으로 `ADMIN` role이 필요하다.' "API spec"
Assert-Contains $apiSpec '`AUDITOR`는 read-only 감사/상태 조회 role이다.' "API spec"
Assert-Contains $apiSpec 'adminOnly=true' "API spec"
Assert-Contains $apiSpec 'allowedRoles' "API spec"
Assert-Contains $apiSpec 'accessMode' "API spec"
Assert-Contains $apiSpec 'GET /api/admin/teams' "API spec"
Assert-Contains $apiSpec 'GET /api/admin/security/enterprise-auth-plan' "API spec"
Assert-Contains $apiSpec 'POST /api/admin/security/enterprise-auth/claim-preview' "API spec"
Assert-Contains $apiSpec 'POST /api/admin/security/enterprise-auth/jit-provision' "API spec"
Assert-Contains $apiSpec 'GET /api/auth/oidc/authorize' "API spec"
Assert-Contains $apiSpec 'GET /api/auth/oidc/callback' "API spec"
Assert-Contains $apiSpec 'POST /api/auth/ldap/login' "API spec"
Assert-Contains $apiSpec 'GET /api/admin/billing/pricing-policy' "API spec"
Assert-Contains $apiSpec 'PUT /api/admin/billing/pricing-policy' "API spec"
Assert-Contains $apiSpec 'GET /api/admin/billing/chargeback-preview' "API spec"
Assert-Contains $apiSpec 'GET /api/admin/billing/chargeback-alerts' "API spec"
Assert-Contains $apiSpec 'GET /api/admin/billing/chargeback-preview/export.csv' "API spec"
Assert-Contains $apiSpec 'GET /api/admin/billing/chargeback-invoice-draft/export.csv' "API spec"
Assert-Contains $apiSpec 'OSMU_ENTERPRISE_AUTH_OIDC_ISSUER_URI' "API spec"
Assert-Contains $apiSpec 'OSMU_ENTERPRISE_AUTH_OIDC_AUTHORIZATION_ENABLED' "API spec"
Assert-Contains $apiSpec 'OSMU_ENTERPRISE_AUTH_OIDC_CALLBACK_ENABLED' "API spec"
Assert-Contains $apiSpec 'OSMU_ENTERPRISE_AUTH_OIDC_JWKS_URI' "API spec"
Assert-Contains $apiSpec 'OSMU_ENTERPRISE_AUTH_JIT_PROVISIONING_ENABLED' "API spec"
Assert-Contains $apiSpec 'OSMU_ENTERPRISE_AUTH_LDAP_LOGIN_ENABLED' "API spec"
Assert-Contains $apiSpec '`subjectType`은 `USER`, `ORGANIZATION`, `TEAM`을 지원한다.' "API spec"

$frontendDesign = Read-RequiredFile $FrontendDesignPath "Frontend design"
Assert-Contains $frontendDesign 'getEnterpriseAuthPlan' "Frontend design"
Assert-Contains $frontendDesign 'completeOidcCallback' "Frontend design"
Assert-Contains $frontendDesign 'loginWithLdap' "Frontend design"
Assert-Contains $frontendDesign 'getBillingPricingPolicy' "Frontend design"
Assert-Contains $frontendDesign 'getChargebackPreview' "Frontend design"
Assert-Contains $frontendDesign 'getChargebackAlerts' "Frontend design"
Assert-Contains $frontendDesign 'downloadChargebackPreviewCsv' "Frontend design"
Assert-Contains $frontendDesign 'downloadChargebackInvoiceDraftCsv' "Frontend design"
Assert-Contains $frontendDesign 'BillingChargebackPanel' "Frontend design"
Assert-Contains $frontendDesign 'previewEnterpriseAuthClaims' "Frontend design"
Assert-Contains $frontendDesign 'provisionEnterpriseAuthUser' "Frontend design"
Assert-Contains $frontendDesign 'adminOnly' "Frontend design"
Assert-Contains $frontendDesign 'dashboard palette catalog와 저장 layout은 role 기준으로 필터링한다.' "Frontend design"

$adminRbacPolicy = Read-RequiredFile $AdminRbacPolicyPath "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/users")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("POST", "/api/admin/users")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.pattern("PATCH", "^/api/admin/users/\\d+/status$")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/organizations")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/organizations/usage")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/billing/pricing-policy")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/billing/chargeback-preview")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/billing/chargeback-alerts")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/billing/chargeback-preview/export.csv")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/billing/chargeback-invoice-draft/export.csv")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/teams")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.pattern("PUT", "^/api/admin/teams/\\d+/members$")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'AUDITOR_ALLOWED_ROUTES' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/audit-logs")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/security/enterprise-auth-plan")' "Admin RBAC policy"
Assert-Contains $adminRbacPolicy 'RouteRule.exact("GET", "/api/admin/dashboard/summary")' "Admin RBAC policy"

$enterpriseAuthPlanService = Read-RequiredFile $EnterpriseAuthPlanServicePath "Enterprise auth plan service"
Assert-Contains $enterpriseAuthPlanService 'List.of("OIDC", "LDAP")' "Enterprise auth plan service"
Assert-Contains $enterpriseAuthPlanService 'osmu_roles' "Enterprise auth plan service"
Assert-Contains $enterpriseAuthPlanService 'osmu_org' "Enterprise auth plan service"
Assert-Contains $enterpriseAuthPlanService 'osmu_teams' "Enterprise auth plan service"
Assert-Contains $enterpriseAuthPlanService 'oidc-authorization-request' "Enterprise auth plan service"
Assert-Contains $enterpriseAuthPlanService 'oidc-callback-validation' "Enterprise auth plan service"
Assert-Contains $enterpriseAuthPlanService 'ldap-bind-search' "Enterprise auth plan service"

$oidcAuthorizationService = Read-RequiredFile $OidcAuthorizationServicePath "OIDC authorization service"
Assert-Contains $oidcAuthorizationService 'code_challenge_method' "OIDC authorization service"
Assert-Contains $oidcAuthorizationService '"S256"' "OIDC authorization service"
Assert-Contains $oidcAuthorizationService 'states.put(state' "OIDC authorization service"
Assert-Contains $oidcAuthorizationService 'consumeState' "OIDC authorization service"

$oidcClaimPreviewService = Read-RequiredFile $OidcClaimPreviewServicePath "OIDC claim preview service"
Assert-Contains $oidcClaimPreviewService 'MATCHED_EXISTING_USER' "OIDC claim preview service"
Assert-Contains $oidcClaimPreviewService 'REQUIRES_ADMIN_APPROVAL' "OIDC claim preview service"
Assert-Contains $oidcClaimPreviewService 'allowedDomainMatched' "OIDC claim preview service"

$oidcJitProvisioningService = Read-RequiredFile $OidcJitProvisioningServicePath "OIDC JIT provisioning service"
Assert-Contains $oidcJitProvisioningService 'approvePrivilegedRole' "OIDC JIT provisioning service"
Assert-Contains $oidcJitProvisioningService 'OIDC email domain is not allowed.' "OIDC JIT provisioning service"
Assert-Contains $oidcJitProvisioningService 'Organization is required for ORG_ADMIN provisioning.' "OIDC JIT provisioning service"
Assert-Contains $oidcJitProvisioningService 'randomPassword' "OIDC JIT provisioning service"

$oidcLoginService = Read-RequiredFile $OidcLoginServicePath "OIDC login service"
Assert-Contains $oidcLoginService 'exchangeAuthorizationCode' "OIDC login service"
Assert-Contains $oidcLoginService 'findByEmail' "OIDC login service"
Assert-Contains $oidcLoginService 'ACTIVE' "OIDC login service"

$oidcIdTokenVerifier = Read-RequiredFile $OidcIdTokenVerifierPath "OIDC id token verifier"
Assert-Contains $oidcIdTokenVerifier '"RS256"' "OIDC id token verifier"
Assert-Contains $oidcIdTokenVerifier 'SHA256withRSA' "OIDC id token verifier"
Assert-Contains $oidcIdTokenVerifier 'audienceContains' "OIDC id token verifier"

$ldapLoginService = Read-RequiredFile $LdapLoginServicePath "LDAP login service"
Assert-Contains $ldapLoginService 'osmu.enterprise-auth.ldap.login-enabled' "LDAP login service"
Assert-Contains $ldapLoginService 'LdapSearchRequest' "LDAP login service"
Assert-Contains $ldapLoginService 'LdapBindRequest' "LDAP login service"
Assert-Contains $ldapLoginService 'LDAP user is not provisioned.' "LDAP login service"

$chargebackPreviewService = Read-RequiredFile $ChargebackPreviewServicePath "Chargeback preview service"
Assert-Contains $chargebackPreviewService 'visibleOrganizations' "Chargeback preview service"
Assert-Contains $chargebackPreviewService 'actor.isOrgAdmin()' "Chargeback preview service"
Assert-Contains $chargebackPreviewService 'Chargeback preview access denied.' "Chargeback preview service"
Assert-Contains $chargebackPreviewService 'eventScanLimit' "Chargeback preview service"
Assert-Contains $chargebackPreviewService 'exportInvoiceDraftCsv' "Chargeback preview service"
Assert-Contains $chargebackPreviewService 'OSMU-DRAFT-' "Chargeback preview service"

$dashboardLayoutService = Read-RequiredFile $DashboardLayoutServicePath "Dashboard layout service"
Assert-Contains $dashboardLayoutService 'isWidgetAllowedForUser' "Dashboard layout service"
Assert-Contains $dashboardLayoutService 'Dashboard widget is not allowed for this role.' "Dashboard layout service"
Assert-Contains $dashboardLayoutService 'item.allowedRoles().contains(normalizeRole(user.role()))' "Dashboard layout service"
Assert-Contains $dashboardLayoutService 'List.of("ADMIN", "ORG_ADMIN", "AUDITOR", "USER")' "Dashboard layout service"
Assert-Contains $dashboardLayoutService 'List.of("ADMIN", "AUDITOR")' "Dashboard layout service"
Assert-Contains $dashboardLayoutService '"read-only"' "Dashboard layout service"

$homeView = Read-RequiredFile $HomeViewPath "HomeView"
Assert-Contains $homeView 'dashboardWidgetCatalogForCurrentRole' "HomeView"
Assert-Contains $homeView 'dashboardWidgetAllowedRoles(widget).includes(role)' "HomeView"
Assert-Contains $homeView "roles: ['ADMIN', 'AUDITOR']" "HomeView"
Assert-Contains $homeView 'dashboardWidgetCatalogForRole.value.some((widget) => widget.id === dashboardWidgetToAdd.value)' "HomeView"
Assert-Contains $homeView 'dashboardWidgetAccessLabel' "HomeView"
Assert-Contains $homeView 'dashboardWidgetAllowedRoles' "HomeView"
Assert-Contains $homeView 'getTeams' "HomeView"
Assert-Contains $homeView 'createTeam' "HomeView"
Assert-Contains $homeView 'deleteTeam' "HomeView"
Assert-Contains $homeView 'getEnterpriseAuthPlan' "HomeView"
Assert-Contains $homeView 'enterpriseAuthPlan' "HomeView"
Assert-Contains $homeView 'getBillingPricingPolicy' "HomeView"
Assert-Contains $homeView 'saveBillingPricingPolicy' "HomeView"
Assert-Contains $homeView 'getChargebackPreview' "HomeView"
Assert-Contains $homeView 'getChargebackAlerts' "HomeView"
Assert-Contains $homeView 'downloadChargebackPreviewCsv' "HomeView"
Assert-Contains $homeView 'downloadChargebackInvoiceDraftCsv' "HomeView"
Assert-Contains $homeView 'loadChargebackPreview' "HomeView"
Assert-Contains $homeView 'loadChargebackAlerts' "HomeView"

$adminPage = Read-RequiredFile $AdminPagePath "AdminPage"
Assert-Contains $adminPage 'BillingChargebackPanel' "AdminPage"
Assert-Contains $adminPage 'Enterprise auth plan' "AdminPage"
Assert-Contains $adminPage 'enterpriseAuthStatus' "AdminPage"
Assert-Contains $adminPage 'osmu_roles' "AdminPage"

$billingChargebackPanel = Read-RequiredFile $BillingChargebackPanelPath "Billing chargeback panel"
Assert-Contains $billingChargebackPanel 'billing-chargeback-panel' "Billing chargeback panel"
Assert-Contains $billingChargebackPanel 'chargeback-organization-table' "Billing chargeback panel"
Assert-Contains $billingChargebackPanel 'chargeback-export-button' "Billing chargeback panel"
Assert-Contains $billingChargebackPanel 'chargeback-invoice-draft-export-button' "Billing chargeback panel"
Assert-Contains $billingChargebackPanel 'chargeback-alert-list' "Billing chargeback panel"

Write-Host "IAM/RBAC matrix verified."
Write-Host "Matrix: $(Resolve-ProjectPath $MatrixPath)"
