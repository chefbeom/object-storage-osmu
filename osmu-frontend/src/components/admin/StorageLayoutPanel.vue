<template>
  <article class="panel storage-layout-panel" data-testid="storage-layout-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Storage Layout</p>
        <h3>PVC layout plans</h3>
      </div>
      <span class="bucket-label">{{ storageLayoutPlans.length }}{{ storageLayoutNextCursor ? '+' : '' }} plans</span>
    </div>

    <form class="inline-form" @submit.prevent="$emit('create-storage-layout-plan')">
      <select
        data-testid="storage-layout-code-select"
        aria-label="Storage layout"
        :value="storageLayoutForm.layoutCode"
        @change="$emit('update-storage-layout-form', { field: 'layoutCode', value: $event.target.value })"
      >
        <option v-for="layout in storageLayoutCatalog" :key="layout.code" :value="layout.code">
          {{ layout.name }}
        </option>
      </select>
      <input
        data-testid="storage-layout-storage-class-input"
        aria-label="StorageClass"
        :value="storageLayoutForm.storageClassName"
        placeholder="StorageClass"
        @input="$emit('update-storage-layout-form', { field: 'storageClassName', value: $event.target.value })"
      />
      <input
        data-testid="storage-layout-server-count-input"
        aria-label="Servers"
        type="number"
        min="1"
        :value="storageLayoutForm.serverCount"
        @input="$emit('update-storage-layout-form', { field: 'serverCount', value: $event.target.value })"
      />
      <input
        data-testid="storage-layout-volumes-per-server-input"
        aria-label="Volumes per server"
        type="number"
        min="1"
        :value="storageLayoutForm.volumesPerServer"
        @input="$emit('update-storage-layout-form', { field: 'volumesPerServer', value: $event.target.value })"
      />
      <input
        data-testid="storage-layout-volume-size-input"
        aria-label="PVC size GiB"
        type="number"
        min="10"
        :value="storageLayoutForm.volumeSizeGiB"
        @input="$emit('update-storage-layout-form', { field: 'volumeSizeGiB', value: $event.target.value })"
      />
      <input
        data-testid="storage-layout-reason-input"
        aria-label="Reason"
        :value="storageLayoutForm.reason"
        placeholder="Reason"
        @input="$emit('update-storage-layout-form', { field: 'reason', value: $event.target.value })"
      />
      <button data-testid="storage-layout-create-button" type="submit" :disabled="!isAdmin">Create plan</button>
    </form>

    <ul class="compact-list storage-layout-catalog" data-testid="storage-layout-catalog">
      <li v-for="layout in storageLayoutCatalog" :key="layout.code">
        <span class="list-main">
          <b>{{ layout.name }}</b>
          <small>{{ layout.description }}</small>
        </span>
        <span class="list-main layout-meta">
          <small>{{ layout.minimumPvcCount }}+ PVC</small>
          <small>{{ layout.faultTolerance }}</small>
        </span>
        <strong class="status-pill">{{ layout.riskLevel }}</strong>
      </li>
    </ul>

    <form class="inline-form" @submit.prevent>
      <select
        data-testid="storage-layout-status-filter"
        aria-label="Storage layout plan status"
        :value="storageLayoutStatusFilter"
        :disabled="storageLayoutPlansLoading"
        @change="$emit('update-storage-layout-status-filter', $event.target.value)"
      >
        <option value="OPEN">Open</option>
        <option value="ALL">All</option>
        <option value="PLANNED">Planned</option>
        <option value="APPROVED">Approved</option>
        <option value="REJECTED">Rejected</option>
      </select>
      <button
        v-if="storageLayoutNextCursor"
        data-testid="storage-layout-load-more-button"
        type="button"
        class="ghost"
        :disabled="storageLayoutPlansLoading"
        @click="$emit('load-more-storage-layout-plans')"
      >
        {{ storageLayoutPlansLoading ? 'Loading...' : 'Load more' }}
      </button>
    </form>

    <ul class="compact-list storage-layout-plan-list" data-testid="storage-layout-plan-list">
      <li v-for="plan in storageLayoutPlans" :key="plan.id">
        <span class="list-main">
          <b>{{ plan.poolName }} / {{ plan.layout?.name }}</b>
          <small>{{ plan.storageClassName }} / {{ plan.serverCount }} servers x {{ plan.volumesPerServer }} volumes / {{ plan.pvcCount }} PVC</small>
          <small>usable estimate {{ formatBytes(plan.estimatedUsableCapacityBytes) }} / raw {{ formatBytes(plan.estimatedRawCapacityBytes) }}</small>
          <small>{{ plan.preflight?.result }} · simulation only</small>
        </span>
        <strong class="status-pill">{{ plan.status }}</strong>
        <span class="key-actions">
          <button
            v-if="plan.status === 'PLANNED'"
            data-testid="storage-layout-approve-button"
            type="button"
            class="ghost"
            :disabled="!plan.simulatedAt"
            :title="plan.simulatedAt ? 'Approve layout plan' : 'Run simulation before approval'"
            @click="$emit('update-storage-layout-plan-status', { plan, status: 'APPROVED' })"
          >
            Approve
          </button>
          <button
            v-if="plan.status === 'PLANNED'"
            data-testid="storage-layout-reject-button"
            type="button"
            class="danger"
            @click="$emit('update-storage-layout-plan-status', { plan, status: 'REJECTED' })"
          >
            Reject
          </button>
          <button
            v-if="plan.status !== 'REJECTED'"
            data-testid="storage-layout-simulate-button"
            type="button"
            class="ghost"
            @click="$emit('simulate-storage-layout-plan', plan)"
          >
            Simulate
          </button>
        </span>
      </li>
      <li v-if="storageLayoutPlans.length === 0" class="empty">No layout plans</li>
    </ul>

    <section v-if="storageLayoutSimulation" class="storage-layout-simulation" data-testid="storage-layout-simulation">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Simulation</p>
          <h4>{{ storageLayoutSimulation.plan?.poolName }}</h4>
        </div>
        <span class="status-pill">{{ storageLayoutSimulation.mode }}</span>
      </div>
      <small>{{ storageLayoutSimulation.message }}</small>
      <ul class="compact-list">
        <li v-for="check in storageLayoutSimulation.plan?.preflight?.checks || []" :key="check.code">
          <span class="list-main">
            <b>{{ check.code }}</b>
            <small>{{ check.detail }}</small>
          </span>
          <strong class="status-pill">{{ check.result }}</strong>
        </li>
      </ul>
      <pre data-testid="storage-layout-manifest-preview"><code>{{ storageLayoutSimulation.manifestPreview }}</code></pre>
    </section>
  </article>
</template>

<script setup>
defineProps({
  isAdmin: { type: Boolean, required: true },
  storageLayoutCatalog: { type: Array, required: true },
  storageLayoutForm: { type: Object, required: true },
  storageLayoutPlans: { type: Array, required: true },
  storageLayoutStatusFilter: { type: String, required: true },
  storageLayoutNextCursor: { type: String, default: '' },
  storageLayoutPlansLoading: { type: Boolean, required: true },
  storageLayoutSimulation: { type: Object, default: null },
  formatBytes: { type: Function, required: true },
})

defineEmits([
  'update-storage-layout-form',
  'create-storage-layout-plan',
  'update-storage-layout-status-filter',
  'load-more-storage-layout-plans',
  'update-storage-layout-plan-status',
  'simulate-storage-layout-plan',
])
</script>

<style scoped>
.storage-layout-catalog,
.storage-layout-plan-list {
  margin-top: 0.75rem;
}

.layout-meta {
  min-width: 8rem;
}

.storage-layout-simulation {
  margin-top: 0.75rem;
  border-top: 1px solid var(--border, #d7dde5);
  padding-top: 0.75rem;
}

pre {
  max-height: 18rem;
  overflow: auto;
  white-space: pre-wrap;
}
</style>