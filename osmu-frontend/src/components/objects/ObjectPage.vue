<template>
  <section id="storage-workbench" class="content-grid single-page-grid">
    <article class="panel object-panel" data-testid="object-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Objects</p>
          <h3>파일 탐색기</h3>
        </div>
        <strong class="bucket-label">{{ selectedBucket || '버킷 선택' }}</strong>
      </div>

      <form class="inline-form object-filter" data-testid="object-filter-form" @submit.prevent="$emit('load-objects')">
        <input
          data-testid="object-prefix-input"
          :value="objectPrefix"
          placeholder="prefix: images/"
          :disabled="!selectedBucket"
          @input="$emit('update-object-prefix', $event.target.value)"
        />
        <input
          data-testid="object-search-input"
          :value="objectSearch"
          placeholder="검색: report"
          :disabled="!selectedBucket"
          @input="$emit('update-object-search', $event.target.value)"
        />
        <input
          data-testid="object-tag-filter-input"
          :value="objectTagFilter"
          placeholder="tag: project=osmu"
          :disabled="!selectedBucket"
          @input="$emit('update-object-tag-filter', $event.target.value)"
        />
        <select
          data-testid="object-list-limit-select"
          :value="objectListLimit"
          :disabled="!selectedBucket"
          @change="$emit('update-object-list-limit', Number($event.target.value)); $emit('load-objects')"
        >
          <option v-for="limit in objectListLimitOptions" :key="limit" :value="limit">{{ limit }}개</option>
        </select>
        <button data-testid="object-search-button" type="submit" :disabled="!selectedBucket">검색</button>
        <button type="button" class="ghost" :disabled="!objectPrefix" @click="$emit('object-prefix-up')">상위</button>
        <button
          type="button"
          class="ghost"
          :disabled="!objectPrefix && !objectSearch && !objectTagFilter"
          @click="$emit('reset-object-filter')"
        >
          초기화
        </button>
      </form>

      <div class="segmented-control" role="tablist" aria-label="Object view">
        <button
          type="button"
          :class="{ active: objectViewMode === 'active' }"
          :disabled="!selectedBucket"
          @click="$emit('change-object-view-mode', 'active')"
        >
          Active
        </button>
        <button
          type="button"
          :class="{ active: objectViewMode === 'trash' }"
          :disabled="!selectedBucket"
          @click="$emit('change-object-view-mode', 'trash')"
        >
          Trash
        </button>
      </div>

      <nav class="prefix-breadcrumb" aria-label="Object prefix">
        <button
          v-for="crumb in objectPrefixBreadcrumbs"
          :key="crumb.prefix"
          type="button"
          class="ghost"
          :disabled="crumb.prefix === objectPrefix"
          @click="$emit('select-object-prefix', crumb.prefix)"
        >
          {{ crumb.label }}
        </button>
      </nav>

      <section v-if="!selectedBucket" class="empty-state-panel object-empty-state" data-testid="object-empty-state">
        <strong>버킷을 먼저 선택하세요.</strong>
        <small>Storage 페이지에서 버킷을 만들거나 선택하면 파일 업로드, 검색, 공유 링크, 버전 관리가 활성화됩니다.</small>
      </section>

      <form class="inline-form object-form" data-testid="object-upload-form" @submit.prevent="$emit('upload-object')">
        <input data-testid="object-key-input" v-model="objectForm.key" placeholder="images/sample.png" :disabled="!selectedBucket" />
        <input data-testid="object-tags-input" v-model="objectForm.tags" placeholder="tags: project=osmu,stage=raw" :disabled="!selectedBucket" />
        <input data-testid="object-file-input" type="file" :disabled="!selectedBucket || uploadState.active" @change="$emit('file-change', $event)" />
        <button data-testid="object-upload-button" type="submit" :disabled="!canSubmitUpload">
          {{ uploadState.active ? '업로드 중' : '업로드' }}
        </button>
        <button data-testid="object-upload-cancel-button" type="button" class="ghost" :disabled="!uploadState.active" @click="$emit('cancel-upload')">
          취소
        </button>
        <button data-testid="object-upload-retry-button" type="button" class="ghost" :disabled="!canRetryUpload" @click="$emit('retry-upload')">
          재시도
        </button>
      </form>

      <div
        v-if="uploadState.active || uploadState.retryable"
        class="upload-progress"
        data-testid="object-upload-progress"
        role="status"
        aria-live="polite"
      >
        <div>
          <strong>{{ uploadState.percent }}%</strong>
          <span>{{ formatBytes(uploadState.loadedBytes) }} / {{ formatBytes(uploadState.totalBytes) }}</span>
        </div>
        <progress :value="uploadState.percent" max="100"></progress>
        <p v-if="uploadState.message">{{ uploadState.message }}</p>
      </div>

      <section v-if="visibleMultipartResumeSessions.length > 0" class="resume-panel" aria-label="Pending multipart uploads">
        <div class="resume-panel-head">
          <strong>Pending multipart</strong>
          <span>{{ visibleMultipartResumeSessions.length }}</span>
        </div>
        <ul>
          <li v-for="session in visibleMultipartResumeSessions" :key="session.storageKey" :class="{ expired: session.expired }">
            <span class="list-main">
              <b>{{ session.key }}</b>
              <small>
                {{ session.fileName }} / {{ formatBytes(session.fileSize) }} /
                {{ session.completedParts.length }} of {{ session.partCount || '-' }} parts /
                {{ formatMultipartResumeStatus(session) }}
              </small>
            </span>
            <span class="resume-actions">
              <button
                type="button"
                class="ghost"
                :disabled="session.expired || !isMatchingResumeSession(session)"
                @click="$emit('resume-matching-multipart-upload', session)"
              >
                Resume
              </button>
              <button type="button" class="danger" @click="$emit('discard-multipart-resume', session.storageKey)">Delete</button>
            </span>
          </li>
        </ul>
      </section>

      <form class="inline-form tag-form" @submit.prevent="$emit('update-object-tags')">
        <input v-model="objectTagForm.key" placeholder="tag target key" :disabled="!selectedBucket" />
        <input v-model="objectTagForm.tags" placeholder="tags: project=osmu,stage=raw" :disabled="!selectedBucket" />
        <button type="submit" :disabled="!selectedBucket || !objectTagForm.key">태그 저장</button>
        <button
          type="button"
          class="ghost"
          :disabled="!objectTagForm.key && !objectTagForm.tags"
          @click="$emit('reset-object-tag-form')"
        >
          취소
        </button>
      </form>

      <p v-if="presignedUrl" class="secret-box">Presigned URL: {{ presignedUrl }}</p>

      <div class="table-wrap">
        <table data-testid="object-table">
          <thead>
            <tr>
              <th>키</th>
              <th>크기</th>
              <th>타입</th>
              <th>태그</th>
              <th>작업</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="prefix in objectPrefixes" :key="`prefix-${prefix}`" class="folder-row">
              <td>{{ formatPrefixName(prefix) }}</td>
              <td>-</td>
              <td>prefix</td>
              <td>-</td>
              <td class="actions">
                <button type="button" class="ghost" @click="$emit('open-object-prefix', prefix)">열기</button>
              </td>
            </tr>
            <tr v-for="object in objects" :key="object.key">
              <td>
                <span
                  v-for="(part, index) in objectKeyParts(object.key)"
                  :key="`${object.key}-${index}`"
                  :class="{ 'key-match': part.match }"
                >
                  {{ part.text }}
                </span>
                <small v-if="objectViewMode === 'trash'" class="object-subtext">
                  Deleted {{ formatDateTime(object.deletedAt) }}
                </small>
              </td>
              <td>{{ formatBytes(object.sizeBytes) }}</td>
              <td>{{ object.contentType || '-' }}</td>
              <td>{{ formatObjectTags(object.tags) }}</td>
              <td class="actions">
                <button v-if="objectViewMode === 'active'" type="button" class="ghost" @click="$emit('download-object', object.key)">다운로드</button>
                <button v-if="objectViewMode === 'active'" type="button" class="ghost" @click="$emit('create-presigned-download-url', object.key)">URL</button>
                <button v-if="objectViewMode === 'active'" type="button" class="ghost" @click="$emit('start-object-tag-edit', object)">태그</button>
                <button
                  data-testid="object-detail-button"
                  v-if="objectViewMode === 'active'"
                  type="button"
                  class="ghost"
                  @click="$emit('load-object-metadata', object.key)"
                >
                  상세
                </button>
                <button
                  data-testid="object-share-link-button"
                  v-if="objectViewMode === 'active'"
                  type="button"
                  class="ghost"
                  @click="$emit('create-object-share-link', object.key)"
                >
                  공유
                </button>
                <button v-if="objectViewMode === 'active'" type="button" class="ghost" @click="$emit('load-object-versions', object.key)">Versions</button>
                <button v-if="objectViewMode === 'active'" type="button" class="danger" @click="$emit('delete-object', object.key)">삭제</button>
                <button v-if="objectViewMode === 'trash'" type="button" class="ghost" @click="$emit('restore-object', object.key)">Restore</button>
                <button v-if="objectViewMode === 'trash'" type="button" class="danger" @click="$emit('purge-object', object.key)">Purge</button>
              </td>
            </tr>
            <tr v-if="objects.length === 0 && objectPrefixes.length === 0">
              <td colspan="5" class="empty">선택한 조건에 맞는 파일이 없습니다.</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="panel-actions" v-if="objects.length > 0 || objectPrefixes.length > 0">
        <button type="button" class="ghost" :disabled="!objectNextCursor" @click="$emit('load-next-objects')">다음 항목</button>
      </div>

      <section v-if="objectMetadata" class="object-detail-panel" data-testid="object-detail-panel">
        <div class="panel-head slim">
          <div>
            <p class="eyebrow">Object Detail</p>
            <h3>{{ objectMetadata.key }}</h3>
          </div>
          <div class="detail-actions">
            <span :class="['status-pill', metadataStatusClass(objectMetadata.syncStatus)]">
              {{ metadataStatusLabel(objectMetadata.syncStatus) }}
            </span>
            <button type="button" class="ghost" @click="$emit('close-object-metadata')">닫기</button>
          </div>
        </div>
        <dl class="detail-grid">
          <div v-for="row in objectMetadataRows" :key="row.label">
            <dt>
              <span>{{ row.label }}</span>
              <small
                :class="['metadata-row-state', `metadata-row-state-${row.state || 'unknown'}`]"
                data-testid="object-metadata-row-state"
              >
                {{ objectMetadataRowStateLabel(row.state) }}
              </small>
            </dt>
            <dd>{{ row.value }}</dd>
          </div>
        </dl>
      </section>

      <section v-if="objectShareLinks.key" class="object-detail-panel" data-testid="object-share-link-panel">
        <div class="panel-head slim">
          <div>
            <p class="eyebrow">Share Links</p>
            <h3>{{ objectShareLinks.key }}</h3>
          </div>
          <button data-testid="object-share-link-cleanup-button" type="button" class="ghost" :disabled="objectShareLinks.pending" @click="$emit('cleanup-object-share-links')">
            만료 정리
          </button>
        </div>
        <div class="inline-form share-form">
          <input
            data-testid="object-share-link-password-input"
            :value="shareLinkPassword"
            type="password"
            placeholder="optional password"
            @input="$emit('update-share-link-password', $event.target.value)"
          />
          <input
            data-testid="object-share-link-ip-allowlist-input"
            :value="shareLinkAllowedIpCidrs"
            placeholder="10.0.0.0/8,192.168.0.0/16"
            @input="$emit('update-share-link-allowed-ip-cidrs', $event.target.value)"
          />
          <button type="button" :disabled="objectShareLinks.pending" @click="$emit('create-object-share-link', objectShareLinks.key)">새 링크</button>
        </div>
        <p v-if="shareLinkUrl" class="secret-box" data-testid="object-share-link-url">{{ shareLinkUrl }}</p>
        <ul class="compact-list">
          <li v-for="link in objectShareLinks.items" :key="link.id">
            <span class="list-main">
              <b>{{ link.status || 'ACTIVE' }}</b>
              <small>{{ link.url || link.publicUrl || '-' }}</small>
            </span>
            <span class="key-actions">
              <small>{{ link.downloadCount || 0 }} / {{ link.maxDownloads || '-' }}</small>
              <button type="button" class="danger" @click="$emit('revoke-object-share-link', link.id)">해제</button>
            </span>
          </li>
          <li v-if="objectShareLinks.items.length === 0" class="empty">공유 링크 없음</li>
        </ul>
      </section>

      <section v-if="objectVersions.key" class="object-detail-panel">
        <div class="panel-head slim">
          <div>
            <p class="eyebrow">Object Versions</p>
            <h3>{{ objectVersions.key }}</h3>
          </div>
          <button type="button" class="ghost" @click="$emit('close-object-versions')">닫기</button>
        </div>
        <ul class="compact-list version-list">
          <li v-for="version in objectVersions.items" :key="version.versionId">
            <span class="list-main">
              <b>{{ formatDateTime(version.createdAt) }}</b>
              <small>{{ version.versionId }} / {{ formatBytes(version.sizeBytes) }} / {{ version.contentType }}</small>
            </span>
            <span class="version-actions">
              <button type="button" class="ghost" :disabled="objectVersions.pending" @click="$emit('download-object-version', version.versionId)">Download</button>
              <button type="button" class="ghost" :disabled="objectVersions.pending" @click="$emit('restore-object-version', version.versionId)">Restore</button>
              <button type="button" class="danger" :disabled="objectVersions.pending" @click="$emit('delete-object-version', version.versionId)">Delete</button>
            </span>
          </li>
          <li v-if="objectVersions.items.length === 0" class="empty">Version 없음</li>
        </ul>
      </section>
    </article>
  </section>
