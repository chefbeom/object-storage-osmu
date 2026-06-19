<template>
  <article v-if="canUseAdminTools" id="admin-billing-chargeback" class="panel billing-chargeback-panel" data-testid="billing-chargeback-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Billing</p>
        <h3>Chargeback Preview</h3>
      </div>
      <span class="bucket-label" data-testid="chargeback-scan-count">
        {{ formatCount(preview.scannedEventCount) }} events
      </span>
    </div>

    <form class="inline-form chargeback-form" data-testid="chargeback-filter-form" @submit.prevent="$emit('refresh-chargeback-preview')">
      <input
        data-testid="chargeback-filter-from"
        type="datetime-local"
        :value="chargebackOptions.from"
        @input="updateOption('from', $event.target.value)"
      />
      <input
        data-testid="chargeback-filter-to"
        type="datetime-local"
        :value="chargebackOptions.to"
        @input="updateOption('to', $event.target.value)"
      />
      <input
        data-testid="chargeback-currency-input"
        :value="chargebackOptions.currency"
        maxlength="12"
        placeholder="USD"
        @input="updateOption('currency', $event.target.value)"
      />
      <input
        data-testid="chargeback-storage-rate-input"
        min="0"
        step="0.000001"
        type="number"
        :value="chargebackOptions.storageGbMonthRate"
        placeholder="storage / GiB"
        @input="updateOption('storageGbMonthRate', $event.target.value)"
      />
      <input
        data-testid="chargeback-ingress-rate-input"
        min="0"
        step="0.000001"
        type="number"
        :value="chargebackOptions.ingressGbRate"
        placeholder="ingress / GiB"
        @input="updateOption('ingressGbRate', $event.target.value)"
      />
      <input
        data-testid="chargeback-egress-rate-input"
        min="0"
        step="0.000001"
        type="number"
        :value="chargebackOptions.egressGbRate"
        placeholder="egress / GiB"
        @input="updateOption('egressGbRate', $event.target.value)"
      />
      <input
        data-testid="chargeback-internal-rate-input"
        min="0"
        step="0.000001"
        type="number"
        :value="chargebackOptions.internalGbRate"
        placeholder="internal / GiB"
        @input="updateOption('internalGbRate', $event.target.value)"
      />
      <input
        data-testid="chargeback-operation-rate-input"
        min="0"
        step="0.000001"
        type="number"
        :value="chargebackOptions.operationThousandRate"
        placeholder="ops / 1K"
        @input="updateOption('operationThousandRate', $event.target.value)"
      />
      <input
        data-testid="chargeback-warning-threshold-input"
        min="0"
        step="0.000001"
        type="number"
        :value="chargebackOptions.warningAmount"
        placeholder="warning amount"
        @input="updateOption('warningAmount', $event.target.value)"
      />
      <input
        data-testid="chargeback-critical-threshold-input"
        min="0"
        step="0.000001"
        type="number"
        :value="chargebackOptions.criticalAmount"
        placeholder="critical amount"
        @input="updateOption('criticalAmount', $event.target.value)"
      />
      <input
        data-testid="chargeback-notification-channel-input"
        :value="chargebackOptions.notificationChannel"
        placeholder="notify channel"
        @input="updateOption('notificationChannel', $event.target.value)"
      />
      <input
        data-testid="chargeback-notification-target-input"
        :value="chargebackOptions.notificationTarget"
        placeholder="notify target"
        @input="updateOption('notificationTarget', $event.target.value)"
      />
      <input
        data-testid="chargeback-event-limit-input"
        min="1"
        max="50000"
        step="1"
        type="number"
        :value="chargebackOptions.eventScanLimit"
        placeholder="event limit"
        @input="updateOption('eventScanLimit', $event.target.value)"
      />
      <button data-testid="chargeback-refresh-button" type="submit">Refresh</button>
      <button data-testid="chargeback-reset-button" type="button" class="ghost" @click="$emit('reset-chargeback-options')">
        Reset
      </button>
      <button data-testid="chargeback-export-button" type="button" class="ghost" @click="$emit('export-chargeback-csv')">
        CSV
      </button>
      <button
        data-testid="chargeback-invoice-draft-export-button"
        type="button"
        class="ghost"
        @click="$emit('export-chargeback-invoice-draft-csv')"
      >
        Invoice draft
      </button>
      <button
        data-testid="chargeback-notification-queue-button"
        type="button"
        class="ghost"
        @click="$emit('queue-chargeback-alert-notifications')"
      >
        Queue notify
      </button>
      <button
        v-if="isAdmin"
        data-testid="chargeback-save-policy-button"
        type="button"
        class="ghost"
        @click="$emit('save-billing-pricing-policy')"
      >
        Save policy
      </button>
    </form>

    <div class="compact-metrics chargeback-metrics" data-testid="chargeback-metrics">
      <div>
        <span>Total preview</span>
        <b data-testid="chargeback-total-cost">{{ formatMoney(preview.estimatedTotalCost) }}</b>
      </div>
      <div>
        <span>Stored</span>
        <b data-testid="chargeback-total-used">{{ formatBytes(preview.usedBytes) }}</b>
      </div>
      <div>
        <span>Billable ops</span>
        <b data-testid="chargeback-total-operations">{{ formatCount(preview.billableOperationCount) }}</b>
      </div>
    </div>

    <ul class="compact-list chargeback-rate-list" data-testid="chargeback-rate-list">
      <li>
        <span class="list-main">
          <b>Traffic</b>
          <small>{{ formatBytes(preview.ingressBytes) }} in / {{ formatBytes(preview.egressBytes) }} out / {{ formatBytes(preview.internalBytes) }} internal</small>
        </span>
        <strong>{{ formatCount(preview.organizationCount) }} orgs</strong>
      </li>
      <li>
        <span class="list-main">
          <b>Rates</b>
          <small>storage {{ formatRate(rates.storageGbMonthRate) }} / ingress {{ formatRate(rates.ingressGbRate) }} / egress {{ formatRate(rates.egressGbRate) }} / internal {{ formatRate(rates.internalGbRate) }}</small>
        </span>
        <strong>{{ formatRate(rates.operationThousandRate) }} / 1K ops</strong>
      </li>
      <li>
        <span class="list-main">
          <b>Window</b>
          <small>{{ formatDateTime(preview.from) || '-' }} -> {{ formatDateTime(preview.to) || '-' }}</small>
        </span>
        <strong>{{ formatDateTime(preview.generatedAt) || '-' }}</strong>
      </li>
      <li>
        <span class="list-main">
          <b>Policy</b>
          <small>{{ formatDateTime(billingPricingPolicy.updatedAt) || '-' }} / warn {{ formatMoney(alerts.warningAmount, alerts.currency) }} / critical {{ formatMoney(alerts.criticalAmount, alerts.currency) }}</small>
        </span>
        <strong>{{ billingPricingPolicy.currency || preview.currency || chargebackOptions.currency }}</strong>
      </li>
    </ul>

    <div class="compact-metrics chargeback-alert-metrics" data-testid="chargeback-alert-metrics">
      <div>
        <span>Alerts</span>
        <b data-testid="chargeback-alert-count">{{ formatCount(alerts.alertCount) }}</b>
      </div>
      <div>
        <span>Warning</span>
        <b data-testid="chargeback-warning-count">{{ formatCount(alerts.warningCount) }}</b>
      </div>
      <div>
        <span>Critical</span>
        <b data-testid="chargeback-critical-count">{{ formatCount(alerts.criticalCount) }}</b>
      </div>
    </div>

    <ul class="compact-list chargeback-alert-list" data-testid="chargeback-alert-list">
      <li v-for="alert in alertOrganizations" :key="alert.organizationId" data-testid="chargeback-alert-row">
        <span class="list-main">
          <b>{{ alert.organizationName }}</b>
          <small>{{ formatMoney(alert.estimatedTotalCost, alerts.currency) }} / warn {{ formatMoney(alert.warningAmount, alerts.currency) }} / critical {{ formatMoney(alert.criticalAmount, alerts.currency) }}</small>
        </span>
        <strong :class="['status-pill', alert.severity === 'CRITICAL' ? 'down' : 'mock']">{{ alert.severity }}</strong>
      </li>
      <li v-if="alertOrganizations.length === 0" class="empty">No chargeback threshold alerts.</li>
    </ul>

    <div class="compact-metrics chargeback-notification-metrics" data-testid="chargeback-notification-metrics">
      <div>
        <span>Notify preview</span>
        <b data-testid="chargeback-notification-count">{{ formatCount(notificationPreview.notificationCount) }}</b>
      </div>
      <div>
        <span>Channel</span>
        <b data-testid="chargeback-notification-channel">{{ notificationPreview.channel || '-' }}</b>
      </div>
      <div>
        <span>Delivery</span>
        <b data-testid="chargeback-notification-mode">{{ notificationPreview.externalDeliveryEnabled ? 'Enabled' : 'Preview' }}</b>
      </div>
    </div>

    <ul class="compact-list chargeback-notification-list" data-testid="chargeback-notification-list">
      <li v-for="notification in notificationRows" :key="notification.organizationId" data-testid="chargeback-notification-row">
        <span class="list-main">
          <b>{{ notification.subject }}</b>
          <small>{{ notification.message }}</small>
        </span>
        <strong>{{ notification.payload?.target || notificationPreview.target || '-' }}</strong>
      </li>
      <li v-if="notificationRows.length === 0" class="empty">No chargeback notification payloads.</li>
    </ul>

    <div class="compact-metrics chargeback-notification-outbox-metrics" data-testid="chargeback-notification-outbox-metrics">
      <div>
        <span>Outbox</span>
        <b data-testid="chargeback-notification-outbox-count">{{ formatCount(notificationOutbox.deliveryCount) }}</b>
      </div>
      <div>
        <span>Status</span>
        <b data-testid="chargeback-notification-outbox-status">{{ notificationOutboxRows[0]?.status || '-' }}</b>
      </div>
      <div>
        <span>Updated</span>
        <b data-testid="chargeback-notification-outbox-updated">{{ formatDateTime(notificationOutbox.generatedAt) || '-' }}</b>
      </div>
    </div>

    <ul class="compact-list chargeback-notification-outbox-list" data-testid="chargeback-notification-outbox-list">
      <li v-for="delivery in notificationOutboxRows" :key="delivery.id" data-testid="chargeback-notification-outbox-row">
        <span class="list-main">
          <b>{{ delivery.organizationName }}</b>
          <small>{{ delivery.subject }} / {{ delivery.channel }} -> {{ delivery.target }}</small>
        </span>
        <strong>{{ delivery.status }}</strong>
      </li>
      <li v-if="notificationOutboxRows.length === 0" class="empty">No chargeback notification outbox records.</li>
    </ul>

    <div class="table-wrap chargeback-table-wrap">
      <table data-testid="chargeback-organization-table">
        <thead>
          <tr>
            <th>Organization</th>
            <th>Storage</th>
            <th>Traffic</th>
            <th>Ops</th>
            <th>Preview cost</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="organization in organizations" :key="organization.organizationId" data-testid="chargeback-organization-row">
            <td>
              <strong>{{ organization.organizationName }}</strong>
              <small>{{ formatCount(organization.bucketCount) }} buckets / {{ formatCount(organization.objectCount) }} objects</small>
            </td>
            <td>{{ formatBytes(organization.usedBytes) }}</td>
            <td>
              <span>{{ formatBytes(organization.ingressBytes) }} / {{ formatBytes(organization.egressBytes) }}</span>
              <small>{{ formatBytes(organization.internalBytes) }} internal</small>
            </td>
            <td>
              <span>{{ formatCount(organization.billableOperationCount) }}</span>
              <small>{{ formatCount(organization.failedOperationCount) }} failed / {{ formatCount(organization.cancelledOperationCount) }} cancelled</small>
            </td>
            <td>
              <strong>{{ formatMoney(organization.estimatedTotalCost) }}</strong>
              <small>{{ costBreakdown(organization) }}</small>
            </td>
          </tr>
          <tr v-if="organizations.length === 0">
            <td colspan="5" class="empty">No organization usage.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </article>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  canUseAdminTools: { type: Boolean, required: true },
  isAdmin: { type: Boolean, required: true },
  chargebackOptions: { type: Object, required: true },
  chargebackPreview: { type: Object, required: true },
  chargebackAlerts: { type: Object, required: true },
  chargebackAlertNotificationPreview: { type: Object, required: true },
  chargebackAlertNotificationOutbox: { type: Object, required: true },
  billingPricingPolicy: { type: Object, required: true },
  formatBytes: { type: Function, required: true },
  formatDateTime: { type: Function, required: true },
})

