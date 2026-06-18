<template>
  <article class="panel" data-testid="dashboard-quota-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Quota Alerts</p>
        <h3>쿼터 정책 경보</h3>
      </div>
      <span :class="['status-pill', quota.exhaustedPolicyCount > 0 ? 'down' : quota.warningPolicyCount > 0 ? 'mock' : 'up']">
        {{ quota.warningPolicyCount + quota.exhaustedPolicyCount }} alerts
      </span>
    </div>
    <dl class="status-dl compact">
      <div>
        <dt>정책/경고</dt>
        <dd>{{ quota.policyCount }} / {{ quota.warningPolicyCount }}</dd>
      </div>
      <div>
        <dt>할당 사용량</dt>
        <dd>{{ formatBytes(quota.totalUsedBytes) }} / {{ formatBytes(quota.totalQuotaBytes) }}</dd>
      </div>
    </dl>
    <ul class="compact-list">
      <li v-if="quota.topPolicies.length === 0" class="empty">쿼터 정책이 없습니다.</li>
      <li v-for="policy in quota.topPolicies" :key="`${policy.targetType}-${policy.targetId}`">
        <span class="list-main">
          <b>{{ policy.targetType }} #{{ policy.targetId }}</b>
          <small>{{ formatBytes(policy.usedBytes) }} / {{ formatBytes(policy.quotaBytes) }}</small>
        </span>
        <span class="bucket-label">{{ quotaPolicyPercent(policy) }}%</span>
      </li>
    </ul>
  </article>
</template>

<script setup>
defineProps({
  quota: {
    type: Object,
    required: true,
  },
  formatBytes: {
    type: Function,
    required: true,
  },
  quotaPolicyPercent: {
    type: Function,
    required: true,
  },
})
</script>
