<template>
  <article class="panel" data-testid="dashboard-share-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Share Links</p>
        <h3>공유 링크 운영 상태</h3>
      </div>
      <span :class="['status-pill', analytics.activeLinks > 0 ? 'up' : 'mock']">
        {{ analytics.activeLinks }} active
      </span>
    </div>
    <dl class="status-dl compact">
      <div>
        <dt>전체/다운로드</dt>
        <dd>{{ analytics.totalLinks }} / {{ analytics.totalDownloads }}</dd>
      </div>
      <div>
        <dt>보호 설정</dt>
        <dd>{{ analytics.passwordProtectedLinks }} PW / {{ analytics.ipRestrictedLinks }} IP</dd>
      </div>
    </dl>
    <ul class="compact-list">
      <li v-if="analytics.recentLinks.length === 0" class="empty">공유 링크가 없습니다.</li>
      <li v-for="link in analytics.recentLinks.slice(0, 3)" :key="link.id">
        <span class="list-main">
          <b>{{ link.bucketName }}/{{ link.key }}</b>
          <small>{{ link.status }} / {{ formatDateTime(link.expiresAt) }}</small>
        </span>
        <span class="bucket-label">{{ link.downloadCount }} hits</span>
      </li>
    </ul>
  </article>
</template>

<script setup>
defineProps({
  analytics: {
    type: Object,
    required: true,
  },
  formatDateTime: {
    type: Function,
    required: true,
  },
})
</script>