const emit = defineEmits([
  'update-chargeback-option',
  'refresh-chargeback-preview',
  'reset-chargeback-options',
  'save-billing-pricing-policy',
  'queue-chargeback-alert-notifications',
  'export-chargeback-csv',
  'export-chargeback-invoice-draft-csv',
])

const preview = computed(() => props.chargebackPreview || {})
const alerts = computed(() => props.chargebackAlerts || {})
const notificationPreview = computed(() => props.chargebackAlertNotificationPreview || {})
const notificationOutbox = computed(() => props.chargebackAlertNotificationOutbox || {})
const rates = computed(() => preview.value.rates || {})
const organizations = computed(() => (
  Array.isArray(preview.value.organizations) ? preview.value.organizations : []
))
const alertOrganizations = computed(() => (
  Array.isArray(alerts.value.organizations) ? alerts.value.organizations : []
))
const notificationRows = computed(() => (
  Array.isArray(notificationPreview.value.notifications) ? notificationPreview.value.notifications : []
))
const notificationOutboxRows = computed(() => (
  Array.isArray(notificationOutbox.value.deliveries) ? notificationOutbox.value.deliveries : []
))

function updateOption(field, value) {
  emit('update-chargeback-option', { field, value })
}

function formatCount(value) {
  return Number(value || 0).toLocaleString()
}

function formatRate(value) {
  const amount = Number(value || 0)
  return amount.toLocaleString(undefined, { maximumFractionDigits: 6 })
}

function formatMoney(value, currencyValue = '') {
  const amount = Number(value || 0)
  const currency = String(currencyValue || preview.value.currency || props.chargebackOptions.currency || 'USD').toUpperCase()
  return `${currency} ${amount.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 6 })}`
}

function costBreakdown(organization) {
  return [
    `storage ${formatMoney(organization.projectedStorageCost)}`,
    `traffic ${formatMoney(Number(organization.ingressCost || 0) + Number(organization.egressCost || 0) + Number(organization.internalCost || 0))}`,
    `ops ${formatMoney(organization.operationCost)}`,
  ].join(' / ')
}
</script>
