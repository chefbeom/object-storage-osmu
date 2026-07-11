<template>
  <section class="quick-guide" data-testid="quick-start-guide">
    <div class="quick-guide-heading">
      <div>
        <p class="eyebrow">Easy guide</p>
        <h4>처음 사용하는 방법과 주요 기능</h4>
      </div>
      <span>{{ activeGuide.label }}</span>
    </div>

    <div class="quick-guide-tabs" role="tablist" aria-label="Quick Start guide topics">
      <button
        v-for="guide in guides"
        :key="guide.id"
        type="button"
        :class="{ active: guideTopic === guide.id }"
        :data-testid="`quick-start-guide-${guide.id}`"
        @click="guideTopic = guide.id"
      >
        {{ guide.label }}
      </button>
    </div>

    <div class="quick-guide-content">
      <div>
        <h5>{{ activeGuide.title }}</h5>
        <p>{{ activeGuide.summary }}</p>
        <ol>
          <li v-for="step in activeGuide.steps" :key="step">{{ step }}</li>
        </ol>
      </div>
      <aside>
        <strong>{{ activeGuide.tipTitle }}</strong>
        <p>{{ activeGuide.tip }}</p>
        <code v-if="activeGuide.example">{{ activeGuide.example }}</code>
      </aside>
    </div>
  </section>
</template>

<script setup>
import { computed, ref } from 'vue'

const guideTopic = ref('first')
const guides = [
  {
    id: 'first', label: '처음 사용', title: '저장소 하나를 만들고 첫 파일을 올리기',
    summary: '가장 일반적인 시작 흐름입니다. 버킷은 프로젝트별 파일 보관함이라고 생각하면 됩니다.',
    steps: ['저장소 만들기에 프로젝트 이름을 입력합니다.', 'Access Key 발급에서 읽기 및 쓰기를 선택합니다.', 'Secret Key를 비밀 관리 도구에 한 번만 보관합니다.', '파일 올리기를 눌러 브라우저에서 파일을 업로드하거나 연결 예시를 실행합니다.'],
    tipTitle: '이름 예시', tip: '환경과 용도를 함께 쓰면 나중에 찾기 쉽습니다.', example: 'team-a-assets-dev',
  },
  {
    id: 'files', label: '파일 관리', title: '파일을 올리고 찾고 공유하기',
    summary: 'Quick Start에서 파일 올리기를 누르면 Objects 화면으로 이동합니다. 폴더처럼 보이는 경로도 파일 이름 앞에 붙여 관리합니다.',
    steps: ['파일 올리기에서 대상 파일과 저장 경로를 확인합니다.', '경로에 슬래시를 넣어 폴더처럼 정리합니다.', 'Objects 화면의 검색과 prefix 필터로 파일을 다시 찾습니다.', '외부 전달이 필요하면 만료 시간이 있는 공유 링크를 사용합니다.'],
    tipTitle: '저장 경로 예시', tip: '날짜와 용도를 경로에 넣으면 파일이 많아져도 정리하기 쉽습니다.', example: 'reports/2026/07/summary.pdf',
  },
  {
    id: 'connect', label: '연결 예시', title: '애플리케이션과 명령줄에서 연결하기',
    summary: 'Access Key와 Secret Key를 코드나 환경 변수에 넣고, Quick Start에 표시된 Endpoint를 사용합니다.',
    steps: ['설정에서 AWS CLI 또는 Python 예시를 선택합니다.', '표시된 예시의 버킷 이름이 맞는지 확인합니다.', 'Access Key와 Secret Key는 코드에 직접 넣지 말고 환경 변수나 비밀 관리 도구에 저장합니다.', '먼저 작은 hello.txt 파일로 업로드와 목록 조회를 확인합니다.'],
    tipTitle: '첫 연결 확인', tip: '작은 텍스트 파일을 올린 뒤 목록에 보이는지만 먼저 확인하세요.', example: 'aws s3 ls s3://<YOUR_BUCKET>/ --endpoint-url <ENDPOINT>',
  },
  {
    id: 'security', label: '권한·보안', title: '필요한 권한만 발급하고 Secret Key 지키기',
    summary: 'Access Key는 선택한 버킷에만 연결됩니다. 사용하는 프로그램에 꼭 필요한 권한만 주는 것이 안전합니다.',
    steps: ['업로드가 필요하면 읽기 및 쓰기를 선택합니다.', '다운로드·조회만 하는 서비스는 읽기 전용을 선택합니다.', 'Secret Key는 화면에서 한 번만 확인하고 비밀 관리 도구에 저장합니다.', '키가 노출되었거나 더 이상 필요 없으면 Developer에서 비활성화하거나 Rotate합니다.'],
    tipTitle: '중요', tip: 'Secret Key를 메신저, 문서, Git 저장소에 붙여 넣지 마세요.', example: '',
  },
  {
    id: 'settings', label: '설정', title: '내 작업 방식에 맞게 기본값 바꾸기',
    summary: '설정은 다음 생성 작업에 미리 적용할 기본값입니다. 이미 만들어진 저장소나 Access Key를 바꾸지 않습니다.',
    steps: ['설정 버튼을 눌러 기본 용량을 고릅니다.', '새 키에 기본으로 적용할 권한을 선택합니다.', '사용하는 언어에 맞는 연결 예시를 AWS CLI 또는 Python으로 고릅니다.', '설정 저장을 누르면 현재 브라우저에서 다음 작업에도 유지됩니다.'],
    tipTitle: '설정 범위', tip: '브라우저별 개인 편의 설정이며 서버의 운영 정책은 바꾸지 않습니다.', example: '',
  },
]

const activeGuide = computed(() => guides.find((guide) => guide.id === guideTopic.value) || guides[0])
</script>

<style scoped>
.quick-guide { display: grid; gap: 16px; padding: 22px; border: 1px solid #d9e1e9; border-radius: 6px; background: #ffffff; }
.quick-guide-heading { display: flex; align-items: end; justify-content: space-between; gap: 16px; }.quick-guide-heading h4 { margin: 4px 0 0; color: #172033; font-size: 19px; }.quick-guide-heading > span { padding: 5px 8px; border: 1px solid #c9e0dc; border-radius: 4px; color: #0b7068; font-size: 11px; font-weight: 900; }
.quick-guide-tabs { display: flex; overflow-x: auto; border-bottom: 1px solid #dce3eb; }.quick-guide-tabs button { min-height: 38px; padding: 8px 12px; border-radius: 0; border-bottom: 2px solid transparent; background: transparent; color: #657287; font-size: 12px; }.quick-guide-tabs button.active { border-bottom-color: #16877f; color: #0b7068; background: #f3f9f8; }
.quick-guide-content { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(220px, .75fr); gap: 24px; }.quick-guide-content h5 { margin: 0 0 7px; color: #172033; font-size: 17px; }.quick-guide-content > div > p { margin: 0; color: #657287; line-height: 1.6; }.quick-guide-content ol { display: grid; gap: 9px; margin: 16px 0 0; padding-left: 23px; color: #354155; line-height: 1.55; }.quick-guide-content aside { align-self: start; display: grid; gap: 7px; padding: 15px; border-left: 3px solid #16877f; background: #f1f8f7; }.quick-guide-content aside p { margin: 0; color: #49615e; line-height: 1.55; }.quick-guide-content code { overflow-wrap: anywhere; color: #0c5e58; font-size: 12px; }
@media (max-width: 700px) { .quick-guide { padding: 18px; }.quick-guide-heading { align-items: start; flex-direction: column; }.quick-guide-content { grid-template-columns: 1fr; gap: 16px; } }
</style>
