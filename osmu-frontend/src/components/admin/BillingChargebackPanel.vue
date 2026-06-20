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
        data-testid="chargeback-payment-provider-input"
        :value="chargebackOptions.paymentProvider"
        placeholder="payment provider"
        @input="updateOption('paymentProvider', $event.target.value)"
      />
      <input
        data-testid="chargeback-payment-target-input"
        :value="chargebackOptions.paymentTargetAccount"
        placeholder="payment target"
        @input="updateOption('paymentTargetAccount', $event.target.value)"
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
        v-if="isAdmin"
        data-testid="chargeback-invoice-draft-save-button"
        type="button"
        class="ghost"
        @click="$emit('create-chargeback-invoice-drafts')"
      >
        Save draft
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
      <button
        v-if="isAdmin"
        data-testid="billing-pricing-policy-proposal-button"
        type="button"
        class="ghost"
        @click="$emit('create-billing-pricing-policy-proposal')"
      >
        Propose policy
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

    <div v-if="isAdmin" class="compact-metrics billing-pricing-policy-proposal-metrics" data-testid="billing-pricing-policy-proposal-metrics">
      <div>
        <span>Policy proposals</span>
        <b data-testid="billing-pricing-policy-proposal-count">{{ formatCount(pricingPolicyProposals.proposalCount) }}</b>
      </div>
      <div>
        <span>Status</span>
        <b data-testid="billing-pricing-policy-proposal-status">{{ pricingPolicyProposalRows[0]?.status || '-' }}</b>
      </div>
      <div>
        <span>Updated</span>
        <b data-testid="billing-pricing-policy-proposal-updated">{{ formatDateTime(pricingPolicyProposals.generatedAt) || '-' }}</b>
      </div>
    </div>

    <ul v-if="isAdmin" class="compact-list billing-pricing-policy-proposal-list" data-testid="billing-pricing-policy-proposal-list">
      <li v-for="proposal in pricingPolicyProposalRows" :key="proposal.id" data-testid="billing-pricing-policy-proposal-row">
        <span class="list-main">
          <b>{{ proposal.currency }} policy #{{ proposal.id }}</b>
          <small>
            storage {{ formatRate(proposal.storageGbMonthRate) }} / ingress {{ formatRate(proposal.ingressGbRate) }} / ops {{ formatRate(proposal.operationThousandRate) }} / warn {{ formatMoney(proposal.warningAmount, proposal.currency) }} / critical {{ formatMoney(proposal.criticalAmount, proposal.currency) }}
          </small>
          <small>{{ proposal.approvedPriceList ? 'Approved price list' : 'Internal calculation only' }} / {{ proposal.reason || '-' }}</small>
        </span>
        <button
          v-if="proposal.status === 'PENDING_APPROVAL'"
          data-testid="billing-pricing-policy-proposal-approve-button"
          type="button"
          class="ghost"
          @click="$emit('approve-billing-pricing-policy-proposal', proposal.id)"
        >
          Approve
        </button>
        <strong v-else :class="['status-pill', proposal.status === 'APPROVED_APPLIED' ? 'up' : 'mock']">{{ proposal.status || '-' }}</strong>
      </li>
      <li v-if="pricingPolicyProposalRows.length === 0" class="empty">No billing pricing policy proposals.</li>
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
          <small>{{ adapterAttemptSummary(delivery) }}</small>
        </span>
        <button
          v-if="isAdmin && canBlockAdapter(delivery.status)"
          data-testid="chargeback-notification-adapter-block-button"
          type="button"
          class="ghost"
          @click="$emit('record-chargeback-notification-adapter-result', { deliveryId: delivery.id, result: 'BLOCKED_CREDENTIAL' })"
        >
          Block
        </button>
        <button
          v-else-if="isAdmin && canRetryAdapter(delivery.status)"
          data-testid="chargeback-notification-adapter-retry-button"
          type="button"
          class="ghost"
          @click="$emit('record-chargeback-notification-adapter-result', { deliveryId: delivery.id, result: 'RETRY' })"
        >
          Retry
        </button>
        <strong v-else :class="['status-pill', adapterSucceeded(delivery.status) ? 'up' : 'mock']">{{ delivery.status }}</strong>
      </li>
      <li v-if="notificationOutboxRows.length === 0" class="empty">No chargeback notification outbox records.</li>
    </ul>

    <div v-if="isAdmin" class="compact-metrics chargeback-invoice-draft-metrics" data-testid="chargeback-invoice-draft-metrics">
      <div>
        <span>Draft records</span>
        <b data-testid="chargeback-invoice-draft-count">{{ formatCount(invoiceDrafts.invoiceCount) }}</b>
      </div>
      <div>
        <span>Status</span>
        <b data-testid="chargeback-invoice-draft-status">{{ invoiceDraftRows[0]?.status || '-' }}</b>
      </div>
      <div>
        <span>Updated</span>
        <b data-testid="chargeback-invoice-draft-updated">{{ formatDateTime(invoiceDrafts.generatedAt) || '-' }}</b>
      </div>
    </div>

    <ul v-if="isAdmin" class="compact-list chargeback-invoice-draft-list" data-testid="chargeback-invoice-draft-list">
      <li v-for="invoice in invoiceDraftRows" :key="invoice.id" data-testid="chargeback-invoice-draft-row">
        <span class="list-main">
          <b>{{ invoice.invoiceNumber }}</b>
          <small>{{ invoice.organizationName }} / {{ formatMoney(invoice.estimatedTotalCost, invoice.currency) }} / {{ invoice.reason || '-' }}</small>
        </span>
        <button
          v-if="invoice.status === 'DRAFT_REVIEW'"
          data-testid="chargeback-invoice-draft-approve-button"
          type="button"
          class="ghost"
          @click="$emit('approve-chargeback-invoice-draft', invoice.id)"
        >
          Approve
        </button>
        <button
          v-else-if="invoice.status === 'APPROVED_INTERNAL'"
          data-testid="chargeback-invoice-draft-finalize-button"
          type="button"
          class="ghost"
          @click="$emit('finalize-chargeback-invoice-draft', invoice.id)"
        >
          Finalize
        </button>
        <strong v-else>{{ invoice.status }}</strong>
      </li>
      <li v-if="invoiceDraftRows.length === 0" class="empty">No chargeback invoice draft records.</li>
    </ul>

    <div v-if="isAdmin" class="compact-metrics chargeback-final-invoice-metrics" data-testid="chargeback-final-invoice-metrics">
      <div>
        <span>Final invoices</span>
        <b data-testid="chargeback-final-invoice-count">{{ formatCount(finalInvoices.invoiceCount) }}</b>
      </div>
      <div>
        <span>Status</span>
        <b data-testid="chargeback-final-invoice-status">{{ finalInvoiceRows[0]?.status || '-' }}</b>
      </div>
      <div>
        <span>Payment</span>
        <b data-testid="chargeback-final-invoice-payment-status">{{ finalInvoiceRows[0]?.paymentStatus || '-' }}</b>
      </div>
    </div>

    <ul v-if="isAdmin" class="compact-list chargeback-final-invoice-list" data-testid="chargeback-final-invoice-list">
      <li v-for="invoice in finalInvoiceRows" :key="invoice.id" data-testid="chargeback-final-invoice-row">
        <span class="list-main">
          <b>{{ invoice.invoiceNumber }}</b>
          <small>{{ invoice.organizationName }} / {{ formatMoney(invoice.estimatedTotalCost, invoice.currency) }} / {{ invoice.paymentStatus || '-' }}</small>
          <small>{{ invoice.paymentReference || invoice.finalizationNote || '-' }}</small>
        </span>
        <button
          v-if="invoice.status === 'FINALIZED'"
          data-testid="chargeback-final-invoice-payment-request-button"
          type="button"
          class="ghost"
          @click="$emit('request-chargeback-invoice-payment', invoice.id)"
        >
          Request payment
        </button>
        <button
          v-if="invoice.status === 'PAYMENT_REQUESTED'"
          data-testid="chargeback-payment-handoff-button"
          type="button"
          class="ghost"
          @click="$emit('queue-chargeback-payment-provider-handoff', invoice.id)"
        >
          Queue handoff
        </button>
        <button
          v-if="invoice.status === 'PAYMENT_REQUESTED'"
          data-testid="chargeback-final-invoice-payment-record-button"
          type="button"
          class="ghost"
          @click="$emit('record-chargeback-invoice-payment', invoice.id)"
        >
          Record paid
        </button>
        <strong v-if="invoice.status !== 'FINALIZED' && invoice.status !== 'PAYMENT_REQUESTED'" :class="['status-pill', invoice.status === 'PAID' ? 'up' : 'mock']">{{ invoice.status || '-' }}</strong>
      </li>
      <li v-if="finalInvoiceRows.length === 0" class="empty">No chargeback final invoice records.</li>
    </ul>

    <div v-if="isAdmin" class="compact-metrics chargeback-payment-handoff-metrics" data-testid="chargeback-payment-handoff-metrics">
      <div>
        <span>Payment handoffs</span>
        <b data-testid="chargeback-payment-handoff-count">{{ formatCount(paymentHandoffs.handoffCount) }}</b>
      </div>
      <div>
        <span>Status</span>
        <b data-testid="chargeback-payment-handoff-status">{{ paymentHandoffRows[0]?.status || '-' }}</b>
      </div>
      <div>
        <span>Provider</span>
        <b data-testid="chargeback-payment-handoff-provider">{{ paymentHandoffRows[0]?.provider || chargebackOptions.paymentProvider || '-' }}</b>
      </div>
    </div>

    <ul v-if="isAdmin" class="compact-list chargeback-payment-handoff-list" data-testid="chargeback-payment-handoff-list">
      <li v-for="handoff in paymentHandoffRows" :key="handoff.id" data-testid="chargeback-payment-handoff-row">
        <span class="list-main">
          <b>{{ handoff.invoiceNumber }}</b>
          <small>{{ handoff.organizationName }} / {{ formatMoney(handoff.amount, handoff.currency) }} / {{ handoff.provider }} -> {{ handoff.targetAccount }}</small>
          <small>{{ adapterAttemptSummary(handoff) }}</small>
        </span>
        <button
          v-if="canBlockAdapter(handoff.status)"
          data-testid="chargeback-payment-handoff-adapter-block-button"
          type="button"
          class="ghost"
          @click="$emit('record-chargeback-payment-provider-adapter-result', { handoffId: handoff.id, result: 'BLOCKED_CREDENTIAL' })"
        >
          Block
        </button>
        <button
          v-else-if="canRetryAdapter(handoff.status)"
          data-testid="chargeback-payment-handoff-adapter-retry-button"
          type="button"
          class="ghost"
          @click="$emit('record-chargeback-payment-provider-adapter-result', { handoffId: handoff.id, result: 'RETRY' })"
        >
          Retry
        </button>
        <strong v-else :class="['status-pill', adapterSucceeded(handoff.status) ? 'up' : 'mock']">{{ handoff.status || '-' }}</strong>
      </li>
      <li v-if="paymentHandoffRows.length === 0" class="empty">No chargeback payment provider handoffs.</li>
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
  chargebackInvoiceDrafts: { type: Object, required: true },
  chargebackFinalInvoices: { type: Object, required: true },
  chargebackPaymentProviderHandoffs: { type: Object, required: true },
  billingPricingPolicy: { type: Object, required: true },
  billingPricingPolicyProposals: { type: Object, required: true },
  formatBytes: { type: Function, required: true },
  formatDateTime: { type: Function, required: true },
})

