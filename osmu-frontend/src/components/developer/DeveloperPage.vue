<template>
  <section id="developer-workbench" class="management-grid lower" data-testid="developer-page">
    <header class="workspace-page-header developer-workspace-header">
      <div>
        <p class="eyebrow">Developer</p>
        <h2>Developer workspace</h2>
        <small>Set up one connection step at a time, then select the client example you need.</small>
      </div>
      <WorkspaceSectionTabs v-model="activeDeveloperArea" :items="developerWorkspaceAreas" label="Developer workspace areas" />
    </header>
    <article v-if="activeDeveloperArea === 'start'" class="panel developer-onboarding-panel" data-testid="developer-onboarding-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Onboarding</p>
          <h3>개발자 시작 checklist</h3>
        </div>
        <span class="status-pill up" data-testid="developer-onboarding-progress">
          {{ developerOnboardingProgress.ready }}/{{ developerOnboardingProgress.total }} Ready
        </span>
      </div>
      <ol class="developer-onboarding-list">
        <li
          v-for="step in developerOnboardingSteps"
          :key="step.id"
          :class="{ complete: step.done }"
          :data-step="step.id"
          data-testid="developer-onboarding-step"
        >
          <span class="status-pill" :class="step.done ? 'up' : 'mock'">
            {{ step.done ? 'Ready' : 'Todo' }}
          </span>
          <span>
            <strong>{{ step.label }}</strong>
            <small>{{ step.detail }}</small>
          </span>
        </li>
      </ol>
    </article>

    <AccessKeyPanel
      v-if="activeDeveloperArea === 'credentials'"
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

    <article v-if="activeDeveloperArea === 'start'" class="panel developer-endpoint-panel" data-testid="developer-s3-endpoint-panel">
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

    <article v-if="activeDeveloperArea === 'examples'" class="panel developer-client-snippets-panel" data-testid="developer-client-snippets-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Client Setup</p>
          <h3>S3 클라이언트 예시</h3>
        </div>
      </div>
      <div class="developer-client-picker" role="tablist" aria-label="Client examples">
        <button v-for="client in developerClientExamples" :key="client.id" type="button" :class="{ active: activeDeveloperClient === client.id }" @click="activeDeveloperClient = client.id">
          {{ client.label }}
        </button>
      </div>
      <div class="client-snippet-list client-snippet-single">
        <section v-if="activeDeveloperClient === 'aws-cli'">
          <h4>AWS CLI</h4>
          <pre data-testid="developer-client-aws-cli"><code>{{ awsCliSnippet }}</code></pre>
        </section>
        <section v-else-if="activeDeveloperClient === 's3fs'">
          <h4>s3fs-fuse</h4>
          <pre data-testid="developer-client-s3fs"><code>{{ s3fsSnippet }}</code></pre>
        </section>
        <section v-else-if="activeDeveloperClient === 'goofys'">
          <h4>goofys</h4>
          <pre data-testid="developer-client-goofys"><code>{{ goofysSnippet }}</code></pre>
        </section>
        <section v-else-if="activeDeveloperClient === 'javascript'">
          <h4>AWS SDK JavaScript</h4>
          <pre data-testid="developer-sdk-javascript"><code>{{ javascriptSdkSnippet }}</code></pre>
        </section>
        <section v-else-if="activeDeveloperClient === 'python'">
          <h4>boto3 Python</h4>
          <pre data-testid="developer-sdk-python"><code>{{ pythonSdkSnippet }}</code></pre>
        </section>
        <section v-else>
          <h4>AWS SDK Java</h4>
          <pre data-testid="developer-sdk-java"><code>{{ javaSdkSnippet }}</code></pre>
        </section>
      </div>
    </article>

    <article v-if="activeDeveloperArea === 'compatibility'" class="panel developer-compatibility-panel" data-testid="developer-client-compatibility-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Compatibility</p>
          <h3>Real S3 client matrix</h3>
        </div>
        <span class="status-pill up" data-testid="developer-client-compatibility-region">{{ snippetRegion }}</span>
      </div>
      <div class="developer-compatibility-table">
        <div class="developer-compatibility-row header" aria-hidden="true">
          <span>Client</span>
          <span>Status</span>
          <span>Auth</span>
          <span>Operations</span>
          <span>Required option</span>
        </div>
        <div
          v-for="client in clientCompatibilityRows"
          :key="client.name"
          class="developer-compatibility-row"
          data-testid="developer-client-compatibility-row"
        >
          <strong>{{ client.name }}</strong>
          <span class="status-pill" :class="client.tone" data-testid="developer-client-compatibility-status">{{ client.status }}</span>
          <span>{{ client.auth }}</span>
          <span>{{ client.operations }}</span>
          <small>{{ client.option }}</small>
        </div>
      </div>
    </article>
  </section>
</template>

<script setup>
import { computed, ref } from 'vue'
import WorkspaceSectionTabs from '../common/WorkspaceSectionTabs.vue'
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

