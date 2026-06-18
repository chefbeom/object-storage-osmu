<template>
  <section id="audit" class="lower">
    <article v-if="!isAdmin" class="panel empty-state-panel" data-testid="audit-empty-state">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Audit Locked</p>
          <h3>감사 로그 권한 필요</h3>
        </div>
      </div>
      <div class="empty-state-body">
        <strong>{{ isLoggedIn ? 'ADMIN 권한 계정만 감사 로그를 조회할 수 있습니다.' : '로그인 후 감사 로그 권한을 확인하세요.' }}</strong>
        <small>API 요청 이력, 권한 실패, 공유 링크 접근 기록은 관리자 화면에서 검증합니다.</small>
      </div>
    </article>

    <article v-if="isAdmin" class="panel audit-panel" data-testid="audit-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Audit</p>
          <h3>감사 로그</h3>
        </div>
      </div>
      <form class="inline-form audit-filter" data-testid="audit-filter-form" @submit.prevent="$emit('load-audit-logs')">
        <input data-testid="audit-event-type-input" v-model="auditFilter.eventType" placeholder="eventType" />
        <input data-testid="audit-actor-id-input" v-model="auditFilter.actorId" placeholder="actorId" />
        <input data-testid="audit-request-id-input" v-model="auditFilter.requestId" placeholder="requestId" />
        <input data-testid="audit-target-type-input" v-model="auditFilter.targetType" placeholder="targetType" />
        <input data-testid="audit-target-id-input" v-model="auditFilter.targetId" placeholder="targetId" />
        <select data-testid="audit-result-select" v-model="auditFilter.result">
          <option value="">Result</option>
          <option value="SUCCESS">SUCCESS</option>
          <option value="FAIL">FAIL</option>
        </select>
        <input v-model="auditFilter.from" type="datetime-local" />
        <input v-model="auditFilter.to" type="datetime-local" />
        <input v-model.number="auditFilter.limit" type="number" min="1" max="500" />
        <button data-testid="audit-search-button" type="submit">필터</button>
        <button data-testid="audit-export-button" type="button" class="ghost" @click="$emit('export-audit-csv')">CSV</button>
        <button data-testid="audit-reset-button" type="button" class="ghost" @click="$emit('reset-audit-filter')">초기화</button>
      </form>
      <ul class="audit-list" data-testid="audit-list">
        <li v-for="entry in auditLogs" :key="entry.id" class="audit-entry">
          <div>
            <strong>{{ entry.eventType }}</strong>
            <small>{{ entry.actorId }} -> {{ entry.targetId }}</small>
          </div>
          <div class="audit-meta">
            <span>{{ entry.result }}</span>
            <small>{{ entry.ipAddress || '-' }}</small>
            <small>{{ entry.requestId || '-' }}</small>
          </div>
        </li>
        <li v-if="auditLogs.length === 0" class="empty">로그 없음</li>
      </ul>
      <div class="panel-actions" v-if="auditLogs.length > 0">
        <button type="button" class="ghost" :disabled="!auditNextCursor" @click="$emit('load-next-audit-logs')">다음 로그</button>
      </div>
    </article>
  </section>
</template>

<script setup>
defineProps({
  isAdmin: { type: Boolean, required: true },
  isLoggedIn: { type: Boolean, required: true },
  auditFilter: { type: Object, required: true },
  auditLogs: { type: Array, required: true },
  auditNextCursor: { type: String, required: true },
})

defineEmits([
  'load-audit-logs',
  'export-audit-csv',
  'reset-audit-filter',
  'load-next-audit-logs',
])
</script>
