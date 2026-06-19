<template>
  <section id="admin-workbench" class="management-grid lower">
    <AccessKeyPanel
      id="admin-access-keys"
      :access-key-form="accessKeyForm"
      :buckets="buckets"
      :is-logged-in="isLoggedIn"
      :new-secret-key="newSecretKey"
      :access-keys="accessKeys"
      :format-key-scope="formatKeyScope"
      @create-access-key="$emit('create-access-key')"
      @add-access-key-scope="$emit('add-access-key-scope')"
      @remove-access-key-scope="$emit('remove-access-key-scope', $event)"
      @rotate-access-key="$emit('rotate-access-key', $event)"
      @delete-access-key="$emit('delete-access-key', $event)"
      @bulk-disable-access-keys="$emit('bulk-disable-access-keys', $event)"
    />

    <article v-if="isLoggedIn && !selectedBucket" class="panel empty-state-panel" data-testid="admin-bucket-empty-state">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Bucket Context</p>
          <h3>버킷 선택 필요</h3>
        </div>
      </div>
      <div class="empty-state-body">
        <strong>버킷 권한, lifecycle XML, tag 설정은 선택된 버킷 기준으로 동작합니다.</strong>
        <small>Storage 페이지에서 버킷을 선택한 뒤 Admin 페이지로 돌아오세요.</small>
      </div>
    </article>

    <article v-if="!isAdmin" class="panel empty-state-panel" data-testid="admin-role-empty-state">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Admin Controls</p>
          <h3>관리자 기능 제한</h3>
        </div>
      </div>
      <div class="empty-state-body">
        <strong>{{ isLoggedIn ? '일부 정책/쿼터/감사 기능은 ADMIN 권한이 필요합니다.' : '로그인 후 사용 가능한 관리 기능이 표시됩니다.' }}</strong>
        <small>일반 사용자는 S3 Access Key와 허용된 버킷 작업만 사용할 수 있습니다.</small>
        <ul class="compact-list role-scope-list" data-testid="admin-role-restricted-panel-list">
          <li>Share policy / analytics</li>
          <li>Quota, lifecycle, retention</li>
          <li>Storage expansion and runner controls</li>
        </ul>
      </div>
    </article>

    <article v-if="isAdmin" class="panel approval-workflow-panel" data-testid="admin-approval-workflow-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Approval Workflow</p>
          <h3>운영 승인 큐</h3>
        </div>
        <span class="bucket-label">{{ approvalWorkflowCounts.total }} actions</span>
      </div>
      <div class="compact-metrics approval-workflow-metrics" data-testid="admin-approval-workflow-metrics">
        <div>
          <span>Profiles</span>
          <b>{{ approvalWorkflowCounts.profilePending }}</b>
        </div>
        <div>
          <span>Expansion planned</span>
          <b>{{ approvalWorkflowCounts.expansionPlanned }}</b>
        </div>
        <div>
          <span>Expansion approved</span>
          <b>{{ approvalWorkflowCounts.expansionApproved }}</b>
        </div>
      </div>
      <ul class="compact-list approval-workflow-list" data-testid="admin-approval-workflow-list">
        <li v-for="item in approvalWorkflowItems" :key="item.key">
          <span class="list-main">
            <b data-testid="admin-approval-workflow-item-title">{{ item.title }}</b>
            <small>{{ item.detail }}</small>
            <small>{{ item.nextStep }}</small>
          </span>
          <strong :class="['status-pill', statusClass(item.status)]">{{ item.status }}</strong>
          <span v-if="item.type === 'storage-profile'" class="key-actions">
            <button
              v-if="item.status === 'PENDING'"
              data-testid="admin-approval-profile-approve-button"
              type="button"
              class="ghost"
              @click="$emit('update-storage-profile-request-status', { request: item.source, status: 'APPROVED' })"
            >
              Approve
            </button>
            <button
              v-if="item.status === 'PENDING'"
              data-testid="admin-approval-profile-reject-button"
              type="button"
              class="danger"
              @click="$emit('update-storage-profile-request-status', { request: item.source, status: 'REJECTED' })"
            >
              Reject
            </button>
            <button
              v-if="item.status === 'APPROVED'"
              data-testid="admin-approval-profile-apply-button"
              type="button"
              @click="$emit('apply-storage-profile-request', item.source)"
            >
              Apply
            </button>
          </span>
          <span v-if="item.type === 'storage-expansion'" class="key-actions">
            <button
              v-if="item.status === 'PLANNED'"
              data-testid="admin-approval-expansion-approve-button"
              type="button"
              class="ghost"
              @click="$emit('update-storage-expansion-status', { request: item.source, status: 'APPROVED' })"
            >
              Approve
            </button>
            <button
              v-if="item.status === 'APPROVED'"
              data-testid="admin-approval-expansion-plan-button"
              type="button"
              class="ghost"
              @click="$emit('create-storage-expansion-execution-plan', item.source)"
            >
              Dry Run
            </button>
            <button
              v-if="item.status === 'APPROVED'"
              data-testid="admin-approval-expansion-apply-button"
              type="button"
              :disabled="!storageExpansionApplyEvidence.trim()"
              @click="$emit('update-storage-expansion-status', { request: item.source, status: 'APPLIED', appliedEvidence: storageExpansionApplyEvidence })"
            >
              Apply
            </button>
            <button
              data-testid="admin-approval-expansion-reject-button"
              type="button"
              class="danger"
              @click="$emit('update-storage-expansion-status', { request: item.source, status: 'REJECTED' })"
            >
              Reject
            </button>
          </span>
        </li>
        <li v-if="approvalWorkflowItems.length === 0" class="empty">승인 대기 항목 없음</li>
      </ul>
    </article>

    <article v-if="isAdmin" class="panel security-audit-policy-panel" data-testid="admin-security-audit-policy-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Security & Audit</p>
          <h3>감사/보안 정책</h3>
        </div>
        <RouterLink data-testid="admin-security-audit-open-audit-link" class="ghost" to="/audit">Audit</RouterLink>
      </div>
      <div class="compact-metrics security-policy-metrics" data-testid="admin-security-policy-metrics">
        <div>
          <span>Key review</span>
          <b>{{ securityPolicyMetrics.accessKeyReviewCount }}</b>
        </div>
        <div>
          <span>Share controls</span>
          <b>{{ securityPolicyMetrics.shareControlCount }}/2</b>
        </div>
        <div>
          <span>Audit failures</span>
          <b>{{ securityPolicyMetrics.auditFailureCount }}</b>
        </div>
      </div>
      <ul class="compact-list security-policy-list" data-testid="admin-security-policy-list">
        <li v-for="row in securityPolicyRows" :key="row.key" data-testid="admin-security-policy-row">
          <span class="list-main">
            <b data-testid="admin-security-policy-row-title">{{ row.title }}</b>
            <small>{{ row.detail }}</small>
            <small>{{ row.evidence }}</small>
          </span>
          <strong :class="['status-pill', statusClass(row.status)]" data-testid="admin-security-policy-row-status">
            {{ row.status }}
          </strong>
        </li>
      </ul>
    </article>

    <BucketPermissionsPanel
      id="admin-bucket-permissions"
      :is-logged-in="isLoggedIn"
      :selected-bucket="selectedBucket"
      :can-show-bucket-permissions="canShowBucketPermissions"
      :bucket-permission-form="bucketPermissionForm"
      :users="users"
      :organizations="organizations"
      :teams="teams"
      :bucket-permissions="bucketPermissions"
      @grant-bucket-permissions="$emit('grant-bucket-permissions')"
      @revoke-bucket-permission="$emit('revoke-bucket-permission', $event)"
    />

    <BucketMetadataPanel
      id="admin-bucket-metadata"
      :is-logged-in="isLoggedIn"
      :selected-bucket="selectedBucket"
      :can-use-bucket-lifecycle="canUseBucketLifecycle"
      :bucket-lifecycle-xml="bucketLifecycleXml"
      :can-use-bucket-tags="canUseBucketTags"
      :bucket-tags="bucketTags"
      @load-bucket-lifecycle-xml="$emit('load-bucket-lifecycle-xml')"
      @put-bucket-lifecycle-xml="$emit('put-bucket-lifecycle-xml')"
      @delete-bucket-lifecycle-xml="$emit('delete-bucket-lifecycle-xml')"
      @load-bucket-tags="$emit('load-bucket-tags')"
      @put-bucket-tags="$emit('put-bucket-tags')"
      @delete-bucket-tags="$emit('delete-bucket-tags')"
    />

    <ObjectSharePanel
      v-if="isAdmin"
      id="admin-object-share"
      :is-admin="isAdmin"
      :object-share-policy-form="objectSharePolicyForm"
      :object-share-analytics="objectShareAnalytics"
      :object-share-analytics-filter="objectShareAnalyticsFilter"
      :format-date-time="formatDateTime"
      @save-object-share-policy="$emit('save-object-share-policy')"
      @refresh-object-share-analytics="$emit('refresh-object-share-analytics')"
    />

    <QuotaPolicyPanel
      v-if="isAdmin"
      id="admin-quota-policies"
      :is-admin="isAdmin"
      :quota-policy-form="quotaPolicyForm"
      :quota-policy-target-options="quotaPolicyTargetOptions"
      :quota-policies="quotaPolicies"
      :quota-policy-history="quotaPolicyHistory"
      :format-bytes="formatBytes"
      @save-quota-policy="$emit('save-quota-policy')"
      @reset-quota-policy-target="$emit('reset-quota-policy-target')"
      @reset-quota-policy-form="$emit('reset-quota-policy-form')"
      @edit-quota-policy="$emit('edit-quota-policy', $event)"
      @delete-quota-policy="$emit('delete-quota-policy', $event)"
    />

    <BillingChargebackPanel
      v-if="canUseAdminTools"
      id="admin-billing-chargeback"
      :can-use-admin-tools="canUseAdminTools"
      :is-admin="isAdmin"
      :chargeback-options="chargebackOptions"
      :chargeback-preview="chargebackPreview"
      :chargeback-alerts="chargebackAlerts"
      :chargeback-alert-notification-preview="chargebackAlertNotificationPreview"
      :chargeback-alert-notification-outbox="chargebackAlertNotificationOutbox"
      :chargeback-invoice-drafts="chargebackInvoiceDrafts"
      :chargeback-final-invoices="chargebackFinalInvoices"
      :billing-pricing-policy="billingPricingPolicy"
      :billing-pricing-policy-proposals="billingPricingPolicyProposals"
      :format-bytes="formatBytes"
      :format-date-time="formatDateTime"
      @update-chargeback-option="$emit('update-chargeback-option', $event)"
      @refresh-chargeback-preview="$emit('refresh-chargeback-preview')"
      @reset-chargeback-options="$emit('reset-chargeback-options')"
      @save-billing-pricing-policy="$emit('save-billing-pricing-policy')"
      @create-billing-pricing-policy-proposal="$emit('create-billing-pricing-policy-proposal')"
      @approve-billing-pricing-policy-proposal="$emit('approve-billing-pricing-policy-proposal', $event)"
      @queue-chargeback-alert-notifications="$emit('queue-chargeback-alert-notifications')"
      @export-chargeback-csv="$emit('export-chargeback-csv')"
      @export-chargeback-invoice-draft-csv="$emit('export-chargeback-invoice-draft-csv')"
      @create-chargeback-invoice-drafts="$emit('create-chargeback-invoice-drafts')"
      @approve-chargeback-invoice-draft="$emit('approve-chargeback-invoice-draft', $event)"
      @finalize-chargeback-invoice-draft="$emit('finalize-chargeback-invoice-draft', $event)"
      @request-chargeback-invoice-payment="$emit('request-chargeback-invoice-payment', $event)"
      @record-chargeback-invoice-payment="$emit('record-chargeback-invoice-payment', $event)"
    />

    <article v-if="isAdmin" id="admin-storage-profiles" class="panel" data-testid="admin-storage-profile-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Storage Profiles</p>
          <h3>Profile approval queue</h3>
        </div>
        <span class="bucket-label">{{ storageProfileRequests.length }} requests</span>
      </div>

      <form class="inline-form" @submit.prevent>
        <input
          data-testid="storage-profile-admin-note-input"
          :value="storageProfileAdminNote"
          placeholder="Admin note"
          @input="$emit('update-storage-profile-admin-note', $event.target.value)"
        />
      </form>

      <div class="table-wrap">
        <table data-testid="admin-storage-profile-request-table">
          <thead>
            <tr>
              <th>Bucket</th>
              <th>Current</th>
              <th>Requested</th>
              <th>Status</th>
              <th>Actor</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="request in storageProfileRequests" :key="request.id">
              <td>
                <strong>{{ request.bucketName }}</strong>
                <small>{{ request.reason || '-' }}</small>
              </td>
              <td>{{ request.currentProfile?.name || request.currentProfile?.code }}</td>
              <td>
                <strong>{{ request.requestedProfile?.name || request.requestedProfile?.code }}</strong>
                <small>{{ request.requestedProfile?.alias }} / {{ request.requestedProfile?.riskLevel }}</small>
              </td>
              <td><strong :class="['status-pill', statusClass(request.status)]">{{ request.status }}</strong></td>
              <td>{{ request.requestedBy }}</td>
              <td class="actions">
                <button type="button" class="ghost" :disabled="request.status !== 'PENDING'" @click="$emit('update-storage-profile-request-status', { request, status: 'APPROVED' })">
                  Approve
                </button>
                <button type="button" class="danger" :disabled="request.status !== 'PENDING'" @click="$emit('update-storage-profile-request-status', { request, status: 'REJECTED' })">
                  Reject
                </button>
                <button type="button" :disabled="request.status !== 'APPROVED'" @click="$emit('apply-storage-profile-request', request)">
                  Apply
                </button>
              </td>
            </tr>
            <tr v-if="storageProfileRequests.length === 0">
              <td colspan="6" class="empty">No storage profile requests.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </article>

    <StorageExpansionPanel
      v-if="isAdmin"
      id="admin-storage-expansion"
      :is-admin="isAdmin"
      :storage-expansion-form="storageExpansionForm"
      :storage-expansion-requests="storageExpansionRequests"
      :storage-expansion-manifest="storageExpansionManifest"
      :storage-expansion-execution-plan="storageExpansionExecutionPlan"
      :storage-expansion-git-ops-plan="storageExpansionGitOpsPlan"
      :storage-expansion-executions="storageExpansionExecutions"
      :storage-expansion-execution-form="storageExpansionExecutionForm"
      :storage-expansion-apply-evidence="storageExpansionApplyEvidence"
      :storage-expansion-runner-preflight="storageExpansionRunnerPreflight"
      :format-bytes="formatBytes"
      :format-date-time="formatDateTime"
      @create-storage-expansion-request="$emit('create-storage-expansion-request')"
      @preview-storage-expansion-manifest="$emit('preview-storage-expansion-manifest', $event)"
      @download-storage-expansion-manifest="$emit('download-storage-expansion-manifest', $event)"
      @download-storage-expansion-gitops-bundle="$emit('download-storage-expansion-gitops-bundle')"
      @create-storage-expansion-execution-plan="$emit('create-storage-expansion-execution-plan', $event)"
      @record-storage-expansion-dry-run-execution="$emit('record-storage-expansion-dry-run-execution')"
      @run-storage-expansion-dry-run-execution="$emit('run-storage-expansion-dry-run-execution')"
      @run-storage-expansion-apply-execution="$emit('run-storage-expansion-apply-execution')"
      @run-storage-expansion-rollback-execution="$emit('run-storage-expansion-rollback-execution')"
      @create-storage-expansion-gitops-plan="$emit('create-storage-expansion-gitops-plan', $event)"
      @run-storage-expansion-gitops-pr-execution="$emit('run-storage-expansion-gitops-pr-execution')"
      @record-storage-expansion-gitops-pr-execution="$emit('record-storage-expansion-gitops-pr-execution')"
      @load-storage-expansion-executions="$emit('load-storage-expansion-executions', $event)"
      @create-storage-expansion-execution-record="$emit('create-storage-expansion-execution-record')"
      @apply-storage-expansion-from-execution="$emit('apply-storage-expansion-from-execution', $event)"
      @update-storage-expansion-apply-evidence="$emit('update-storage-expansion-apply-evidence', $event)"
      @refresh-storage-expansion-runner-preflight="$emit('refresh-storage-expansion-runner-preflight')"
      @update-storage-expansion-status="$emit('update-storage-expansion-status', $event)"
    />

    <LifecycleRulesPanel
      v-if="isAdmin"
      id="admin-lifecycle-rules"
      :is-admin="isAdmin"
      :lifecycle-rule-form="lifecycleRuleForm"
      :lifecycle-rules="lifecycleRules"
      :lifecycle-rule-preview="lifecycleRulePreview"
      :lifecycle-rule-conflicts="lifecycleRuleConflicts"
      :lifecycle-xml="lifecycleXml"
      :format-bytes="formatBytes"
      @reset-lifecycle-rule-form="$emit('reset-lifecycle-rule-form')"
      @save-object-lifecycle-rule="$emit('save-object-lifecycle-rule')"
      @dry-run-object-lifecycle-rule="$emit('dry-run-object-lifecycle-rule', $event)"
      @edit-lifecycle-rule="$emit('edit-lifecycle-rule', $event)"
      @delete-object-lifecycle-rule="$emit('delete-object-lifecycle-rule', $event)"
      @refresh-lifecycle-rule-conflicts="$emit('refresh-lifecycle-rule-conflicts')"
      @export-lifecycle-xml="$emit('export-lifecycle-xml')"
      @import-lifecycle-xml="$emit('import-lifecycle-xml')"
    />

    <IdentityAdminPanel
      v-if="canUseAdminTools"
      id="admin-identity"
      :can-use-admin-tools="canUseAdminTools"
      :organization-form="organizationForm"
      :organization-usages="organizationUsages"
      :team-form="teamForm"
      :teams="teams"
      :user-form="userForm"
      :users="users"
      :organizations="organizations"
      :is-logged-in="isLoggedIn"
      :is-admin="isAdmin"
      :session="session"
      :format-bytes="formatBytes"
      @create-organization="$emit('create-organization')"
      @create-team="$emit('create-team')"
      @delete-team="$emit('delete-team', $event)"
      @create-user="$emit('create-user')"
      @toggle-user-status="$emit('toggle-user-status', $event)"
    />
  </section>
