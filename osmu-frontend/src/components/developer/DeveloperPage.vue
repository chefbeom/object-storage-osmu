<template>
  <section id="developer-workbench" class="management-grid lower" data-testid="developer-page">
    <AccessKeyPanel
      id="developer-access-keys"
      :access-key-form="accessKeyForm"
      :buckets="buckets"
      :is-logged-in="isLoggedIn"
      :new-secret-key="newSecretKey"
      :access-keys="accessKeys"
      :format-key-scope="formatKeyScope"
      @create-access-key="$emit('create-access-key')"
      @add-access-key-scope="$emit('add-access-key-scope')"
      @remove-access-key-scope="$emit('remove-access-key-scope', $event)"
      @rotate-access-key="$emit('rotate-access-key', $event)"
      @delete-access-key="$emit('delete-access-key', $event)"
      @bulk-disable-access-keys="$emit('bulk-disable-access-keys', $event)"
    />

    <article class="panel developer-endpoint-panel" data-testid="developer-s3-endpoint-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">S3 Compatible</p>
          <h3>API 접속 정보</h3>
        </div>
      </div>
      <dl class="status-dl compact">
        <div>
          <dt>Endpoint</dt>
          <dd data-testid="developer-s3-endpoint">{{ s3ClientConfig.endpoint || '-' }}</dd>
        </div>
        <div>
          <dt>Region</dt>
          <dd data-testid="developer-s3-region">{{ s3ClientConfig.region || '-' }}</dd>
        </div>
        <div>
          <dt>Signature</dt>
          <dd data-testid="developer-s3-signature">{{ s3ClientConfig.signatureVersion || '-' }}</dd>
        </div>
        <div>
          <dt>Auth</dt>
          <dd>Access Key + Secret Key</dd>
        </div>
        <div>
          <dt>Selected Bucket</dt>
          <dd data-testid="developer-selected-bucket">{{ selectedBucket || '-' }}</dd>
        </div>
        <div>
          <dt>Scope</dt>
          <dd>READ / WRITE / DELETE</dd>
        </div>
        <div>
          <dt>Virtual Host</dt>
          <dd data-testid="developer-s3-virtual-host">
            {{ s3ClientConfig.virtualHostedStyleEnabled ? virtualHostedLabel : 'Disabled' }}
          </dd>
        </div>
      </dl>
    </article>

    <article class="panel developer-client-snippets-panel" data-testid="developer-client-snippets-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Client Setup</p>
          <h3>S3 클라이언트 예시</h3>
        </div>
      </div>
      <div class="client-snippet-list">
        <section>
          <h4>AWS CLI</h4>
          <pre data-testid="developer-client-aws-cli"><code>{{ awsCliSnippet }}</code></pre>
        </section>
        <section>
          <h4>s3fs-fuse</h4>
          <pre data-testid="developer-client-s3fs"><code>{{ s3fsSnippet }}</code></pre>
        </section>
        <section>
          <h4>goofys</h4>
          <pre data-testid="developer-client-goofys"><code>{{ goofysSnippet }}</code></pre>
        </section>
      </div>
    </article>
  </section>
</template>

<script setup>
import { computed } from 'vue'
import AccessKeyPanel from '../admin/AccessKeyPanel.vue'

const props = defineProps({
  accessKeyForm: { type: Object, required: true },
  buckets: { type: Array, required: true },
  isLoggedIn: { type: Boolean, required: true },
  newSecretKey: { type: String, required: true },
  accessKeys: { type: Array, required: true },
  selectedBucket: { type: String, required: true },
  s3ClientConfig: { type: Object, required: true },
  formatKeyScope: { type: Function, required: true },
})

defineEmits([
  'create-access-key',
  'add-access-key-scope',
  'remove-access-key-scope',
  'rotate-access-key',
  'delete-access-key',
  'bulk-disable-access-keys',
])

const virtualHostedLabel = computed(() => props.s3ClientConfig.virtualHostedStyleDomainSuffixes?.join(', ') || 'Enabled')
const snippetEndpoint = computed(() => props.s3ClientConfig.endpoint || '<S3_ENDPOINT>')
const snippetRegion = computed(() => props.s3ClientConfig.region || 'us-east-1')
const snippetBucket = computed(() => props.selectedBucket || '<BUCKET_NAME>')
const awsCliSnippet = computed(() => [
  'aws configure set aws_access_key_id <ACCESS_KEY>',
  'aws configure set aws_secret_access_key <SECRET_KEY>',
  `aws configure set default.region ${snippetRegion.value}`,
  `aws --endpoint-url ${snippetEndpoint.value} s3 ls s3://${snippetBucket.value}`,
].join('\n'))
const s3fsSnippet = computed(() => [
  'printf "%s:%s\\n" "<ACCESS_KEY>" "<SECRET_KEY>" > ~/.passwd-s3fs',
  'chmod 600 ~/.passwd-s3fs',
  `s3fs ${snippetBucket.value} /mnt/osmu -o passwd_file=~/.passwd-s3fs -o url=${snippetEndpoint.value} -o use_path_request_style`,
].join('\n'))
const goofysSnippet = computed(() => (
  `AWS_ACCESS_KEY_ID=<ACCESS_KEY> AWS_SECRET_ACCESS_KEY=<SECRET_KEY> goofys --endpoint ${snippetEndpoint.value} --region ${snippetRegion.value} ${snippetBucket.value} /mnt/osmu`
))
</script>
