<template>
  <section class="docs-page" data-testid="dev-docs-page">
    <header class="docs-toolbar">
      <div>
        <p class="eyebrow">OSMU Documentation</p>
        <h3>사람과 AI를 위한 운영 안내서</h3>
        <p>필요한 역할과 주제를 선택하면 해당 안내서만 집중해서 읽을 수 있습니다.</p>
      </div>
      <button type="button" class="ghost" data-testid="copy-ai-context-button" @click="copyAiContext">
        {{ copyLabel }}
      </button>
    </header>

    <div class="docs-browser">
      <aside class="docs-catalog" aria-label="문서 탐색">
        <label class="docs-search">
          <span>문서 검색</span>
          <input
            v-model.trim="searchQuery"
            data-testid="dev-docs-search"
            type="search"
            placeholder="버킷, RAID, 권한, 오류 코드..."
          />
        </label>

        <label class="role-filter">
          <span>사용자 역할</span>
          <select v-model="activeRole" data-testid="dev-docs-role-filter">
            <option v-for="role in documentationRoles" :key="role.id" :value="role.id">
              {{ role.label }}
            </option>
          </select>
        </label>

        <nav class="docs-nav" aria-label="안내서 목록">
          <button
            type="button"
            :class="['docs-nav-item', { active: activeDocumentId === 'overview' }]"
            data-testid="dev-docs-nav-overview"
            @click="selectDocument('overview')"
          >
            <span class="docs-nav-icon">⌂</span>
            <span><strong>문서 홈</strong><small>구조와 역할 한눈에 보기</small></span>
          </button>

          <template v-for="group in groupedSections" :key="group.name">
            <p class="docs-nav-group">{{ group.name }}</p>
            <button
              v-for="section in group.sections"
              :key="section.id"
              type="button"
              :class="['docs-nav-item', { active: activeDocumentId === section.id }]"
              :data-testid="`dev-docs-nav-${section.id}`"
              @click="selectDocument(section.id)"
            >
              <span><strong>{{ section.title }}</strong><small>{{ section.summary }}</small></span>
            </button>
          </template>
        </nav>

        <div v-if="filteredSections.length === 0" class="docs-empty" role="status">
          <strong>검색 결과가 없습니다</strong>
          <span>검색어를 줄이거나 역할을 전체 문서로 변경하세요.</span>
        </div>
      </aside>

      <main ref="reader" class="docs-reader" tabindex="-1">
        <article v-if="activeDocumentId === 'overview'" class="overview-document">
          <header class="article-header">
            <p class="eyebrow">Documentation home</p>
            <h1>OSMU 사용 가이드</h1>
            <p>OSMU의 구조를 먼저 이해한 뒤 왼쪽에서 역할별 작업을 선택하세요. 한 화면에는 하나의 주제만 표시됩니다.</p>
            <div class="article-stats" aria-label="문서 통계">
              <span><strong>{{ documentationSections.length }}</strong>개 안내서</span>
              <span><strong>{{ documentationRoles.length - 1 }}</strong>개 역할</span>
              <span><strong>Human + AI</strong> 공용</span>
            </div>
          </header>

          <section class="overview-section" aria-labelledby="system-map-title">
            <div class="section-heading">
              <p class="eyebrow">System map</p>
              <h2 id="system-map-title">요청이 저장소에 도착하는 경로</h2>
            </div>
            <div class="system-flow" aria-label="OSMU 시스템 흐름도">
              <div class="flow-node"><span>01</span><strong>사용자 · SDK</strong><small>Portal / S3 API</small></div>
              <b aria-hidden="true">→</b>
              <div class="flow-node emphasis"><span>02</span><strong>OSMU Backend</strong><small>인증 / 정책 / 감사</small></div>
              <b aria-hidden="true">→</b>
              <div class="flow-node"><span>03</span><strong>Object Storage</strong><small>Bucket / Object</small></div>
              <b aria-hidden="true">↕</b>
              <div class="flow-node warning"><span>04</span><strong>Kubernetes PVC</strong><small>Layout simulation</small></div>
            </div>
          </section>

          <div class="overview-grid">
            <section class="overview-section role-overview" aria-labelledby="role-matrix-title">
              <div class="section-heading">
                <p class="eyebrow">Role matrix</p>
                <h2 id="role-matrix-title">역할별 권한</h2>
              </div>
              <div class="table-wrap">
                <table data-testid="dev-docs-role-matrix">
                  <thead><tr><th>기능</th><th>USER</th><th>ADMIN</th><th>ORG</th><th>AUDIT</th></tr></thead>
                  <tbody>
                    <tr v-for="row in roleCapabilities" :key="row.capability">
                      <td>{{ row.capability }}</td>
                      <td v-for="role in matrixRoles" :key="role">
                        <span :class="['matrix-state', row[role] ? 'allowed' : 'blocked']">{{ row[role] ? '가능' : '제한' }}</span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>

            <section class="overview-section profile-overview" aria-labelledby="profile-layout-title">
              <div class="section-heading">
                <p class="eyebrow">Profile to layout</p>
                <h2 id="profile-layout-title">데이터 성격별 선택</h2>
              </div>
              <div class="profile-list">
                <div><span class="risk high">HIGH RISK</span><strong>Performance</strong><small>JBOD · RAID0-like</small></div>
                <div><span class="risk medium">BALANCED</span><strong>Standard</strong><small>RAID5 · RAID10-like</small></div>
                <div><span class="risk low">DURABLE</span><strong>Durable</strong><small>RAID1 · RAID6-like</small></div>
              </div>
            </section>
          </div>

          <section class="overview-section" aria-labelledby="visual-example-title">
            <div class="section-heading visual-heading">
              <div><p class="eyebrow">Visual walkthrough</p><h2 id="visual-example-title">실제 화면 예시</h2></div>
              <p>이미지를 선택하면 원본 크기로 확인할 수 있습니다.</p>
            </div>
            <div class="visual-examples">
              <a href="/dev-docs/admin-storage-layout.png" target="_blank" rel="noreferrer">
                <img src="/dev-docs/admin-storage-layout.png" alt="관리자 Storage Layout 시뮬레이션 화면" />
                <span><strong>관리자 Layout plan</strong><small>Simulate와 preflight 상태 확인</small></span>
              </a>
              <a href="/dev-docs/user-storage-profile.png" target="_blank" rel="noreferrer">
                <img src="/dev-docs/user-storage-profile.png" alt="사용자 Storage Profile 적용 결과 화면" />
                <span><strong>사용자 Profile 결과</strong><small>APPLIED와 Layout 연결 확인</small></span>
              </a>
            </div>
          </section>
        </article>

        <article
          v-else-if="activeSection"
          :key="activeSection.id"
          :data-testid="`dev-docs-section-${activeSection.id}`"
          class="guide-document"
        >
          <header class="article-header">
            <p class="article-breadcrumb">Dev-Docs / {{ activeSection.group }}</p>
            <h1>{{ activeSection.title }}</h1>
            <p>{{ activeSection.summary }}</p>
            <div class="role-tags" aria-label="이 문서의 대상 역할">
              <span v-for="role in displayRoles(activeSection.roles)" :key="role">{{ role }}</span>
            </div>
          </header>

          <section class="article-section" aria-labelledby="procedure-title">
            <div class="section-heading"><p class="eyebrow">Procedure</p><h2 id="procedure-title">작업 순서</h2></div>
            <ol class="procedure-list">
              <li v-for="(step, stepIndex) in activeSection.steps" :key="step">
                <span>{{ stepIndex + 1 }}</span><p>{{ step }}</p>
              </li>
            </ol>
          </section>

          <section v-if="activeSection.details?.length" class="article-section" aria-labelledby="details-title">
            <div class="section-heading"><p class="eyebrow">Details</p><h2 id="details-title">알아두기</h2></div>
            <ul class="detail-list"><li v-for="detail in activeSection.details" :key="detail">{{ detail }}</li></ul>
          </section>

          <aside v-if="activeSection.warning" class="warning-block" role="note">
            <strong>주의</strong><p>{{ activeSection.warning }}</p>
          </aside>

          <section v-if="activeSection.code" class="article-section" aria-labelledby="example-title">
            <div class="section-heading"><p class="eyebrow">Example</p><h2 id="example-title">실행 예제</h2></div>
            <div class="code-example"><div><span>Example</span><small>주소와 비밀값은 환경에 맞게 교체하세요.</small></div><pre><code>{{ activeSection.code }}</code></pre></div>
          </section>

          <footer class="article-pagination">
            <button v-if="previousSection" type="button" class="ghost" @click="selectDocument(previousSection.id)">
              <small>이전 문서</small><span>← {{ previousSection.title }}</span>
            </button>
            <span v-else></span>
            <button v-if="nextSection" type="button" class="ghost next" @click="selectDocument(nextSection.id)">
              <small>다음 문서</small><span>{{ nextSection.title }} →</span>
            </button>
          </footer>
        </article>

        <div v-else class="reader-empty">
          <strong>표시할 문서가 없습니다.</strong><p>검색 조건을 변경하고 왼쪽에서 문서를 선택하세요.</p>
        </div>
      </main>
    </div>
  </section>
