<template>
  <article v-if="isAdmin" class="panel" data-testid="object-share-policy-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Share Policy</p>
        <h3>공유 링크 정책</h3>
      </div>
    </div>
    <form class="policy-form" data-testid="object-share-policy-form" @submit.prevent="$emit('save-object-share-policy')">
      <label class="check">
        <input data-testid="object-share-policy-require-password" v-model="objectSharePolicyForm.requirePassword" type="checkbox" />
        비밀번호 필수
      </label>
      <label class="check">
        <input data-testid="object-share-policy-require-ip" v-model="objectSharePolicyForm.requireIpAllowlist" type="checkbox" />
        IP allowlist 필수
      </label>
      <label>
        최대 만료초
        <input data-testid="object-share-policy-max-expiry" v-model.number="objectSharePolicyForm.maxExpiresSeconds" min="60" type="number" />
      </label>
      <label>
        최대 다운로드
        <input data-testid="object-share-policy-max-downloads" v-model="objectSharePolicyForm.maxDownloadsLimit" min="1" type="number" />
      </label>
      <button data-testid="object-share-policy-save-button" type="submit" :disabled="objectSharePolicyForm.pending">저장</button>
    </form>
  </article>

  <article v-if="isAdmin" class="panel" data-testid="object-share-analytics-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Share Analytics</p>
        <h3>공유 링크 현황</h3>
      </div>
      <button data-testid="object-share-analytics-refresh-button" type="button" class="ghost" @click="$emit('refresh-object-share-analytics')">
        새로고침
      </button>
    </div>
    <form class="inline-form analytics-filter" data-testid="object-share-analytics-filter-form" @submit.prevent="$emit('refresh-object-share-analytics')">
      <input data-testid="object-share-analytics-bucket-filter" v-model="objectShareAnalyticsFilter.bucketName" placeholder="bucket" />
      <select data-testid="object-share-analytics-status-filter" v-model="objectShareAnalyticsFilter.status">
        <option value="">All</option>
        <option value="ACTIVE">ACTIVE</option>
        <option value="EXPIRED">EXPIRED</option>
        <option value="REVOKED">REVOKED</option>
        <option value="LIMIT_REACHED">LIMIT_REACHED</option>
      </select>
      <input data-testid="object-share-analytics-limit-filter" v-model.number="objectShareAnalyticsFilter.limit" type="number" min="1" max="100" />
      <button type="submit">조회</button>
    </form>
    <div class="compact-metrics" data-testid="object-share-analytics-metrics">
      <div><span>Total</span><b>{{ objectShareAnalytics.totalLinks }}</b></div>
      <div><span>Active</span><b>{{ objectShareAnalytics.activeLinks }}</b></div>
      <div><span>Downloads</span><b>{{ objectShareAnalytics.totalDownloads }}</b></div>
    </div>
    <ul class="compact-list" data-testid="object-share-analytics-list">
      <li v-for="link in objectShareAnalytics.recentLinks" :key="link.id || link.url">
        <span class="list-main">
          <b>{{ link.bucketName || '-' }} / {{ link.key || '-' }}</b>
          <small>{{ link.status || '-' }} / {{ link.downloadCount || 0 }} downloads</small>
        </span>
        <small>{{ formatDateTime(link.lastAccessedAt) }}</small>
      </li>
      <li v-if="objectShareAnalytics.recentLinks.length === 0" class="empty">공유 링크 기록 없음</li>
    </ul>
  </article>
</template>

<script setup>
defineProps({
  isAdmin: { type: Boolean, required: true },
  objectSharePolicyForm: { type: Object, required: true },
  objectShareAnalytics: { type: Object, required: true },
  objectShareAnalyticsFilter: { type: Object, required: true },
  formatDateTime: { type: Function, required: true },
})

defineEmits([
  'save-object-share-policy',
  'refresh-object-share-analytics',
])
</script>