</template>

<script setup>
import { computed } from 'vue'
import AccessKeyPanel from './AccessKeyPanel.vue'
import BillingChargebackPanel from './BillingChargebackPanel.vue'
import BucketMetadataPanel from './BucketMetadataPanel.vue'
import BucketPermissionsPanel from './BucketPermissionsPanel.vue'
import IdentityAdminPanel from './IdentityAdminPanel.vue'
import LifecycleRulesPanel from './LifecycleRulesPanel.vue'
import ObjectSharePanel from './ObjectSharePanel.vue'
import QuotaPolicyPanel from './QuotaPolicyPanel.vue'
import StorageExpansionPanel from './StorageExpansionPanel.vue'

const props = defineProps({
  accessKeyForm: { type: Object, required: true },
  buckets: { type: Array, required: true },
  isLoggedIn: { type: Boolean, required: true },
  newSecretKey: { type: String, required: true },
  accessKeys: { type: Array, required: true },
  auditLogs: { type: Array, required: true },
  selectedBucket: { type: String, required: true },
  canShowBucketPermissions: { type: Boolean, required: true },
  bucketPermissionForm: { type: Object, required: true },
  users: { type: Array, required: true },
  organizations: { type: Array, required: true },
  teams: { type: Array, required: true },
  bucketPermissions: { type: Array, required: true },
  canUseBucketLifecycle: { type: Boolean, required: true },
  bucketLifecycleXml: { type: Object, required: true },
  canUseBucketTags: { type: Boolean, required: true },
  bucketTags: { type: Object, required: true },
  isAdmin: { type: Boolean, required: true },
  objectSharePolicyForm: { type: Object, required: true },
  objectShareAnalytics: { type: Object, required: true },
  objectShareAnalyticsFilter: { type: Object, required: true },
  enterpriseAuthPlan: { type: Object, required: true },
  chargebackOptions: { type: Object, required: true },
  chargebackPreview: { type: Object, required: true },
  chargebackAlerts: { type: Object, required: true },
  chargebackAlertNotificationPreview: { type: Object, required: true },
  chargebackAlertNotificationOutbox: { type: Object, required: true },
  chargebackInvoiceDrafts: { type: Object, required: true },
  chargebackFinalInvoices: { type: Object, required: true },
  billingPricingPolicy: { type: Object, required: true },
  billingPricingPolicyProposals: { type: Object, required: true },
  quotaPolicyForm: { type: Object, required: true },
  quotaPolicyTargetOptions: { type: Array, required: true },
  quotaPolicies: { type: Array, required: true },
  quotaPolicyHistory: { type: Array, required: true },
  storageExpansionForm: { type: Object, required: true },
  storageExpansionRequests: { type: Array, required: true },
  storageExpansionManifest: { type: Object, default: null },
  storageExpansionExecutionPlan: { type: Object, default: null },
  storageExpansionGitOpsPlan: { type: Object, default: null },
  storageExpansionExecutions: { type: Array, required: true },
  storageExpansionExecutionForm: { type: Object, required: true },
  storageExpansionApplyEvidence: { type: String, required: true },
  storageExpansionRunnerPreflight: { type: Object, required: true },
  storageProfileRequests: { type: Array, required: true },
  storageProfileAdminNote: { type: String, required: true },
  lifecycleRuleForm: { type: Object, required: true },
  lifecycleRules: { type: Array, required: true },
  lifecycleRulePreview: { type: Object, required: true },
  lifecycleRuleConflicts: { type: Object, required: true },
  lifecycleXml: { type: Object, required: true },
  canUseAdminTools: { type: Boolean, required: true },
  organizationForm: { type: Object, required: true },
  organizationUsages: { type: Array, required: true },
  teamForm: { type: Object, required: true },
  userForm: { type: Object, required: true },
  session: { type: Object, required: true },
  formatKeyScope: { type: Function, required: true },
  formatDateTime: { type: Function, required: true },
  formatBytes: { type: Function, required: true },
  statusClass: { type: Function, required: true },
})

