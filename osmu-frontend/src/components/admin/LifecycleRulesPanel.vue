<template>
  <article v-if="isAdmin" class="panel lifecycle-rules">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Lifecycle Rules</p>
        <h3>오브젝트 수명주기</h3>
      </div>
      <button type="button" class="ghost" @click="$emit('reset-lifecycle-rule-form')">New</button>
    </div>
    <form class="lifecycle-rule-form" @submit.prevent="$emit('save-object-lifecycle-rule')">
      <input v-model="lifecycleRuleForm.name" placeholder="rule name" />
      <select v-model="lifecycleRuleForm.targetType">
        <option value="OBJECT_VERSION">Object versions</option>
        <option value="TRASH_OBJECT">Trash objects</option>
      </select>
      <label class="check"><input v-model="lifecycleRuleForm.enabled" type="checkbox" />Enabled</label>
      <input v-model.number="lifecycleRuleForm.priority" min="1" max="10000" type="number" placeholder="priority" />
      <input v-model="lifecycleRuleForm.prefix" placeholder="prefix: videos/raw/" />
      <input v-model="lifecycleRuleForm.tags" placeholder="tags: stage=raw,project=osmu" />
      <input v-model.number="lifecycleRuleForm.retentionDays" min="1" max="3650" type="number" />
      <input v-model.number="lifecycleRuleForm.batchSize" min="1" max="10000" type="number" />
      <button type="submit" :disabled="lifecycleRuleForm.pending">{{ lifecycleRuleForm.pending ? 'Saving' : 'Save' }}</button>
    </form>
    <ul class="compact-list">
      <li v-for="rule in lifecycleRules" :key="rule.ruleId">
        <span class="list-main">
          <b>{{ rule.name }}</b>
          <small>{{ rule.targetType }} / {{ rule.enabled ? 'Enabled' : 'Disabled' }} / {{ rule.retentionDays }}d / {{ rule.prefix || '*' }}</small>
        </span>
        <span class="key-actions">
          <button type="button" class="ghost" :disabled="lifecycleRulePreview.pendingRuleId === rule.ruleId" @click="$emit('dry-run-object-lifecycle-rule', rule)">Dry run</button>
          <button type="button" class="ghost" @click="$emit('edit-lifecycle-rule', rule)">Edit</button>
          <button type="button" class="danger" @click="$emit('delete-object-lifecycle-rule', rule)">Delete</button>
        </span>
      </li>
      <li v-if="lifecycleRules.length === 0" class="empty">Lifecycle rule 없음</li>
    </ul>
    <div class="lifecycle-conflicts">
      <strong>{{ lifecycleRuleConflicts.conflictCount }} overlaps</strong>
      <small>{{ lifecycleRuleConflicts.ruleCount }} enabled rules checked</small>
      <button type="button" class="ghost" :disabled="lifecycleRuleConflicts.pending" @click="$emit('refresh-lifecycle-rule-conflicts')">Check</button>
    </div>
    <div class="lifecycle-xml">
      <div>
        <strong>S3 Lifecycle XML</strong>
        <small v-if="lifecycleXml.importedCount !== null">imported {{ lifecycleXml.importedCount }} rules</small>
      </div>
      <div class="rule-actions">
        <button type="button" class="ghost" :disabled="lifecycleXml.pending" @click="$emit('export-lifecycle-xml')">Export</button>
        <button type="button" :disabled="lifecycleXml.pending" @click="$emit('import-lifecycle-xml')">Import</button>
      </div>
      <textarea v-model="lifecycleXml.content" placeholder="<LifecycleConfiguration>..." rows="6"></textarea>
    </div>
    <div v-if="lifecycleRulePreview.ruleId" class="lifecycle-preview">
      <strong>{{ lifecycleRulePreview.ruleName }}</strong>
      <small>
        {{ lifecycleRulePreview.candidateCount }} candidates /
        {{ formatBytes(lifecycleRulePreview.candidateBytes) }}
      </small>
    </div>
  </article>
</template>

<script setup>
defineProps({
  isAdmin: { type: Boolean, required: true },
  lifecycleRuleForm: { type: Object, required: true },
  lifecycleRules: { type: Array, required: true },
  lifecycleRulePreview: { type: Object, required: true },
  lifecycleRuleConflicts: { type: Object, required: true },
  lifecycleXml: { type: Object, required: true },
  formatBytes: { type: Function, required: true },
})

defineEmits([
  'reset-lifecycle-rule-form',
  'save-object-lifecycle-rule',
  'dry-run-object-lifecycle-rule',
  'edit-lifecycle-rule',
  'delete-object-lifecycle-rule',
  'refresh-lifecycle-rule-conflicts',
  'export-lifecycle-xml',
  'import-lifecycle-xml',
])
</script>
