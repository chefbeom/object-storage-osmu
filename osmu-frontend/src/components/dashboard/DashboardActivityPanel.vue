<template>
  <article class="panel activity-panel" data-testid="dashboard-activity-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Recent Activity</p>
        <h3>최근 요청/변경</h3>
      </div>
      <span class="bucket-label">{{ logs.length }} events</span>
    </div>
    <ul class="audit-list dashboard-activity-list">
      <li v-if="logs.length === 0" class="empty">표시할 감사 로그가 없습니다.</li>
      <li v-for="entry in logs.slice(0, 5)" :key="entry.id" class="audit-entry">
        <div>
          <strong>{{ entry.eventType }}</strong>
          <small>{{ entry.actorId || '-' }} / {{ entry.targetType || '-' }} / {{ entry.targetId || '-' }}</small>
        </div>
        <div class="audit-meta">
          <span>{{ entry.result }}</span>
          <small>{{ formatDateTime(entry.createdAt) }}</small>
        </div>
      </li>
    </ul>
    <div class="panel-actions">
      <RouterLink class="text-link" to="/audit">Audit 페이지 열기</RouterLink>
    </div>
  </article>
</template>

<script setup>
defineProps({
  logs: {
    type: Array,
    required: true,
  },
  formatDateTime: {
    type: Function,
    required: true,
  },
})
</script>