const approvalWorkflowProfileItems = computed(() => props.storageProfileRequests
  .filter((request) => ['PENDING', 'APPROVED'].includes(request.status))
  .map((request) => ({
    key: `storage-profile-${request.id}`,
    type: 'storage-profile',
    status: request.status,
    title: `Storage profile / ${request.bucketName}`,
    detail: `${request.currentProfile?.code || '-'} -> ${request.requestedProfile?.code || '-'}`,
    nextStep: request.status === 'PENDING' ? 'Approve or reject requested bucket profile.' : 'Apply approved profile to bucket.',
    source: request,
  })))

const approvalWorkflowExpansionItems = computed(() => props.storageExpansionRequests
  .filter((request) => ['PLANNED', 'APPROVED'].includes(request.status))
  .map((request) => ({
    key: `storage-expansion-${request.id}`,
    type: 'storage-expansion',
    status: request.status,
    title: `Storage expansion / ${request.poolName}`,
    detail: `usable ${props.formatBytes(request.estimatedUsableCapacityBytes)} / ${request.serverCount} servers x ${request.volumesPerServer} PV`,
    nextStep: request.status === 'PLANNED'
      ? 'Approve before manifest, dry-run, GitOps, or apply work.'
      : 'Run dry-run/GitOps and attach apply evidence before apply.',
    source: request,
  })))

