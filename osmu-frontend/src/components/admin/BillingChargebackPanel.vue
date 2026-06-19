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
  chargebackOptions: { type: Object, required: true },
  chargebackPreview: { type: Object, required: true },
  formatBytes: { type: Function, required: true },
  formatDateTime: { type: Function, required: true },
})

const emit = defineEmits([
  'update-chargeback-option',
  'refresh-chargeback-preview',
  'reset-chargeback-options',
])

const preview = computed(() => props.chargebackPreview || {})
const rates = computed(() => preview.value.rates || {})
const organizations = computed(() => (
  Array.isArray(preview.value.organizations) ? preview.value.organizations : []
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

function formatMoney(value) {
  const amount = Number(value || 0)
  const currency = String(preview.value.currency || props.chargebackOptions.currency || 'USD').toUpperCase()
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
