<template>
  <article v-if="isAdmin" class="panel" data-testid="quota-policy-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Quota</p>
        <h3>쿼터 정책</h3>
      </div>
    </div>
    <form class="quota-form" data-testid="quota-policy-form" @submit.prevent="$emit('save-quota-policy')">
      <select data-testid="quota-policy-target-type" v-model="quotaPolicyForm.targetType" @change="$emit('reset-quota-policy-target')">
        <option value="USER">USER</option>
        <option value="ORGANIZATION">ORGANIZATION</option>
        <option value="BUCKET">BUCKET</option>
      </select>
      <input data-testid="quota-policy-target-search" v-model="quotaPolicyForm.targetSearch" placeholder="target search" />
      <select data-testid="quota-policy-target-id" v-model="quotaPolicyForm.targetId">
        <option value="">Target</option>
        <option v-for="target in quotaPolicyTargetOptions" :key="target.id" :value="target.id">{{ target.label }}</option>
      </select>
      <input data-testid="quota-policy-quota-input" v-model.number="quotaPolicyForm.quotaGb" min="1" type="number" />
      <input data-testid="quota-policy-reason-input" v-model="quotaPolicyForm.reason" placeholder="reason" />
      <button data-testid="quota-policy-save-button" type="submit" :disabled="!quotaPolicyForm.targetId">저장</button>
      <button data-testid="quota-policy-cancel-edit-button" type="button" class="ghost" :disabled="!quotaPolicyForm.editingKey" @click="$emit('reset-quota-policy-form')">
        취소
      </button>
    </form>
    <ul class="compact-list">
      <li v-for="policy in quotaPolicies" :key="`${policy.targetType}-${policy.targetId}`">
        <span class="list-main">
          <b>{{ policy.targetType }} #{{ policy.targetId }}</b>
          <small>{{ formatBytes(policy.usedBytes) }} / {{ formatBytes(policy.quotaBytes) }}</small>
        </span>
        <span class="key-actions">
          <button data-testid="quota-policy-edit-button" type="button" class="ghost" @click="$emit('edit-quota-policy', policy)">수정</button>
          <button type="button" class="danger" @click="$emit('delete-quota-policy', policy)">삭제</button>
        </span>
      </li>
      <li v-if="quotaPolicies.length === 0" class="empty">쿼터 정책 없음</li>
    </ul>
    <ul class="compact-list history-list" data-testid="quota-policy-history-list">
      <li v-for="entry in quotaPolicyHistory" :key="entry.id">
        <span>{{ entry.action || entry.eventType || '-' }} / {{ entry.targetType }} #{{ entry.targetId }}</span>
        <small>{{ entry.reason || '-' }}</small>
      </li>
      <li v-if="quotaPolicyHistory.length === 0" class="empty">쿼터 변경 이력 없음</li>
    </ul>
  </article>
</template>

<script setup>
defineProps({
  isAdmin: { type: Boolean, required: true },
  quotaPolicyForm: { type: Object, required: true },
  quotaPolicyTargetOptions: { type: Array, required: true },
  quotaPolicies: { type: Array, required: true },
  quotaPolicyHistory: { type: Array, required: true },
  formatBytes: { type: Function, required: true },
})

defineEmits([
  'save-quota-policy',
  'reset-quota-policy-target',
  'reset-quota-policy-form',
  'edit-quota-policy',
  'delete-quota-policy',
])
</script>