const approvalWorkflowItems = computed(() => [
  ...approvalWorkflowProfileItems.value,
  ...approvalWorkflowExpansionItems.value,
])

const approvalWorkflowCounts = computed(() => {
  const profilePending = props.storageProfileRequests.filter((request) => request.status === 'PENDING').length
  const expansionPlanned = props.storageExpansionRequests.filter((request) => request.status === 'PLANNED').length
  const expansionApproved = props.storageExpansionRequests.filter((request) => request.status === 'APPROVED').length
  return {
    profilePending,
    expansionPlanned,
    expansionApproved,
    total: approvalWorkflowItems.value.length,
  }
})

const accessKeyReviewCount = computed(() => props.accessKeys.filter(accessKeyNeedsReview).length)
const shareControlCount = computed(() => Number(Boolean(props.objectSharePolicyForm.requirePassword))
  + Number(Boolean(props.objectSharePolicyForm.requireIpAllowlist)))
const auditFailureCount = computed(() => props.auditLogs.filter((entry) => String(entry.result || '').toUpperCase() !== 'SUCCESS').length)
const securityPolicyMetrics = computed(() => ({
  accessKeyReviewCount: accessKeyReviewCount.value,
  shareControlCount: shareControlCount.value,
  auditFailureCount: auditFailureCount.value,
}))
const securityPolicyRows = computed(() => [
  {
    key: 'access-keys',
    title: 'Access key hygiene',
    status: accessKeyReviewCount.value > 0 ? 'REVIEW' : 'SUCCESS',
    detail: `${activeAccessKeyCount()} active keys / ${accessKeyReviewCount.value} needing cleanup or rotation review`,
    evidence: 'Expires, last-used, rotation grace, usage count, and bulk cleanup preview are visible.',
  },
  {
    key: 'share-policy',
    title: 'Share link protection',
    status: shareControlCount.value === 2 ? 'SUCCESS' : 'REVIEW',
    detail: `password=${policyFlag(props.objectSharePolicyForm.requirePassword)} / ip=${policyFlag(props.objectSharePolicyForm.requireIpAllowlist)} / max expiry=${props.objectSharePolicyForm.maxExpiresSeconds || '-'}`,
    evidence: 'Object share policy and analytics panels enforce password, IP, expiry, and download limits.',
  },
  {
    key: 'quota-policy',
    title: 'Quota policy coverage',
    status: props.quotaPolicies.length > 0 ? 'SUCCESS' : 'REVIEW',
    detail: `${props.quotaPolicies.length} active policies / ${props.quotaPolicyHistory.length} policy history entries`,
    evidence: 'Quota policy panel keeps target search, edit/delete, and change history together.',
  },
  {
    key: 'lifecycle-conflicts',
    title: 'Lifecycle conflict review',
    status: Number(props.lifecycleRuleConflicts.conflictCount || 0) > 0 ? 'REVIEW' : 'SUCCESS',
    detail: `${props.lifecycleRuleConflicts.ruleCount || 0} enabled rules checked / ${props.lifecycleRuleConflicts.conflictCount || 0} overlaps`,
    evidence: 'Lifecycle conflict check is exposed before retention or lifecycle XML changes.',
  },
  {
    key: 'enterprise-auth',
    title: 'Enterprise auth plan',
    status: enterpriseAuthStatus(props.enterpriseAuthPlan),
    detail: enterpriseAuthDetail(props.enterpriseAuthPlan),
    evidence: enterpriseAuthEvidence(props.enterpriseAuthPlan),
  },
  {
    key: 'audit-trail',
    title: 'Audit trail',
    status: props.auditLogs.length === 0 ? 'MISSING' : (auditFailureCount.value > 0 ? 'REVIEW' : 'SUCCESS'),
    detail: `${props.auditLogs.length} recent audit events / ${auditFailureCount.value} non-success results`,
    evidence: 'Audit page supports event, actor, request id, target, result, time, pagination, and CSV export.',
  },
])

