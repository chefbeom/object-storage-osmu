<template>
  <article v-if="isLoggedIn && selectedBucket && canUseBucketLifecycle" class="panel" data-testid="bucket-lifecycle-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Bucket Lifecycle</p>
        <h3>S3 Lifecycle XML</h3>
      </div>
      <strong class="bucket-label">{{ selectedBucket }}</strong>
    </div>
    <div class="lifecycle-xml">
      <div>
        <strong>{{ bucketLifecycleXml.ruleCount ?? 0 }} rules</strong>
        <small v-if="bucketLifecycleXml.savedCount !== null">saved {{ bucketLifecycleXml.savedCount }} rules</small>
      </div>
      <div class="rule-actions">
        <button type="button" class="ghost" :disabled="bucketLifecycleXml.pending" @click="$emit('load-bucket-lifecycle-xml')">
          {{ bucketLifecycleXml.pending ? 'Loading' : 'Load' }}
        </button>
        <button type="button" :disabled="bucketLifecycleXml.pending" @click="$emit('put-bucket-lifecycle-xml')">Save</button>
        <button type="button" class="danger" :disabled="bucketLifecycleXml.pending" @click="$emit('delete-bucket-lifecycle-xml')">Delete</button>
      </div>
      <textarea v-model="bucketLifecycleXml.content" placeholder="<LifecycleConfiguration>..." rows="6"></textarea>
    </div>
  </article>

  <article v-if="isLoggedIn && selectedBucket && canUseBucketTags" class="panel" data-testid="bucket-tags-panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Bucket Tags</p>
        <h3>S3 Tagging</h3>
      </div>
      <strong class="bucket-label">{{ selectedBucket }}</strong>
    </div>
    <div class="lifecycle-xml">
      <div>
        <strong>{{ bucketTags.tagCount ?? 0 }} tags</strong>
        <small v-if="bucketTags.savedCount !== null">saved {{ bucketTags.savedCount }} tags</small>
      </div>
      <div class="rule-actions">
        <button type="button" class="ghost" :disabled="bucketTags.pending" @click="$emit('load-bucket-tags')">
          {{ bucketTags.pending ? 'Loading' : 'Load' }}
        </button>
        <button type="button" :disabled="bucketTags.pending" @click="$emit('put-bucket-tags')">Save</button>
        <button type="button" class="danger" :disabled="bucketTags.pending" @click="$emit('delete-bucket-tags')">Delete</button>
      </div>
      <textarea v-model="bucketTags.content" placeholder="project=osmu,stage=raw" rows="4"></textarea>
    </div>
  </article>
</template>

<script setup>
defineProps({
  isLoggedIn: { type: Boolean, required: true },
  selectedBucket: { type: String, required: true },
  canUseBucketLifecycle: { type: Boolean, required: true },
  bucketLifecycleXml: { type: Object, required: true },
  canUseBucketTags: { type: Boolean, required: true },
  bucketTags: { type: Object, required: true },
})

defineEmits([
  'load-bucket-lifecycle-xml',
  'put-bucket-lifecycle-xml',
  'delete-bucket-lifecycle-xml',
  'load-bucket-tags',
  'put-bucket-tags',
  'delete-bucket-tags',
])
</script>
