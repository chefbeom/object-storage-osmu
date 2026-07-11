<template>
  <section class="quick-start-page" data-testid="quick-start-page">
    <header class="quick-start-header">
      <div>
        <p class="eyebrow">Quick Start</p>
        <h3>{{ screen === 'start' ? '저장소를 만들고 바로 연결하세요' : 'Quick Start 설정' }}</h3>
        <p>{{ screen === 'start' ? '버킷 생성, Access Key 발급, 연결 예시를 한 화면에서 끝냅니다.' : '다음 발급에 사용할 기본값과 코드 예시를 정합니다.' }}</p>
      </div>
      <div class="quick-start-tabs" role="tablist" aria-label="Quick Start view">
        <button type="button" :class="{ active: screen === 'start' }" @click="screen = 'start'">시작</button>
        <button type="button" :class="{ active: screen === 'settings' }" data-testid="quick-start-settings-button" @click="screen = 'settings'">설정</button>
      </div>
    </header>

    <template v-if="screen === 'start'">
      <section class="quick-start-status" aria-label="Quick Start progress">
        <span :class="{ done: Boolean(selectedBucket) }"><b>1</b> 저장소</span>
        <i aria-hidden="true"></i>
        <span :class="{ done: Boolean(latestAccessKey) }"><b>2</b> Access Key</span>
        <i aria-hidden="true"></i>
        <span :class="{ done: Boolean(selectedBucket && latestAccessKey) }"><b>3</b> 연결</span>
      </section>

      <div class="quick-start-grid">
        <article class="quick-step" data-testid="quick-start-storage-step">
          <div class="quick-step-heading">
            <span>01</span>
            <div><p class="eyebrow">Storage</p><h4>저장소 만들기</h4></div>
            <strong v-if="selectedBucket" class="status-pill up">READY</strong>
          </div>
          <p>파일을 보관할 버킷 이름과 용량만 정하면 됩니다.</p>
          <form class="quick-form" @submit.prevent="createBucket">
            <label>버킷 이름<input v-model.trim="bucketName" data-testid="quick-start-bucket-name" placeholder="my-project-data" /></label>
            <label>기본 용량<select v-model.number="settings.quotaGb" data-testid="quick-start-bucket-quota"><option :value="10">10 GB</option><option :value="100">100 GB</option><option :value="1000">1 TB</option></select></label>
            <button data-testid="quick-start-create-bucket" type="submit" :disabled="!bucketName">저장소 만들기</button>
          </form>
          <div v-if="selectedBucket" class="quick-result"><span>사용 중인 버킷</span><strong>{{ selectedBucket }}</strong></div>
        </article>

        <article class="quick-step" data-testid="quick-start-key-step">
          <div class="quick-step-heading">
            <span>02</span>
            <div><p class="eyebrow">Credentials</p><h4>Access Key 발급</h4></div>
            <strong v-if="latestAccessKey" class="status-pill up">ISSUED</strong>
          </div>
          <p>선택된 버킷에만 사용할 수 있는 애플리케이션 키를 만듭니다.</p>
          <form class="quick-form" @submit.prevent="createAccessKey">
            <label>키 이름<input v-model.trim="keyName" data-testid="quick-start-key-name" placeholder="my-app-key" /></label>
            <label>권한<select v-model="settings.permission"><option value="READ_WRITE">읽기 및 쓰기</option><option value="READ_ONLY">읽기 전용</option></select></label>
            <button data-testid="quick-start-create-key" type="submit" :disabled="!selectedBucket || !keyName">Access Key 발급</button>
          </form>
          <div v-if="latestAccessKey" class="quick-result"><span>Access Key</span><code data-testid="quick-start-access-key">{{ latestAccessKey }}</code></div>
          <div v-if="newSecretKey" class="quick-secret" data-testid="quick-start-secret-key">
            <span>Secret Key - 지금만 표시됩니다.</span><code>{{ newSecretKey }}</code><button type="button" class="ghost" @click="copy(newSecretKey)">복사</button>
          </div>
        </article>

        <article class="quick-step quick-connect-step" data-testid="quick-start-connect-step">
          <div class="quick-step-heading"><span>03</span><div><p class="eyebrow">Connect</p><h4>바로 사용하기</h4></div></div>
          <p>아래 명령을 복사해 터미널에서 실행하거나, 포털 업로드 화면으로 이동하세요.</p>
          <pre><code>{{ connectionExample }}</code></pre>
          <div class="quick-connect-actions">
            <button type="button" class="ghost" data-testid="quick-start-copy-example" @click="copy(connectionExample)">예시 복사</button>
            <button type="button" :disabled="!selectedBucket" @click="$emit('open-objects')">파일 올리기</button>
          </div>
        </article>
      </div>
      <QuickStartGuide />
    </template>

    <section v-else class="quick-settings" data-testid="quick-start-settings">
      <div class="quick-settings-copy"><p class="eyebrow">Defaults</p><h4>다음 저장소와 키의 기본값</h4><p>설정은 이 브라우저에만 저장됩니다. 실제 버킷과 Access Key는 발급 버튼을 눌렀을 때 생성됩니다.</p></div>
      <form class="quick-settings-form" @submit.prevent="saveSettings">
        <label>기본 용량<select v-model.number="settings.quotaGb"><option :value="10">10 GB</option><option :value="100">100 GB</option><option :value="1000">1 TB</option></select></label>
        <label>기본 권한<select v-model="settings.permission"><option value="READ_WRITE">읽기 및 쓰기</option><option value="READ_ONLY">읽기 전용</option></select></label>
        <label>연결 예시<select v-model="settings.client"><option value="aws">AWS CLI</option><option value="python">Python (boto3)</option></select></label>
        <button data-testid="quick-start-save-settings" type="submit">설정 저장</button>
      </form>
      <p v-if="settingsSaved" class="quick-settings-saved" role="status">설정을 저장했습니다.</p>
    </section>
  </section>