</template>

<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import { aiContextTemplate, documentationRoles, documentationSections, roleCapabilities } from '@/docs/osmuGuide'

const matrixRoles = ['USER', 'ADMIN', 'ORG_ADMIN', 'AUDITOR']
const activeRole = ref('ALL')
const activeDocumentId = ref('overview')
const searchQuery = ref('')
const copyLabel = ref('AI 컨텍스트 복사')
const reader = ref(null)

const filteredSections = computed(() => {
  const query = searchQuery.value.toLocaleLowerCase('ko-KR')
  return documentationSections.filter((section) => {
    const roleMatch = activeRole.value === 'ALL' || section.roles.includes(activeRole.value)
    if (!roleMatch) return false
    if (!query) return true
    return [section.group, section.title, section.summary, ...(section.steps || []), ...(section.details || []), section.warning || '', section.code || '']
      .join(' ').toLocaleLowerCase('ko-KR').includes(query)
  })
})

const groupedSections = computed(() => {
  const groups = []
  for (const section of filteredSections.value) {
    let group = groups.find((entry) => entry.name === section.group)
    if (!group) {
      group = { name: section.group, sections: [] }
      groups.push(group)
    }
    group.sections.push(section)
  }
  return groups
})

const activeSection = computed(() => documentationSections.find((section) => section.id === activeDocumentId.value) || null)
const activeSectionIndex = computed(() => filteredSections.value.findIndex((section) => section.id === activeDocumentId.value))
const previousSection = computed(() => activeSectionIndex.value > 0 ? filteredSections.value[activeSectionIndex.value - 1] : null)
const nextSection = computed(() => activeSectionIndex.value >= 0 ? filteredSections.value[activeSectionIndex.value + 1] || null : filteredSections.value[0] || null)

