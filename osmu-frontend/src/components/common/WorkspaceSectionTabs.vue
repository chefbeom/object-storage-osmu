<template>
  <nav class="workspace-section-tabs" :aria-label="label">
    <button
      v-for="item in items"
      :key="item.id"
      type="button"
      :class="['workspace-section-tab', { active: modelValue === item.id }]"
      :aria-current="modelValue === item.id ? 'page' : undefined"
      @click="$emit('update:modelValue', item.id)"
    >
      <span>{{ item.label }}</span>
      <small v-if="item.hint">{{ item.hint }}</small>
    </button>
  </nav>
</template>

<script setup>
defineProps({
  modelValue: { type: String, required: true },
  items: { type: Array, required: true },
  label: { type: String, default: 'Workspace sections' },
})

defineEmits(['update:modelValue'])
</script>

<style scoped>
.workspace-section-tabs {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 2px 0 12px;
  border-bottom: 1px solid var(--line, #dbe3ef);
}

.workspace-section-tab {
  display: grid;
  gap: 2px;
  min-width: 112px;
  padding: 9px 12px;
  color: var(--muted, #5e718e);
  background: transparent;
  border: 1px solid transparent;
  border-radius: 6px;
  text-align: left;
  white-space: nowrap;
}

.workspace-section-tab:hover {
  color: var(--ink, #17263e);
  background: #f4f8fc;
}

.workspace-section-tab.active {
  color: #0d6f72;
  background: #edf9f7;
  border-color: #8fd2cc;
}

.workspace-section-tab span {
  font-weight: 800;
}

.workspace-section-tab small {
  color: inherit;
  font-size: 0.72rem;
  opacity: 0.78;
}

@media (max-width: 700px) {
  .workspace-section-tabs {
    margin-inline: -4px;
    padding-inline: 4px;
  }
}
</style>