</template>

<script setup>
import { computed, reactive, ref } from 'vue'
import QuickStartGuide from './QuickStartGuide.vue'

const props = defineProps({
  selectedBucket: { type: String, default: '' },
  latestAccessKey: { type: String, default: '' },
  newSecretKey: { type: String, default: '' },
  s3ClientConfig: { type: Object, required: true },
})

const emit = defineEmits(['create-bucket', 'create-access-key', 'open-objects'])
const storedSettings = loadSettings()
const screen = ref('start')
const bucketName = ref('')
const keyName = ref('my-app-key')
const settingsSaved = ref(false)
const settings = reactive(storedSettings)

const connectionExample = computed(() => {
  const endpoint = props.s3ClientConfig.endpoint || 'http://localhost:9000'
  const bucket = props.selectedBucket || '<YOUR_BUCKET>'
  if (settings.client === 'python') {
    return `import boto3\n\ns3 = boto3.client('s3', endpoint_url='${endpoint}')\ns3.upload_file('hello.txt', '${bucket}', 'hello.txt')`
  }
  return `aws s3 cp hello.txt s3://${bucket}/hello.txt --endpoint-url ${endpoint}`
})

function createBucket() {
  emit('create-bucket', { name: bucketName.value, quotaGb: settings.quotaGb })
}

function createAccessKey() {
  emit('create-access-key', {
    name: keyName.value,
    permissions: settings.permission === 'READ_ONLY' ? ['READ'] : ['READ', 'WRITE'],
  })
}

function saveSettings() {
  window.localStorage.setItem('osmu.quick-start.settings.v1', JSON.stringify(settings))
  settingsSaved.value = true
  window.setTimeout(() => { settingsSaved.value = false }, 1800)
}

async function copy(value) {
  try { await navigator.clipboard.writeText(value) } catch { /* clipboard access is optional */ }
}

function loadSettings() {
  try {
    const stored = JSON.parse(window.localStorage.getItem('osmu.quick-start.settings.v1') || '{}')
    return { quotaGb: [10, 100, 1000].includes(Number(stored.quotaGb)) ? Number(stored.quotaGb) : 100, permission: stored.permission === 'READ_ONLY' ? 'READ_ONLY' : 'READ_WRITE', client: stored.client === 'python' ? 'python' : 'aws' }
  } catch {
    return { quotaGb: 100, permission: 'READ_WRITE', client: 'aws' }
  }
}
</script>