</template>

<script setup>
defineProps({
  selectedBucket: { type: String, required: true },
  objectPrefix: { type: String, required: true },
  objectSearch: { type: String, required: true },
  objectTagFilter: { type: String, required: true },
  objectListLimit: { type: Number, required: true },
  objectListLimitOptions: { type: Array, required: true },
  objectViewMode: { type: String, required: true },
  objectPrefixBreadcrumbs: { type: Array, required: true },
  objectForm: { type: Object, required: true },
  objectTagForm: { type: Object, required: true },
  uploadState: { type: Object, required: true },
  canSubmitUpload: { type: Boolean, required: true },
  canRetryUpload: { type: Boolean, required: true },
  visibleMultipartResumeSessions: { type: Array, required: true },
  objectPrefixes: { type: Array, required: true },
  objects: { type: Array, required: true },
  objectNextCursor: { type: String, required: true },
  objectMetadata: { type: Object, default: null },
  objectMetadataRows: { type: Array, required: true },
  objectShareLinks: { type: Object, required: true },
  shareLinkPassword: { type: String, required: true },
  shareLinkAllowedIpCidrs: { type: String, required: true },
  shareLinkUrl: { type: String, required: true },
  objectVersions: { type: Object, required: true },
  presignedUrl: { type: String, required: true },
  formatBytes: { type: Function, required: true },
  formatMultipartResumeStatus: { type: Function, required: true },
  isMatchingResumeSession: { type: Function, required: true },
  formatPrefixName: { type: Function, required: true },
  objectKeyParts: { type: Function, required: true },
  formatDateTime: { type: Function, required: true },
  formatObjectTags: { type: Function, required: true },
  metadataStatusClass: { type: Function, required: true },
  metadataStatusLabel: { type: Function, required: true },
})

defineEmits([
  'update-object-prefix',
  'update-object-search',
  'update-object-tag-filter',
  'update-object-list-limit',
  'update-share-link-password',
  'update-share-link-allowed-ip-cidrs',
  'load-objects',
  'object-prefix-up',
  'reset-object-filter',
  'change-object-view-mode',
  'select-object-prefix',
  'file-change',
  'upload-object',
  'cancel-upload',
  'retry-upload',
  'resume-matching-multipart-upload',
  'discard-multipart-resume',
  'update-object-tags',
  'reset-object-tag-form',
  'open-object-prefix',
  'download-object',
  'create-presigned-download-url',
  'start-object-tag-edit',
  'load-object-metadata',
  'create-object-share-link',
  'load-object-versions',
  'delete-object',
  'restore-object',
  'purge-object',
  'load-next-objects',
  'close-object-metadata',
  'cleanup-object-share-links',
  'revoke-object-share-link',
  'close-object-versions',
  'download-object-version',
  'restore-object-version',
  'delete-object-version',
])

function objectMetadataRowStateLabel(state) {
  if (state === 'synced') return 'Synced'
  if (state === 'drift') return 'Drift'
  if (state === 'missing') return 'Missing'
  return 'Unknown'
}
</script>