const activeDeveloperArea = ref('start')
const activeDeveloperClient = ref('aws-cli')
const developerWorkspaceAreas = [
  { id: 'start', label: 'Start', hint: 'Endpoint and checklist' },
  { id: 'credentials', label: 'Credentials', hint: 'Access keys' },
  { id: 'examples', label: 'Examples', hint: 'One client at a time' },
  { id: 'compatibility', label: 'Compatibility', hint: 'Client support' },
]
const developerClientExamples = [
  { id: 'aws-cli', label: 'AWS CLI' },
  { id: 's3fs', label: 's3fs' },
  { id: 'goofys', label: 'goofys' },
  { id: 'javascript', label: 'JavaScript' },
  { id: 'python', label: 'Python' },
  { id: 'java', label: 'Java' },
]
const virtualHostedLabel = computed(() => props.s3ClientConfig.virtualHostedStyleDomainSuffixes?.join(', ') || 'Enabled')
const snippetEndpoint = computed(() => props.s3ClientConfig.endpoint || '<S3_ENDPOINT>')
const snippetRegion = computed(() => props.s3ClientConfig.region || 'us-east-1')
const snippetBucket = computed(() => props.selectedBucket || '<BUCKET_NAME>')
const developerOnboardingSteps = computed(() => [
  {
    id: 'endpoint',
    label: 'Endpoint 확인',
    detail: props.s3ClientConfig.endpoint || 'S3 endpoint 설정 대기',
    done: Boolean(props.s3ClientConfig.endpoint),
  },
  {
    id: 'bucket',
    label: 'Bucket 선택',
    detail: props.selectedBucket || 'Storage 화면에서 bucket 선택',
    done: Boolean(props.selectedBucket),
  },
  {
    id: 'access-key',
    label: 'Access Key 준비',
    detail: props.accessKeys.length > 0 ? `${props.accessKeys.length} keys available` : 'Access Key 생성 필요',
    done: props.accessKeys.length > 0,
  },
  {
    id: 'sdk-snippet',
    label: 'SDK 예제 선택',
    detail: 'AWS CLI, s3fs-fuse, goofys, JavaScript, Python, Java',
    done: Boolean(props.s3ClientConfig.endpoint && props.s3ClientConfig.region),
  },
])
const developerOnboardingProgress = computed(() => {
  const total = developerOnboardingSteps.value.length
  const ready = developerOnboardingSteps.value.filter((step) => step.done).length
  return { ready, total }
})
const pathStyleOption = computed(() => (
  props.s3ClientConfig.pathStyleSupported === false ? 'virtual-hosted-style endpoint 필요' : 'path-style / forcePathStyle 사용'
))
const sigV4Label = computed(() => props.s3ClientConfig.signatureVersion || 'AWS4-HMAC-SHA256')
const clientCompatibilityRows = computed(() => [
  {
    name: 'AWS CLI',
    status: 'Supported',
    tone: 'up',
    auth: sigV4Label.value,
    operations: 'ls, cp, stat/head, rm',
    option: `--endpoint-url, ${pathStyleOption.value}`,
  },
  {
    name: 'MinIO Client',
    status: 'Smoke',
    tone: 'up',
    auth: sigV4Label.value,
    operations: 'alias, ls, cp, stat, rm',
    option: `mc alias set, ${pathStyleOption.value}`,
  },
  {
    name: 'boto3 Python',
    status: 'Supported',
    tone: 'up',
    auth: sigV4Label.value,
    operations: 'list_objects_v2, put/get object',
    option: 'endpoint_url, region_name',
  },
  {
    name: 'AWS SDK JavaScript',
    status: 'Supported',
    tone: 'up',
    auth: sigV4Label.value,
    operations: 'ListObjectsV2, PutObject, GetObject',
    option: 'endpoint, region, forcePathStyle',
  },
  {
    name: 'AWS SDK Java',
    status: 'Supported',
    tone: 'up',
    auth: sigV4Label.value,
    operations: 'listObjectsV2, put/get object',
    option: 'endpointOverride, forcePathStyle',
  },
  {
    name: 's3fs-fuse / goofys',
    status: 'Mount',
    tone: 'mock',
    auth: 'Access Key file/env',
    operations: 'mount, read, write, list',
    option: `url/endpoint, ${pathStyleOption.value}`,
  },
  {
    name: 's3cmd',
    status: 'Manual',
    tone: 'mock',
    auth: sigV4Label.value,
    operations: 'ls, put, get, del',
    option: 'host_base, host_bucket, signature_v2 = False',
  },
])
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
const javascriptSdkSnippet = computed(() => [
  'import { S3Client, ListObjectsV2Command } from "@aws-sdk/client-s3"',
  '',
  'const client = new S3Client({',
  `  endpoint: "${snippetEndpoint.value}",`,
  `  region: "${snippetRegion.value}",`,
  '  forcePathStyle: true,',
  '  credentials: {',
  '    accessKeyId: "<ACCESS_KEY>",',
  '    secretAccessKey: "<SECRET_KEY>",',
  '  },',
  '})',
  '',
  `const result = await client.send(new ListObjectsV2Command({ Bucket: "${snippetBucket.value}" }))`,
  'console.log(result.Contents ?? [])',
].join('\n'))
const pythonSdkSnippet = computed(() => [
  'import boto3',
  '',
  'client = boto3.client(',
  '    "s3",',
  `    endpoint_url="${snippetEndpoint.value}",`,
  `    region_name="${snippetRegion.value}",`,
  '    aws_access_key_id="<ACCESS_KEY>",',
  '    aws_secret_access_key="<SECRET_KEY>",',
  ')',
  '',
  `print(client.list_objects_v2(Bucket="${snippetBucket.value}").get("Contents", []))`,
].join('\n'))
const javaSdkSnippet = computed(() => [
  'S3Client client = S3Client.builder()',
  `    .endpointOverride(URI.create("${snippetEndpoint.value}"))`,
  `    .region(Region.of("${snippetRegion.value}"))`,
  '    .forcePathStyle(true)',
  '    .credentialsProvider(StaticCredentialsProvider.create(',
  '        AwsBasicCredentials.create("<ACCESS_KEY>", "<SECRET_KEY>")))',
  '    .build();',
  '',
  `client.listObjectsV2(ListObjectsV2Request.builder().bucket("${snippetBucket.value}").build())`,
  '    .contents()',
  '    .forEach(object -> System.out.println(object.key()));',
].join('\n'))
</script>