function accessKeyNeedsReview(key) {
  if (String(key.status || '').toUpperCase() !== 'ACTIVE') return false
  if (isPast(key.expiresAt)) return true
  return isStaleOrUnused(key.lastUsedAt)
}

function activeAccessKeyCount() {
  return props.accessKeys.filter((key) => String(key.status || '').toUpperCase() === 'ACTIVE').length
}

function isPast(value) {
  if (!value) return false
  return new Date(value).getTime() <= Date.now()
}

function isStaleOrUnused(value) {
  if (!value) return true
  const staleBefore = Date.now() - (30 * 24 * 60 * 60 * 1000)
  return new Date(value).getTime() < staleBefore
}

function policyFlag(value) {
  return value ? 'on' : 'off'
}

function enterpriseAuthStatus(plan) {
  const status = String(plan?.status || '').toUpperCase()
  if (status === 'ACTIVE') return 'SUCCESS'
  if (status === 'PLAN_READY' || status === 'LOCAL_ONLY') return 'REVIEW'
  return 'MISSING'
}

function enterpriseAuthDetail(plan) {
  const active = Array.isArray(plan?.activeLoginModes) && plan.activeLoginModes.length > 0
    ? plan.activeLoginModes.join(', ')
    : (plan?.currentLoginMode || 'LOCAL_PASSWORD')
  const planned = Array.isArray(plan?.plannedExternalModes) && plan.plannedExternalModes.length > 0
    ? plan.plannedExternalModes.join(', ')
    : 'OIDC, LDAP'
  const provider = plan?.externalProviderConfigured ? 'provider configured' : 'provider pending'
  return `${active} active / ${planned} planned / ${provider}`
}