watch([activeRole, searchQuery], () => {
  if (activeDocumentId.value === 'overview') return
  if (!filteredSections.value.some((section) => section.id === activeDocumentId.value)) activeDocumentId.value = filteredSections.value[0]?.id || 'overview'
})

function displayRoles(roles) {
  if (roles.includes('ALL')) return ['모든 사용자']
  return roles
}

async function selectDocument(id) {
  activeDocumentId.value = id
  await nextTick()
  reader.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  reader.value?.focus({ preventScroll: true })
}

async function copyAiContext() {
  try {
    await navigator.clipboard.writeText(aiContextTemplate)
    copyLabel.value = '복사 완료'
  } catch {
    copyLabel.value = '복사 실패'
  }
  window.setTimeout(() => { copyLabel.value = 'AI 컨텍스트 복사' }, 1800)
}
</script>

<style scoped>
.docs-page { min-width: 0; color: #172033; }
.docs-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 20px; padding: 2px 0 18px; }
.docs-toolbar h3 { margin: 3px 0 5px; color: #172033; font-size: 21px; letter-spacing: 0; }
.docs-toolbar p:last-child { margin: 0; color: #667388; line-height: 1.5; }
.docs-browser { display: grid; grid-template-columns: 280px minmax(0, 1fr); min-height: calc(100vh - 250px); border: 1px solid #d7dfe9; background: #fff; }
.docs-catalog { position: sticky; top: 0; min-width: 0; max-height: 100vh; padding: 18px 14px; overflow-y: auto; border-right: 1px solid #d7dfe9; background: #f7f9fb; }
.docs-search, .role-filter { display: grid; gap: 6px; margin: 0 4px 14px; color: #5b687c; font-size: 11px; font-weight: 900; }
.docs-search input, .role-filter select { min-height: 38px; background: #fff; }
.docs-nav { display: grid; gap: 3px; }
.docs-nav-group { margin: 20px 10px 6px; color: #8994a4; font-size: 10px; font-weight: 900; text-transform: uppercase; }
.docs-nav-item { display: grid; grid-template-columns: minmax(0, 1fr); width: 100%; min-height: 0; padding: 10px; border-left: 3px solid transparent; border-radius: 4px; background: transparent; color: #344055; text-align: left; white-space: normal; }
.docs-nav-item:has(.docs-nav-icon) { grid-template-columns: 22px minmax(0, 1fr); }
.docs-nav-item:hover { background: #edf2f6; color: #172033; }
.docs-nav-item.active { border-left-color: #16877f; background: #e7f3f1; color: #0b625c; }
.docs-nav-item > span:not(.docs-nav-icon) { display: grid; gap: 3px; min-width: 0; }
.docs-nav-item strong { font-size: 12px; line-height: 1.35; }
.docs-nav-item small { display: -webkit-box; overflow: hidden; color: #758195; font-size: 10px; font-weight: 600; line-height: 1.35; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
.docs-nav-icon { color: #16877f; font-size: 15px; }
.docs-empty, .reader-empty { display: grid; gap: 5px; padding: 18px; color: #68758a; }
.docs-empty span { font-size: 12px; line-height: 1.5; }
.docs-reader { min-width: 0; max-width: 1120px; padding: 38px clamp(28px, 5vw, 72px) 60px; outline: none; }
.article-header { max-width: 820px; padding-bottom: 28px; border-bottom: 1px solid #dce3eb; }
.article-header h1 { margin: 5px 0 10px; color: #111c2e; font-size: 32px; line-height: 1.18; letter-spacing: 0; }
.article-header > p:last-of-type { margin: 0; color: #596579; font-size: 15px; line-height: 1.7; }
.article-breadcrumb { margin: 0 0 12px; color: #178078; font-size: 12px; font-weight: 800; }
.article-stats, .role-tags { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 20px; }
.article-stats span, .role-tags span { padding: 6px 9px; border: 1px solid #d7e0e8; border-radius: 4px; background: #f7f9fb; color: #536075; font-size: 11px; font-weight: 700; }
.article-stats strong { color: #0e6d66; }
.overview-section, .article-section { padding: 30px 0; border-bottom: 1px solid #e0e6ed; }
.section-heading h2 { margin: 4px 0 0; color: #172033; font-size: 20px; letter-spacing: 0; }
.eyebrow { margin: 0; }
.system-flow { display: grid; grid-template-columns: minmax(110px, 1fr) auto minmax(110px, 1fr) auto minmax(110px, 1fr) auto minmax(110px, 1fr); gap: 8px; align-items: center; margin-top: 20px; }
.system-flow > b { color: #92a0b2; }
.flow-node { display: grid; min-height: 96px; align-content: center; gap: 4px; padding: 12px; border: 1px solid #d3dce6; border-radius: 5px; }
.flow-node span { color: #8290a2; font-size: 10px; font-weight: 900; }
.flow-node small { color: #6b788b; font-size: 11px; }
.flow-node.emphasis { border-color: #48a59d; background: #eff8f7; }
.flow-node.warning { border-color: #dfbd62; background: #fff9e8; }
.overview-grid { display: grid; grid-template-columns: minmax(0, 1.4fr) minmax(250px, .6fr); gap: 34px; }
.table-wrap { margin-top: 16px; overflow-x: auto; }
.table-wrap table { min-width: 560px; font-size: 11px; }
.table-wrap th, .table-wrap td { padding: 9px 8px; }
.matrix-state { font-size: 10px; font-weight: 900; }
.matrix-state.allowed { color: #087068; }
.matrix-state.blocked { color: #a1484a; }
.profile-list { display: grid; gap: 1px; margin-top: 16px; background: #dce3ea; border: 1px solid #dce3ea; }
.profile-list > div { display: grid; gap: 4px; padding: 13px; background: #fff; }
.profile-list small { color: #68758a; }
.risk { font-size: 9px; font-weight: 900; }
.risk.high { color: #a23f43; } .risk.medium { color: #946a00; } .risk.low { color: #087068; }
.visual-heading { display: flex; align-items: end; justify-content: space-between; gap: 20px; }
.visual-heading > p { margin: 0; color: #738094; font-size: 11px; }
.visual-examples { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; margin-top: 18px; }
.visual-examples a { overflow: hidden; border: 1px solid #d7dfe8; border-radius: 5px; background: #fff; }
.visual-examples img { display: block; width: 100%; aspect-ratio: 16 / 8; object-fit: cover; object-position: top; background: #edf1f5; }
.visual-examples a > span { display: grid; gap: 3px; padding: 11px 13px; }
.visual-examples small { color: #6b788c; }
.procedure-list { display: grid; gap: 0; margin: 18px 0 0; padding: 0; list-style: none; border-top: 1px solid #e0e6ed; }
.procedure-list li { display: grid; grid-template-columns: 32px minmax(0, 1fr); gap: 10px; padding: 14px 0; border-bottom: 1px solid #e0e6ed; }
.procedure-list li > span { display: grid; width: 24px; height: 24px; place-items: center; border-radius: 50%; background: #e7f4f2; color: #0c6c65; font-size: 11px; font-weight: 900; }
.procedure-list p { margin: 0; color: #344055; line-height: 1.65; }
.detail-list { display: grid; gap: 10px; margin: 18px 0 0; padding: 18px 20px 18px 38px; border-left: 3px solid #16877f; background: #f1f7f6; color: #425064; line-height: 1.6; }
.warning-block { margin-top: 24px; padding: 16px 18px; border-left: 3px solid #d39c12; background: #fff8e7; }
.warning-block p { margin: 5px 0 0; color: #66511c; line-height: 1.6; }
.code-example { margin-top: 18px; overflow: hidden; border: 1px solid #29374b; border-radius: 5px; background: #101827; }
.code-example > div { display: flex; justify-content: space-between; gap: 12px; padding: 9px 13px; border-bottom: 1px solid #2d3a4e; color: #d6e2ef; }
.code-example small { color: #95a8be; }
.code-example pre { margin: 0; padding: 16px; overflow-x: auto; color: #d8f1ea; font-size: 12px; line-height: 1.65; }
.article-pagination { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; padding-top: 30px; }
.article-pagination button { display: grid; gap: 4px; height: auto; padding: 13px; text-align: left; white-space: normal; }
.article-pagination button.next { text-align: right; }
.article-pagination small { color: #758195; }

@media (max-width: 1100px) { .overview-grid { grid-template-columns: minmax(0, 1fr); gap: 0; } .system-flow { grid-template-columns: repeat(4, minmax(110px, 1fr)); } .system-flow > b { display: none; } }
@media (max-width: 760px) {
  .docs-toolbar { align-items: stretch; flex-direction: column; }
  .docs-toolbar button { align-self: start; }
  .docs-browser { grid-template-columns: minmax(0, 1fr); }
  .docs-catalog { position: static; max-height: none; overflow-y: visible; border-right: 0; border-bottom: 1px solid #d7dfe9; }
  .docs-nav { max-height: 280px; overflow-y: auto; }
  .docs-reader { padding: 28px 18px 44px; }
  .article-header h1 { font-size: 26px; }
  .system-flow, .visual-examples { grid-template-columns: minmax(0, 1fr); }
  .visual-heading { align-items: start; flex-direction: column; }
  .article-pagination { grid-template-columns: minmax(0, 1fr); }
}
</style>