<style scoped>
.quick-start-page { display: grid; gap: 20px; min-width: 0; }
.quick-start-header { display: flex; align-items: center; justify-content: space-between; gap: 18px; padding-bottom: 18px; border-bottom: 1px solid #d9e1e9; }
.quick-start-header h3 { margin: 4px 0 6px; color: #172033; font-size: 24px; letter-spacing: 0; }
.quick-start-header p:last-child { margin: 0; color: #657287; }
.quick-start-tabs { display: flex; gap: 6px; padding: 4px; border: 1px solid #d7e0e9; border-radius: 6px; background: #f5f7f9; }
.quick-start-tabs button { min-height: 32px; padding: 6px 12px; background: transparent; color: #657287; }
.quick-start-tabs button.active { background: #fff; color: #0d655f; box-shadow: 0 1px 2px rgba(23, 32, 51, .12); }
.quick-start-status { display: flex; align-items: center; max-width: 720px; color: #8b98a9; font-size: 13px; font-weight: 800; }
.quick-start-status span { display: inline-flex; align-items: center; gap: 8px; white-space: nowrap; }
.quick-start-status b { display: grid; width: 24px; height: 24px; place-items: center; border: 1px solid #c9d3df; border-radius: 50%; background: #fff; font-size: 11px; }
.quick-start-status span.done { color: #0b716a; }.quick-start-status span.done b { border-color: #1a9188; background: #e8f6f3; }.quick-start-status i { flex: 1; height: 1px; margin: 0 10px; background: #d5dfe8; }
.quick-start-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; align-items: stretch; }
.quick-step { display: grid; align-content: start; gap: 15px; min-width: 0; padding: 20px; border: 1px solid #d9e1e9; border-radius: 6px; background: #fff; }
.quick-step-heading { display: grid; grid-template-columns: 34px minmax(0, 1fr) auto; gap: 10px; align-items: start; }.quick-step-heading > span { display: grid; width: 28px; height: 28px; place-items: center; border-radius: 50%; background: #e8f5f3; color: #0b7068; font-size: 11px; font-weight: 900; }.quick-step-heading h4 { margin: 3px 0 0; color: #172033; font-size: 17px; }.quick-step > p { min-height: 44px; margin: 0; color: #657287; line-height: 1.55; }
.quick-form { display: grid; gap: 11px; }.quick-form label, .quick-settings-form label { display: grid; gap: 5px; color: #657287; font-size: 11px; font-weight: 800; }.quick-form button { margin-top: 4px; }
.quick-result, .quick-secret { display: grid; gap: 5px; padding-top: 13px; border-top: 1px solid #e0e6ed; }.quick-result span, .quick-secret span { color: #748195; font-size: 11px; font-weight: 800; }.quick-result code, .quick-secret code { overflow: hidden; color: #173c53; font-size: 12px; overflow-wrap: anywhere; }.quick-secret { border-left: 3px solid #d39c12; padding: 11px; background: #fff9e9; }.quick-secret button { justify-self: start; }
.quick-connect-step { background: #f8fbfb; }.quick-connect-step pre { min-height: 118px; margin: 0; padding: 14px; overflow: auto; border-radius: 5px; background: #101827; color: #d7f2ea; font-size: 11px; line-height: 1.6; }.quick-connect-actions { display: flex; flex-wrap: wrap; gap: 8px; }
.quick-settings { display: grid; grid-template-columns: minmax(0, .85fr) minmax(320px, 1.15fr); gap: 26px; padding: 26px; border: 1px solid #d9e1e9; border-radius: 6px; background: #fff; }.quick-settings h4 { margin: 4px 0 9px; color: #172033; font-size: 20px; }.quick-settings-copy p:last-child { margin: 0; color: #657287; line-height: 1.6; }.quick-settings-form { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; align-content: start; }.quick-settings-form button { align-self: end; }.quick-settings-saved { grid-column: 1 / -1; margin: 0; color: #087068; font-weight: 800; }
@media (max-width: 1180px) { .quick-start-grid { grid-template-columns: 1fr 1fr; }.quick-connect-step { grid-column: span 2; }.quick-settings { grid-template-columns: 1fr; } }
@media (max-width: 700px) { .quick-start-header { align-items: stretch; flex-direction: column; }.quick-start-tabs { align-self: start; }.quick-start-grid, .quick-settings-form { grid-template-columns: 1fr; }.quick-connect-step { grid-column: span 1; }.quick-step > p { min-height: 0; }.quick-settings { padding: 18px; }.quick-start-status { overflow-x: auto; }.quick-start-status i { min-width: 22px; }.quick-start-status span { font-size: 12px; } }
</style>