function enterpriseAuthEvidence(plan) {
  const mapping = plan?.claimMapping || {}
  const reviewGates = Array.isArray(plan?.gates)
    ? plan.gates.filter((gate) => String(gate.status || '').toUpperCase() !== 'SUCCESS').length
    : 0
  return `Claims role=${mapping.roleClaim || 'osmu_roles'}, org=${mapping.organizationClaim || 'osmu_org'}, team=${mapping.teamClaim || 'osmu_teams'} / ${reviewGates} review gates`
}

defineEmits([
  'create-access-key',
  'add-access-key-scope',
  'remove-access-key-scope',
  'rotate-access-key',
  'delete-access-key',
  'bulk-disable-access-keys',
  'grant-bucket-permissions',
  'revoke-bucket-permission',
  'load-bucket-lifecycle-xml',
  'put-bucket-lifecycle-xml',
  'delete-bucket-lifecycle-xml',
  'load-bucket-tags',
  'put-bucket-tags',
  'delete-bucket-tags',
  'save-object-share-policy',
  'refresh-object-share-analytics',
  'update-chargeback-option',
  'refresh-chargeback-preview',
  'reset-chargeback-options',
  'save-billing-pricing-policy',
  'create-billing-pricing-policy-proposal',
  'approve-billing-pricing-policy-proposal',
  'queue-chargeback-alert-notifications',
  'export-chargeback-csv',
  'export-chargeback-invoice-draft-csv',
  'create-chargeback-invoice-drafts',
  'approve-chargeback-invoice-draft',
  'finalize-chargeback-invoice-draft',
  'request-chargeback-invoice-payment',
  'record-chargeback-invoice-payment',
  'save-quota-policy',
  'reset-quota-policy-target',
  'reset-quota-policy-form',
  'edit-quota-policy',
  'delete-quota-policy',
  'create-storage-expansion-request',
  'preview-storage-expansion-manifest',
  'download-storage-expansion-manifest',
  'download-storage-expansion-gitops-bundle',
  'create-storage-expansion-execution-plan',
  'record-storage-expansion-dry-run-execution',
  'run-storage-expansion-dry-run-execution',
  'run-storage-expansion-apply-execution',
  'run-storage-expansion-rollback-execution',
  'create-storage-expansion-gitops-plan',
  'run-storage-expansion-gitops-pr-execution',
  'record-storage-expansion-gitops-pr-execution',
  'load-storage-expansion-executions',
  'create-storage-expansion-execution-record',
  'apply-storage-expansion-from-execution',
  'update-storage-expansion-apply-evidence',
  'refresh-storage-expansion-runner-preflight',
  'update-storage-expansion-status',
  'update-storage-profile-admin-note',
  'update-storage-profile-request-status',
  'apply-storage-profile-request',
  'reset-lifecycle-rule-form',
  'save-object-lifecycle-rule',
  'dry-run-object-lifecycle-rule',
  'edit-lifecycle-rule',
  'delete-object-lifecycle-rule',
  'refresh-lifecycle-rule-conflicts',
  'export-lifecycle-xml',
  'import-lifecycle-xml',
  'create-organization',
  'create-team',
  'delete-team',
  'create-user',
  'toggle-user-status',
])
</script>