const emit = defineEmits([
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
  'queue-chargeback-payment-provider-handoff',
  'record-chargeback-notification-adapter-result',
  'record-chargeback-payment-provider-adapter-result',
  'record-chargeback-invoice-payment',
])

const preview = computed(() => props.chargebackPreview || {})
const alerts = computed(() => props.chargebackAlerts || {})
const notificationPreview = computed(() => props.chargebackAlertNotificationPreview || {})
const notificationOutbox = computed(() => props.chargebackAlertNotificationOutbox || {})
const invoiceDrafts = computed(() => props.chargebackInvoiceDrafts || {})
const finalInvoices = computed(() => props.chargebackFinalInvoices || {})
const paymentHandoffs = computed(() => props.chargebackPaymentProviderHandoffs || {})
const pricingPolicyProposals = computed(() => props.billingPricingPolicyProposals || {})
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
const invoiceDraftRows = computed(() => (
  Array.isArray(invoiceDrafts.value.invoices) ? invoiceDrafts.value.invoices : []
))
const finalInvoiceRows = computed(() => (
  Array.isArray(finalInvoices.value.invoices) ? finalInvoices.value.invoices : []
))
const paymentHandoffRows = computed(() => (
  Array.isArray(paymentHandoffs.value.handoffs) ? paymentHandoffs.value.handoffs : []
))
const pricingPolicyProposalRows = computed(() => (
  Array.isArray(pricingPolicyProposals.value.proposals) ? pricingPolicyProposals.value.proposals : []
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

function adapterSucceeded(status = '') {
  return String(status || '').endsWith('_SUCCEEDED')
}

function canRetryAdapter(status = '') {
  return String(status || '').includes('_BLOCKED_CREDENTIAL')
}

function canBlockAdapter(status = '') {
  const normalized = String(status || '')
  return normalized && !adapterSucceeded(normalized) && !canRetryAdapter(normalized)
}

function adapterAttemptSummary(record = {}) {
  const attempts = formatCount(record.attemptCount)
  const next = formatDateTime(record.nextAttemptAt)
  const error = record.lastError || record.reason || '-'
  return `attempts ${attempts} / next ${next || '-'} / ${error}`
}
</script>
