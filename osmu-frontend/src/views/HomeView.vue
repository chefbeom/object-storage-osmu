<template>
  <main class="shell">
    <aside class="sidebar">
      <div>
        <p class="eyebrow">Private Object Storage</p>
        <h1>OSMU</h1>
        <p class="summary">S3 호환 프라이빗 스토리지 관리 포털</p>
      </div>

      <section class="status-list">
        <div v-for="item in statusItems" :key="item.label" class="status-row">
          <span>{{ item.label }}</span>
          <strong :class="['status-pill', item.value.toLowerCase()]">{{ item.value }}</strong>
        </div>
      </section>

      <form class="login-box" @submit.prevent="handleLogin">
        <label>
          Login ID
          <input v-model="loginForm.loginId" autocomplete="username" />
        </label>
        <label>
          Password
          <input v-model="loginForm.password" type="password" autocomplete="current-password" />
        </label>
        <button type="submit">로그인</button>
        <p v-if="session.user" class="session-text">{{ session.user.name }} / {{ session.user.role }}</p>
      </form>
    </aside>

    <section class="workspace">
      <header class="topbar">
        <div>
          <p class="eyebrow">Dashboard</p>
          <h2>스토리지 운영 현황</h2>
        </div>
        <div class="topbar-actions">
          <button type="button" class="ghost" @click="refreshAll">새로고침</button>
          <button v-if="isLoggedIn" type="button" class="danger" @click="handleLogout">Logout</button>
        </div>
      </header>

      <p v-if="errorMessage" class="alert">
        <span>{{ errorMessage }}</span>
        <small v-if="errorRequestId">Request ID {{ errorRequestId }}</small>
      </p>

      <section class="metrics-grid">
        <article class="metric">
          <span>총 쿼터</span>
          <strong>{{ formatBytes(usage.totalQuotaBytes) }}</strong>
        </article>
        <article class="metric">
          <span>사용량</span>
          <strong>{{ formatBytes(usage.usedBytes) }}</strong>
        </article>
        <article class="metric">
          <span>버킷</span>
          <strong>{{ usage.bucketCount }}</strong>
        </article>
        <article class="metric">
          <span>오브젝트</span>
          <strong>{{ usage.objectCount }}</strong>
        </article>
      </section>

      <section v-if="isAdmin" class="retention-strip">
        <div>
          <p class="eyebrow">Lifecycle</p>
          <strong>Trash retention {{ retentionPolicy.retentionDays || '-' }} days</strong>
          <small>
            {{ retentionPolicy.enabled ? 'Enabled' : 'Disabled' }} /
            batch {{ retentionPolicy.batchSize || '-' }} /
            purged {{ formatCount(retentionPolicy.purgedObjectCount) }} /
            failed {{ formatCount(retentionPolicy.failedObjectCount) }}
            <template v-if="retentionPolicy.lastPurgedCount !== null">
              / last {{ retentionPolicy.lastPurgedCount }}
            </template>
          </small>
        </div>
        <button
          type="button"
          class="ghost"
          :disabled="!retentionPolicy.enabled || retentionPolicy.pending"
          @click="handleRunObjectRetentionPurge"
        >
          {{ retentionPolicy.pending ? 'Running' : 'Run purge' }}
        </button>
      </section>

      <section v-if="isAdmin" class="lifecycle-rules">
        <div class="lifecycle-rules-head">
          <div>
            <p class="eyebrow">Lifecycle Rules</p>
            <strong>{{ lifecycleRules.length }} rules</strong>
          </div>
          <button type="button" class="ghost" @click="resetLifecycleRuleForm">New</button>
        </div>

        <form class="lifecycle-rule-form" @submit.prevent="handleSaveObjectLifecycleRule">
          <input v-model="lifecycleRuleForm.name" placeholder="rule name" />
          <select v-model="lifecycleRuleForm.targetType">
            <option value="OBJECT_VERSION">Object versions</option>
            <option value="TRASH_OBJECT">Trash objects</option>
          </select>
          <label class="check">
            <input v-model="lifecycleRuleForm.enabled" type="checkbox" />
            Enabled
          </label>
          <input v-model.number="lifecycleRuleForm.priority" min="1" max="10000" type="number" placeholder="priority" />
          <input v-model="lifecycleRuleForm.prefix" placeholder="prefix: videos/raw/" />
          <input v-model="lifecycleRuleForm.tags" placeholder="tags: stage=raw,project=osmu" />
          <input v-model.number="lifecycleRuleForm.retentionDays" min="1" max="3650" type="number" />
          <input v-model.number="lifecycleRuleForm.batchSize" min="1" max="10000" type="number" />
          <button type="submit" :disabled="lifecycleRuleForm.pending">
            {{ lifecycleRuleForm.pending ? 'Saving' : 'Save rule' }}
          </button>
        </form>

        <ul class="lifecycle-rule-list">
          <li v-for="rule in lifecycleRules" :key="rule.ruleId">
            <div>
              <strong>{{ rule.name }}</strong>
              <small>
                {{ rule.targetType }} / {{ rule.enabled ? 'Enabled' : 'Disabled' }} /
                priority {{ rule.priority || 100 }} / {{ rule.retentionDays }}d / batch {{ rule.batchSize }}
              </small>
              <small>{{ rule.prefix || '*' }} / {{ formatObjectTags(rule.tags) }}</small>
            </div>
            <div class="rule-actions">
              <button
                type="button"
                class="ghost"
                :disabled="lifecycleRulePreview.pendingRuleId === rule.ruleId"
                @click="handleDryRunObjectLifecycleRule(rule)"
              >
                {{ lifecycleRulePreview.pendingRuleId === rule.ruleId ? 'Checking' : 'Dry run' }}
              </button>
              <button type="button" class="ghost" @click="editLifecycleRule(rule)">Edit</button>
              <button type="button" class="danger" @click="handleDeleteObjectLifecycleRule(rule)">Delete</button>
            </div>
          </li>
          <li v-if="lifecycleRules.length === 0" class="empty">No lifecycle rules</li>
        </ul>

        <div class="lifecycle-conflicts">
          <div>
            <p class="eyebrow">Conflict Report</p>
            <strong>{{ lifecycleRuleConflicts.conflictCount }} overlaps</strong>
            <small>{{ lifecycleRuleConflicts.ruleCount }} enabled rules checked</small>
          </div>
          <button type="button" class="ghost" :disabled="lifecycleRuleConflicts.pending" @click="refreshLifecycleRuleConflicts">
            {{ lifecycleRuleConflicts.pending ? 'Checking' : 'Check' }}
          </button>
          <ul v-if="lifecycleRuleConflicts.conflicts.length > 0">
            <li v-for="conflict in lifecycleRuleConflicts.conflicts" :key="`${conflict.firstRule.ruleId}-${conflict.secondRule.ruleId}`">
              <span>
                {{ conflict.severity }} / {{ conflict.targetType }} /
                {{ conflict.firstRule.name }} -> {{ conflict.secondRule.name }}
              </span>
              <small>{{ conflict.reason }}</small>
            </li>
          </ul>
        </div>

        <div class="lifecycle-xml">
          <div>
            <p class="eyebrow">S3 Lifecycle XML</p>
            <strong>Import / Export</strong>
            <small v-if="lifecycleXml.importedCount !== null">imported {{ lifecycleXml.importedCount }} rules</small>
          </div>
          <div class="rule-actions">
            <button type="button" class="ghost" :disabled="lifecycleXml.pending" @click="handleExportLifecycleXml">
              {{ lifecycleXml.pending ? 'Working' : 'Export' }}
            </button>
            <button type="button" :disabled="lifecycleXml.pending" @click="handleImportLifecycleXml">
              Import
            </button>
          </div>
          <textarea
            v-model="lifecycleXml.content"
            placeholder="<LifecycleConfiguration>..."
            rows="6"
          ></textarea>
        </div>

        <div v-if="lifecycleRulePreview.ruleId" class="lifecycle-preview">
          <div>
            <p class="eyebrow">Dry Run</p>
            <strong>{{ lifecycleRulePreview.ruleName }}</strong>
            <small>
              {{ lifecycleRulePreview.targetType }} /
              {{ lifecycleRulePreview.candidateCount }} candidates /
              {{ formatBytes(lifecycleRulePreview.candidateBytes) }} /
              cutoff {{ formatDateTime(lifecycleRulePreview.cutoff) }}
              <template v-if="lifecycleRulePreview.truncated"> / truncated</template>
            </small>
          </div>
          <ul>
            <li v-for="candidate in lifecycleRulePreview.candidates" :key="candidate.targetId">
              <span>{{ candidate.targetId }}</span>
              <small>{{ formatBytes(candidate.sizeBytes) }} / {{ formatDateTime(candidate.matchedAt) }}</small>
            </li>
            <li v-if="lifecycleRulePreview.candidates.length === 0" class="empty">No matching candidates</li>
          </ul>
        </div>
      </section>

      <section class="content-grid">
        <article class="panel">
          <div class="panel-head">
            <div>
              <p class="eyebrow">Buckets</p>
              <h3>버킷 관리</h3>
            </div>
          </div>

          <form class="inline-form" @submit.prevent="handleCreateBucket">
            <input v-model="bucketForm.name" placeholder="project-data" />
            <input v-model.number="bucketForm.quotaGb" min="1" type="number" />
            <select v-model="bucketForm.ownerType" :disabled="!canCreateOrgBucket">
              <option value="USER">My user</option>
              <option value="ORG">Organization</option>
            </select>
            <select v-if="bucketForm.ownerType === 'ORG' && isAdmin" v-model="bucketForm.ownerId">
              <option value="">Org</option>
              <option v-for="organization in organizations" :key="organization.id" :value="organization.id">
                {{ organization.name }}
              </option>
            </select>
            <button
              type="submit"
              :disabled="!isLoggedIn || (bucketForm.ownerType === 'ORG' && isAdmin && !bucketForm.ownerId)"
            >
              생성
            </button>
          </form>

          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>이름</th>
                  <th>사용량</th>
                  <th>파일</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="bucket in bucketRows"
                  :key="bucket.name"
                  :class="{ selected: selectedBucket === bucket.name }"
                  @click="selectBucket(bucket.name)"
                >
                  <td>{{ bucket.name }}</td>
                  <td>{{ bucket.usageLabel }}</td>
                  <td>{{ bucket.objectCount }}</td>
                  <td class="actions">
                    <button type="button" class="ghost" @click.stop="handleSyncBucket(bucket.name)">
                      동기화
                    </button>
                    <button type="button" class="danger" @click.stop="handleDeleteBucket(bucket.name)">
                      삭제
                    </button>
                  </td>
                </tr>
                <tr v-if="buckets.length === 0">
                  <td colspan="4" class="empty">버킷 없음</td>
                </tr>
              </tbody>
            </table>
          </div>
        </article>

        <article class="panel">
          <div class="panel-head">
            <div>
              <p class="eyebrow">Objects</p>
              <h3>파일 탐색기</h3>
            </div>
            <strong class="bucket-label">{{ selectedBucket || '버킷 선택' }}</strong>
          </div>

          <form class="inline-form object-filter" @submit.prevent="loadObjects()">
            <input v-model="objectPrefix" placeholder="prefix: images/" :disabled="!isLoggedIn || !selectedBucket" />
            <input v-model="objectSearch" placeholder="검색: report" :disabled="!isLoggedIn || !selectedBucket" />
            <input v-model="objectTagFilter" placeholder="tag: project=osmu" :disabled="!isLoggedIn || !selectedBucket" />
            <select v-model.number="objectListLimit" :disabled="!isLoggedIn || !selectedBucket" @change="loadObjects()">
              <option v-for="limit in objectListLimitOptions" :key="limit" :value="limit">
                {{ limit }}개
              </option>
            </select>
            <button type="submit" :disabled="!isLoggedIn || !selectedBucket">검색</button>
            <button type="button" class="ghost" :disabled="!objectPrefix" @click="handleObjectPrefixUp">
              상위
            </button>
            <button type="button" class="ghost" :disabled="!objectPrefix && !objectSearch && !objectTagFilter" @click="handleResetObjectFilter">
              초기화
            </button>
          </form>
          <div class="segmented-control" role="tablist" aria-label="Object view">
            <button
              type="button"
              :class="{ active: objectViewMode === 'active' }"
              :disabled="!isLoggedIn || !selectedBucket"
              @click="handleObjectViewModeChange('active')"
            >
              Active
            </button>
            <button
              type="button"
              :class="{ active: objectViewMode === 'trash' }"
              :disabled="!isLoggedIn || !selectedBucket"
              @click="handleObjectViewModeChange('trash')"
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
              @click="handleSelectObjectPrefix(crumb.prefix)"
            >
              {{ crumb.label }}
            </button>
          </nav>

          <form class="inline-form object-form" @submit.prevent="handleUploadObject">
            <input v-model="objectForm.key" placeholder="images/sample.png" />
            <input v-model="objectForm.tags" placeholder="tags: project=osmu,stage=raw" />
            <input type="file" :disabled="uploadState.active" @change="handleFileChange" />
            <button type="submit" :disabled="!canSubmitUpload">
              {{ uploadState.active ? '업로드 중' : '업로드' }}
            </button>
            <button type="button" class="ghost" :disabled="!uploadState.active" @click="handleCancelUpload">
              취소
            </button>
            <button type="button" class="ghost" :disabled="!canRetryUpload" @click="handleRetryUpload">
              재시도
            </button>
            <button type="button" class="ghost" :disabled="!isLoggedIn || !selectedBucket" @click="handleCreatePresignedUploadUrl">
              URL 발급
            </button>
            <button type="button" class="ghost" :disabled="!pendingUploadId" @click="handleCompletePresignedUpload">
              완료 확인
            </button>
          </form>
          <section
            v-if="visibleMultipartResumeSessions.length > 0"
            class="resume-panel"
            aria-label="Pending multipart uploads"
          >
            <div class="resume-panel-head">
              <strong>Pending multipart</strong>
              <span>{{ visibleMultipartResumeSessions.length }}</span>
            </div>
            <ul>
              <li
                v-for="session in visibleMultipartResumeSessions"
                :key="session.storageKey"
                :class="{ expired: session.expired }"
              >
                <span class="list-main">
                  <b>{{ session.key }}</b>
                  <small>
                    {{ session.fileName }} /
                    {{ formatBytes(session.fileSize) }} /
                    {{ session.completedParts.length }} of {{ session.partCount || '-' }} parts /
                    {{ formatMultipartResumeStatus(session) }}
                  </small>
                </span>
                <span class="resume-actions">
                  <button
                    type="button"
                    class="ghost"
                    :disabled="session.expired || !isMatchingResumeSession(session)"
                    @click="handleResumeMatchingMultipartUpload(session)"
                  >
                    Resume
                  </button>
                  <button type="button" class="danger" @click="handleDiscardMultipartResume(session.storageKey)">
                    Delete
                  </button>
                </span>
              </li>
            </ul>
          </section>
          <form class="inline-form tag-form" @submit.prevent="handleUpdateObjectTags">
            <input v-model="objectTagForm.key" placeholder="tag target key" />
            <input v-model="objectTagForm.tags" placeholder="tags: project=osmu,stage=raw" />
            <button type="submit" :disabled="!isLoggedIn || !selectedBucket || !objectTagForm.key">
              태그 저장
            </button>
            <button type="button" class="ghost" :disabled="!objectTagForm.key && !objectTagForm.tags" @click="handleResetObjectTagForm">
              취소
            </button>
          </form>
          <div v-if="uploadState.active || uploadState.retryable" class="upload-progress" role="status" aria-live="polite">
            <div>
              <strong>{{ uploadState.percent }}%</strong>
              <span>{{ formatBytes(uploadState.loadedBytes) }} / {{ formatBytes(uploadState.totalBytes) }}</span>
            </div>
            <progress :value="uploadState.percent" max="100"></progress>
            <p v-if="uploadState.message">{{ uploadState.message }}</p>
          </div>
          <p v-if="presignedUrl" class="secret-box">Presigned URL: {{ presignedUrl }}</p>

          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>키</th>
                  <th>크기</th>
                  <th>타입</th>
                  <th>태그</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="prefix in objectPrefixes" :key="`prefix-${prefix}`" class="folder-row">
                  <td>{{ formatPrefixName(prefix) }}</td>
                  <td>-</td>
                  <td>prefix</td>
                  <td>-</td>
                  <td class="actions">
                    <button type="button" class="ghost" @click="handleOpenObjectPrefix(prefix)">
                      열기
                    </button>
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
                  <td>{{ object.contentType }}</td>
                  <td>{{ formatObjectTags(object.tags) }}</td>
                  <td class="actions">
                    <button v-if="objectViewMode === 'active'" type="button" class="ghost" @click="handleDownloadObject(object.key)">
                      다운로드
                    </button>
                    <button v-if="objectViewMode === 'active'" type="button" class="ghost" @click="handleCreatePresignedDownloadUrl(object.key)">
                      URL
                    </button>
                    <button v-if="objectViewMode === 'active'" type="button" class="ghost" @click="handleStartObjectTagEdit(object)">
                      태그
                    </button>
                    <button v-if="objectViewMode === 'active'" type="button" class="ghost" @click="handleLoadObjectMetadata(object.key)">
                      상세
                    </button>
                    <button v-if="objectViewMode === 'active'" type="button" class="ghost" @click="handleLoadObjectVersions(object.key)">
                      Versions
                    </button>
                    <button v-if="objectViewMode === 'active'" type="button" class="danger" @click="handleDeleteObject(object.key)">삭제</button>
                    <button v-if="objectViewMode === 'trash'" type="button" class="ghost" @click="handleRestoreObject(object.key)">
                      Restore
                    </button>
                    <button v-if="objectViewMode === 'trash'" type="button" class="danger" @click="handlePurgeObject(object.key)">
                      Purge
                    </button>
                  </td>
                </tr>
                <tr v-if="objects.length === 0 && objectPrefixes.length === 0">
                  <td colspan="5" class="empty">파일 없음</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="panel-actions" v-if="objects.length > 0 || objectPrefixes.length > 0">
            <button type="button" class="ghost" :disabled="!objectNextCursor" @click="handleLoadNextObjects">
              다음 항목
            </button>
          </div>
          <section v-if="objectMetadata" class="object-detail-panel">
            <div class="panel-head slim">
              <div>
                <p class="eyebrow">Object Detail</p>
                <h3>{{ objectMetadata.key }}</h3>
              </div>
              <div class="detail-actions">
                <span :class="['status-pill', metadataStatusClass(objectMetadata.syncStatus)]">
                  {{ metadataStatusLabel(objectMetadata.syncStatus) }}
                </span>
                <button type="button" class="ghost" @click="objectMetadata = null">닫기</button>
              </div>
            </div>
            <dl class="detail-grid">
              <div>
                <dt>Index 크기</dt>
                <dd>{{ formatBytes(objectMetadata.sizeBytes) }}</dd>
              </div>
              <div>
                <dt>Storage 크기</dt>
                <dd>{{ formatOptionalBytes(objectMetadata.storageSizeBytes) }}</dd>
              </div>
              <div>
                <dt>Index 타입</dt>
                <dd>{{ objectMetadata.contentType }}</dd>
              </div>
              <div>
                <dt>Storage 타입</dt>
                <dd>{{ objectMetadata.storageContentType || '-' }}</dd>
              </div>
              <div>
                <dt>Index ETag</dt>
                <dd>{{ objectMetadata.etag || '-' }}</dd>
              </div>
              <div>
                <dt>Storage ETag</dt>
                <dd>{{ objectMetadata.storageEtag || '-' }}</dd>
              </div>
              <div>
                <dt>Index checksum</dt>
                <dd>{{ formatChecksumMap(objectMetadata.checksums) }}</dd>
              </div>
              <div>
                <dt>Storage checksum</dt>
                <dd>{{ formatChecksumMap(objectMetadata.storageChecksums) }}</dd>
              </div>
              <div>
                <dt>Index 수정일</dt>
                <dd>{{ formatDateTime(objectMetadata.lastModifiedAt) }}</dd>
              </div>
              <div>
                <dt>Storage 수정일</dt>
                <dd>{{ formatDateTime(objectMetadata.storageLastModifiedAt) }}</dd>
              </div>
              <div>
                <dt>Index 태그</dt>
                <dd>{{ formatObjectTags(objectMetadata.tags) }}</dd>
              </div>
              <div>
                <dt>Storage 태그</dt>
                <dd>{{ formatObjectTags(objectMetadata.storageTags) }}</dd>
              </div>
            </dl>
          </section>
          <section v-if="objectVersions.key" class="object-detail-panel">
            <div class="panel-head slim">
              <div>
                <p class="eyebrow">Object Versions</p>
                <h3>{{ objectVersions.key }}</h3>
              </div>
              <div class="detail-actions">
                <span class="status-pill mock">{{ objectVersions.items.length }}</span>
                <button type="button" class="ghost" @click="resetObjectVersions">닫기</button>
              </div>
            </div>
            <ul class="compact-list version-list">
              <li v-for="version in objectVersions.items" :key="version.versionId">
                <span class="list-main">
                  <b>{{ formatDateTime(version.createdAt) }}</b>
                  <small>
                    {{ version.versionId }} / {{ formatBytes(version.sizeBytes) }} /
                    {{ version.contentType }} / {{ formatObjectTags(version.tags) }}
                  </small>
                </span>
                <span class="version-actions">
                  <button
                    type="button"
                    class="ghost"
                    :disabled="objectVersions.pending"
                    @click="handleDownloadObjectVersion(version.versionId)"
                  >
                    Download
                  </button>
                  <button
                    type="button"
                    class="ghost"
                    :disabled="objectVersions.pending"
                    @click="handleRestoreObjectVersion(version.versionId)"
                  >
                    Restore
                  </button>
                  <button
                    type="button"
                    class="ghost danger"
                    :disabled="objectVersions.pending"
                    @click="handleDeleteObjectVersion(version.versionId)"
                  >
                    Delete
                  </button>
                </span>
              </li>
              <li v-if="objectVersions.items.length === 0" class="empty">Version 없음</li>
            </ul>
          </section>
        </article>
      </section>

      <section class="content-grid lower">
        <article class="panel">
          <div class="panel-head">
            <div>
              <p class="eyebrow">Access Keys</p>
              <h3>접근 키</h3>
            </div>
          </div>
          <form class="access-key-form" @submit.prevent="handleCreateAccessKey">
            <input v-model="accessKeyForm.name" placeholder="local-dev-key" />
            <div class="scope-builder">
              <select v-model="accessKeyForm.scopeBucket">
                <option value="">Bucket</option>
                <option v-for="bucket in buckets" :key="bucket.name" :value="bucket.name">
                  {{ bucket.name }}
                </option>
              </select>
              <div class="permission-row">
                <label class="check">
                  <input v-model="accessKeyForm.scopePermissions" type="checkbox" value="READ" />
                  READ
                </label>
                <label class="check">
                  <input v-model="accessKeyForm.scopePermissions" type="checkbox" value="WRITE" />
                  WRITE
                </label>
                <label class="check">
                  <input v-model="accessKeyForm.scopePermissions" type="checkbox" value="DELETE" />
                  DELETE
                </label>
                <label class="check">
                  <input v-model="accessKeyForm.scopePermissions" type="checkbox" value="ADMIN" />
                  ADMIN
                </label>
              </div>
              <button
                type="button"
                class="ghost"
                :disabled="!accessKeyForm.scopeBucket || accessKeyForm.scopePermissions.length === 0"
                @click="handleAddAccessKeyScope"
              >
                추가
              </button>
            </div>
            <button
              type="submit"
              :disabled="!isLoggedIn || accessKeyForm.scopes.length === 0"
            >
              발급
            </button>
          </form>
          <ul v-if="accessKeyForm.scopes.length > 0" class="scope-list">
            <li v-for="scope in accessKeyForm.scopes" :key="scope.bucketName">
              <span>{{ scope.bucketName }} / {{ scope.permissions.join(', ') }}</span>
              <button type="button" class="danger" @click="handleRemoveAccessKeyScope(scope.bucketName)">제거</button>
            </li>
          </ul>
          <p v-if="newSecretKey" class="secret-box">Secret Key: {{ newSecretKey }}</p>
          <ul class="compact-list">
            <li v-for="key in accessKeys" :key="key.id">
              <span class="list-main">
                <b>{{ key.name }}</b>
                <small>{{ key.policyName }} / {{ formatKeyScope(key) }}</small>
              </span>
              <span class="key-actions">
                <strong>{{ key.status }}</strong>
                <button
                  type="button"
                  class="danger"
                  :disabled="key.status !== 'ACTIVE'"
                  @click="handleDeleteAccessKey(key.id)"
                >
                  비활성화
                </button>
              </span>
            </li>
          </ul>
        </article>

        <article v-if="isLoggedIn && selectedBucket && canShowBucketPermissions" class="panel">
          <div class="panel-head">
            <div>
              <p class="eyebrow">Permissions</p>
              <h3>버킷 권한</h3>
            </div>
            <strong class="bucket-label">{{ selectedBucket }}</strong>
          </div>
          <form class="inline-form permission-form" @submit.prevent="handleGrantBucketPermissions">
            <select v-model="bucketPermissionForm.subjectType">
              <option value="USER">USER</option>
              <option value="ORGANIZATION">ORGANIZATION</option>
            </select>
            <select
              v-if="bucketPermissionForm.subjectType === 'USER' && users.length > 0"
              v-model="bucketPermissionForm.subjectId"
            >
              <option value="">User</option>
              <option v-for="user in users" :key="user.id" :value="user.id">
                {{ user.loginId }}
              </option>
            </select>
            <select
              v-else-if="bucketPermissionForm.subjectType === 'ORGANIZATION' && organizations.length > 0"
              v-model="bucketPermissionForm.subjectId"
            >
              <option value="">Org</option>
              <option v-for="organization in organizations" :key="organization.id" :value="organization.id">
                {{ organization.name }}
              </option>
            </select>
            <input v-else v-model="bucketPermissionForm.subjectId" type="number" min="1" placeholder="subject id" />
            <div class="permission-row">
              <label class="check">
                <input v-model="bucketPermissionForm.permissions" type="checkbox" value="READ" />
                READ
              </label>
              <label class="check">
                <input v-model="bucketPermissionForm.permissions" type="checkbox" value="WRITE" />
                WRITE
              </label>
              <label class="check">
                <input v-model="bucketPermissionForm.permissions" type="checkbox" value="DELETE" />
                DELETE
              </label>
              <label class="check">
                <input v-model="bucketPermissionForm.permissions" type="checkbox" value="ADMIN" />
                ADMIN
              </label>
            </div>
            <button type="submit" :disabled="bucketPermissionForm.permissions.length === 0">부여</button>
          </form>
          <ul class="compact-list">
            <li v-for="permission in bucketPermissions" :key="permission.id">
              <span>
                {{ permission.subjectType }} #{{ permission.subjectId }} /
                {{ permission.permission }}
              </span>
              <button type="button" class="danger" @click="handleRevokeBucketPermission(permission.id)">회수</button>
            </li>
            <li v-if="bucketPermissions.length === 0" class="empty">권한 없음</li>
          </ul>
        </article>

        <article v-if="isLoggedIn && selectedBucket && canUseBucketLifecycle" class="panel">
          <div class="panel-head">
            <div>
              <p class="eyebrow">Bucket Lifecycle</p>
              <h3>S3 XML</h3>
            </div>
            <strong class="bucket-label">{{ selectedBucket }}</strong>
          </div>
          <div class="lifecycle-xml">
            <div>
              <strong>{{ bucketLifecycleXml.ruleCount ?? 0 }} rules</strong>
              <small v-if="bucketLifecycleXml.savedCount !== null">saved {{ bucketLifecycleXml.savedCount }} rules</small>
            </div>
            <div class="rule-actions">
              <button type="button" class="ghost" :disabled="bucketLifecycleXml.pending" @click="loadBucketLifecycleXml">
                {{ bucketLifecycleXml.pending ? 'Loading' : 'Load' }}
              </button>
              <button type="button" :disabled="bucketLifecycleXml.pending" @click="handlePutBucketLifecycleXml">
                Save
              </button>
              <button type="button" class="danger" :disabled="bucketLifecycleXml.pending" @click="handleDeleteBucketLifecycleXml">
                Delete
              </button>
            </div>
            <textarea
              v-model="bucketLifecycleXml.content"
              placeholder="<LifecycleConfiguration>..."
              rows="6"
            ></textarea>
          </div>
        </article>

        <article v-if="isLoggedIn && selectedBucket && canUseBucketTags" class="panel">
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
              <button type="button" class="ghost" :disabled="bucketTags.pending" @click="loadBucketTags">
                {{ bucketTags.pending ? 'Loading' : 'Load' }}
              </button>
              <button type="button" :disabled="bucketTags.pending" @click="handlePutBucketTags">
                Save
              </button>
              <button type="button" class="danger" :disabled="bucketTags.pending" @click="handleDeleteBucketTags">
                Delete
              </button>
            </div>
            <textarea
              v-model="bucketTags.content"
              placeholder="project=osmu,stage=raw"
              rows="4"
            ></textarea>
          </div>
        </article>

        <article v-if="canUseAdminTools" class="panel">
          <div class="panel-head">
            <div>
              <p class="eyebrow">Organizations</p>
              <h3>조직 관리</h3>
            </div>
          </div>
          <form class="inline-form organization-form" @submit.prevent="handleCreateOrganization">
            <input v-model="organizationForm.name" placeholder="AI Research Team" />
            <input v-model="organizationForm.description" placeholder="description" />
            <input v-model.number="organizationForm.defaultQuotaTb" min="1" type="number" />
            <button type="submit" :disabled="!isLoggedIn">생성</button>
          </form>
          <ul class="compact-list">
            <li v-for="organization in organizationUsages" :key="organization.id">
              <span class="list-main">
                <b>{{ organization.name }}</b>
                <small>
                  {{ formatBytes(organization.usedBytes) }} /
                  {{ formatBytes(organization.defaultQuotaBytes || organization.bucketQuotaBytes) }}
                  · buckets {{ organization.bucketCount }}
                  · objects {{ organization.objectCount }}
                </small>
              </span>
              <strong>#{{ organization.id }}</strong>
            </li>
            <li v-if="organizationUsages.length === 0" class="empty">조직 없음</li>
          </ul>
        </article>

        <article v-if="canUseAdminTools" class="panel">
          <div class="panel-head">
            <div>
              <p class="eyebrow">Users</p>
              <h3>사용자 관리</h3>
            </div>
          </div>
          <form class="inline-form user-form" @submit.prevent="handleCreateUser">
            <input v-model="userForm.loginId" placeholder="user1" />
            <input v-model="userForm.email" placeholder="user1@example.com" />
            <input v-model="userForm.name" placeholder="User One" />
            <input v-model="userForm.password" type="password" placeholder="password" />
            <select v-model="userForm.organizationId">
              <option value="">No org</option>
              <option v-for="organization in organizations" :key="organization.id" :value="organization.id">
                {{ organization.name }}
              </option>
            </select>
            <select v-model="userForm.role">
              <option value="USER">USER</option>
              <option v-if="isAdmin" value="ORG_ADMIN">ORG_ADMIN</option>
              <option v-if="isAdmin" value="ADMIN">ADMIN</option>
            </select>
            <button type="submit" :disabled="!isLoggedIn">생성</button>
          </form>
          <ul class="compact-list">
            <li v-for="user in users" :key="user.id">
              <span>{{ user.loginId }} / {{ user.role }} / org {{ user.organizationId || '-' }}</span>
              <button
                type="button"
                :class="user.status === 'ACTIVE' ? 'danger' : 'ghost'"
                :disabled="session.user?.id === user.id"
                @click="handleToggleUserStatus(user)"
              >
                {{ user.status === 'ACTIVE' ? '비활성화' : '활성화' }}
              </button>
            </li>
            <li v-if="users.length === 0" class="empty">사용자 없음</li>
          </ul>
        </article>

        <article v-if="isAdmin" class="panel">
          <div class="panel-head">
            <div>
              <p class="eyebrow">Audit</p>
              <h3>감사 로그</h3>
            </div>
          </div>
          <form class="inline-form audit-filter" @submit.prevent="handleLoadAuditLogs">
            <input v-model="auditFilter.eventType" placeholder="eventType" />
            <input v-model="auditFilter.actorId" placeholder="actorId" />
            <input v-model="auditFilter.requestId" placeholder="requestId" />
            <input v-model="auditFilter.targetType" placeholder="targetType" />
            <input v-model="auditFilter.targetId" placeholder="targetId" />
            <select v-model="auditFilter.result">
              <option value="">Result</option>
              <option value="SUCCESS">SUCCESS</option>
              <option value="FAIL">FAIL</option>
            </select>
            <input v-model="auditFilter.from" type="datetime-local" />
            <input v-model="auditFilter.to" type="datetime-local" />
            <input v-model.number="auditFilter.limit" type="number" min="1" max="500" />
            <button type="submit">필터</button>
            <button type="button" class="ghost" @click="handleResetAuditFilter">초기화</button>
          </form>
          <ul class="audit-list">
            <li v-for="entry in auditLogs" :key="entry.id" class="audit-entry">
              <div>
                <strong>{{ entry.eventType }}</strong>
                <small>{{ entry.actorId }} -> {{ entry.targetId }}</small>
              </div>
              <div class="audit-meta">
                <span>{{ entry.result }}</span>
                <small>{{ entry.ipAddress || '-' }}</small>
                <small>{{ entry.requestId || '-' }}</small>
              </div>
            </li>
            <li v-if="auditLogs.length === 0" class="empty">로그 없음</li>
          </ul>
          <div class="panel-actions" v-if="auditLogs.length > 0">
            <button type="button" class="ghost" :disabled="!auditNextCursor" @click="handleLoadNextAuditLogs">
              다음 로그
            </button>
          </div>
        </article>
      </section>
    </section>

    <div v-if="confirmDialog.open" class="modal-backdrop" role="presentation" @click.self="closeConfirmDialog">
      <section class="confirm-modal" role="dialog" aria-modal="true" aria-labelledby="confirm-dialog-title">
        <div>
          <p class="eyebrow">Confirm</p>
          <h3 id="confirm-dialog-title">{{ confirmDialog.title }}</h3>
        </div>
        <p>{{ confirmDialog.message }}</p>
        <div class="modal-actions">
          <button type="button" class="ghost" :disabled="confirmDialog.pending" @click="closeConfirmDialog">
            취소
          </button>
          <button type="button" class="danger" :disabled="confirmDialog.pending" @click="handleConfirmDialogAction">
            {{ confirmDialog.pending ? '처리 중' : confirmDialog.confirmLabel }}
          </button>
        </div>
      </section>
    </div>
  </main>
</template>

<script setup>
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue'
import {
  MULTIPART_UPLOAD_THRESHOLD_BYTES,
  cleanupObjectShareLinks,
  completePresignedUpload,
  createAccessKey,
  createBucket,
  createOrganization,
  createPresignedDownloadUrl,
  createPresignedUploadUrl,
  createUser,
  deleteAccessKey,
  deleteBucket,
  deleteObject,
  downloadObject,
  getAccessKeys,
  getAuditLogs,
  getBucketPermissions,
  getBuckets,
  getDatabaseHealth,
  getHealth,
  getObjectMetadata,
  getObjectRetentionStatus,
  getObjects,
  getOrganizations,
  getOrganizationUsage,
  getStorageHealth,
  getUsage,
  getUsers,
  grantBucketPermissions,
  listObjectVersions,
  login,
  logout as logoutApi,
  purgeObject,
  restoreObject,
  restoreObjectVersion,
  revokeBucketPermission,
  runObjectRetentionPurge,
  syncBucketUsage,
  updateObjectTags,
  updateUserStatus,
  uploadObject,
  uploadObjectMultipart,
} from '@/services/api'
import { useAuthStore } from '@/stores/auth'
import {
  buildObjectMetadataDetailRows,
  buildObjectPrefixBreadcrumbs,
  formatPrefixName,
  parentObjectPrefix,
  splitObjectKeyBySearch,
} from '@/utils/objectExplorer'
import {
  tagPairsToMap,
  tagsToInput,
  validateBucketTagInput,
  validateObjectTagInput,
} from '@/utils/tags'

const health = reactive({
  backend: 'DOWN',
  storage: 'DOWN',
  database: 'DOWN',
})
const usage = reactive({
  totalQuotaBytes: 0,
  usedBytes: 0,
  remainingBytes: 0,
  bucketCount: 0,
  objectCount: 0,
})
const retentionPolicy = reactive({
  enabled: false,
  retentionDays: 0,
  batchSize: 0,
  purgedObjectCount: 0,
  failedObjectCount: 0,
  failedRunCount: 0,
  lastPurgedCount: null,
  pending: false,
})
const loginForm = reactive({ loginId: 'admin', password: 'qwer1234@' })
const bucketForm = reactive({ name: '', quotaGb: 100, ownerType: 'USER', ownerId: '' })
const objectForm = reactive({ key: '', tags: '', file: null })
const objectTagForm = reactive({ key: '', tags: '' })
const objectPrefix = ref('')
const objectSearch = ref('')
const objectTagFilter = ref('')
const objectViewMode = ref('active')
const objectPrefixes = ref([])
const objectNextCursor = ref('')
const objectListLimit = ref(100)
const objectMetadata = ref(null)
const objectVersions = reactive({
  key: '',
  items: [],
  pending: false,
})
const objectShareLinks = reactive({
  key: '',
  items: [],
  pending: false,
})
const objectSharePolicy = reactive({
  requirePassword: false,
  requireIpAllowlist: false,
  maxExpiresSeconds: 604800,
  maxDownloadsLimit: null,
  updatedAt: null,
})
const objectSharePolicyForm = reactive({
  requirePassword: false,
  requireIpAllowlist: false,
  maxExpiresSeconds: 604800,
  maxDownloadsLimit: '',
  reason: '',
  pending: false,
})
const objectShareAnalytics = reactive({
  totalLinks: 0,
  activeLinks: 0,
  expiredLinks: 0,
  revokedLinks: 0,
  limitReachedLinks: 0,
  passwordProtectedLinks: 0,
  ipRestrictedLinks: 0,
  totalDownloads: 0,
  lastAccessedAt: null,
  recentLinks: [],
})
const objectShareAnalyticsFilter = reactive({
  bucketName: '',
  status: '',
  limit: 10,
})
const accessKeyForm = reactive({
  name: 'local-dev-key',
  scopeBucket: '',
  scopePermissions: ['READ', 'WRITE', 'DELETE'],
  scopes: [],
})
const bucketPermissionForm = reactive({
  subjectType: 'USER',
  subjectId: '',
  permissions: ['READ'],
})
const userForm = reactive({
  loginId: '',
  email: '',
  name: '',
  password: '',
  role: 'USER',
  organizationId: '',
})
const organizationForm = reactive({
  name: '',
  description: '',
  defaultQuotaTb: 10,
})
const quotaPolicyForm = reactive({
  targetType: 'USER',
  targetId: '',
  targetSearch: '',
  quotaGb: 100,
  editingKey: '',
})
const auditFilter = reactive({
  eventType: '',
  actorId: '',
  requestId: '',
  targetType: '',
  targetId: '',
  result: '',
  from: '',
  to: '',
  limit: 50,
})
const auth = useAuthStore()
const session = auth.state
const uploadState = reactive({
  active: false,
  loadedBytes: 0,
  totalBytes: 0,
  percent: 0,
  message: '',
  retryable: false,
})
const confirmDialog = reactive({
  open: false,
  title: '',
  message: '',
  confirmLabel: '확인',
  pending: false,
  action: null,
})

const buckets = ref([])
const objects = ref([])
const accessKeys = ref([])
const bucketPermissions = ref([])
const users = ref([])
const organizations = ref([])
const organizationUsages = ref([])
const quotaPolicies = ref([])
const auditLogs = ref([])
const auditNextCursor = ref('')
const selectedBucket = ref('')
const errorMessage = ref('')
const errorRequestId = ref('')
const newSecretKey = ref('')
const presignedUrl = ref('')
const shareLinkUrl = ref('')
const shareLinkPassword = ref('')
const pendingUploadId = ref('')
const uploadController = ref(null)
const lastUploadRequest = ref(null)
const pendingMultipartUploads = ref([])

const statusItems = computed(() => [
  { label: 'Backend', value: health.backend },
  { label: 'Storage', value: health.storage },
  { label: 'Database', value: health.database },
])
const isLoggedIn = auth.isLoggedIn
const isAdmin = auth.isAdmin
const isOrgAdmin = auth.isOrgAdmin
const canUseAdminTools = auth.canUseAdminTools
const canCreateOrgBucket = computed(() => isAdmin.value || (isOrgAdmin.value && Boolean(session.user?.organizationId)))
const BYTES_PER_GIB = 1024 * 1024 * 1024

const quotaPolicyAllTargetOptions = computed(() => {
  if (quotaPolicyForm.targetType === 'ORGANIZATION') {
    return organizations.value.map((organization) => ({
      id: String(organization.id),
      label: `${organization.name} (#${organization.id})`,
    }))
  }
  if (quotaPolicyForm.targetType === 'BUCKET') {
    return buckets.value.map((bucket) => ({
      id: String(bucket.id),
      label: `${bucket.name} (#${bucket.id})`,
    }))
  }
  return users.value.map((user) => ({
    id: String(user.id),
    label: `${user.loginId} (#${user.id})`,
  }))
})
const quotaPolicyTargetOptions = computed(() => {
  const options = quotaPolicyAllTargetOptions.value
  const query = quotaPolicyForm.targetSearch.trim().toLowerCase()
  if (!query) {
    return options
  }
  const filtered = options.filter((target) => target.label.toLowerCase().includes(query))
  const selected = options.find((target) => target.id === String(quotaPolicyForm.targetId || ''))
  if (selected && !filtered.some((target) => target.id === selected.id)) {
    return [selected, ...filtered]
  }
  return filtered
})
const selectedBucketRecord = computed(() => buckets.value.find((bucket) => bucket.name === selectedBucket.value))
const bucketRows = computed(() => buildBucketListRows(buckets.value, formatBytes))
const canSubmitUpload = computed(() => isLoggedIn.value && Boolean(selectedBucket.value) && canStartUpload(uploadState))
const canRetryUpload = computed(() => Boolean(lastUploadRequest.value) && uploadState.retryable && canStartUpload(uploadState))
const matchingMultipartResumeSession = computed(() => {
  if (!selectedBucket.value || !objectForm.file || !objectForm.key) {
    return null
  }
  return getStoredMultipartUploadSessionForFile(
    selectedBucket.value,
    objectForm.key,
    objectForm.file,
    objectForm.tags,
  )
})
const visibleMultipartResumeSessions = computed(() => pendingMultipartUploads.value
  .filter((session) => !selectedBucket.value || session.bucketName === selectedBucket.value)
  .slice(0, 5))
const canManageSelectedBucket = computed(() => {
  const bucket = selectedBucketRecord.value
  if (!bucket || !session.user) {
    return false
  }
  return isAdmin.value
    || (bucket.ownerType === 'USER' && bucket.ownerId === session.user.id)
    || (bucket.ownerType === 'ORG' && isOrgAdmin.value && bucket.ownerId === session.user.organizationId)
})
const canShowBucketPermissions = computed(() => canManageSelectedBucket.value || bucketPermissions.value.length > 0)
const hasSelectedBucketAdminPermission = computed(() =>
  bucketPermissions.value.some((permission) => permission.permission === 'ADMIN'))
const canUseBucketLifecycle = computed(() => canManageSelectedBucket.value || hasSelectedBucketAdminPermission.value)
const objectPrefixBreadcrumbs = computed(() => buildObjectPrefixBreadcrumbs(objectPrefix.value))
const objectListLimitOptions = [50, 100, 250, 500, 1000]
const maxTagCount = 10
const maxTagKeyLength = 128
const maxTagValueLength = 256
const tagKeyPattern = /^[A-Za-z0-9_.:/@+-]+$/

let stopAuthSync = () => {}

onMounted(async () => {
  stopAuthSync = auth.startAuthSync(resetSessionData)
  refreshPendingMultipartUploads()
  const restored = await auth.restoreSession()
  if (restored) {
    await loadDashboard()
    return
  }
  await loadHealth()
})

onUnmounted(() => {
  uploadController.value?.abort()
  stopAuthSync()
})

async function refreshAll() {
  refreshPendingMultipartUploads()
  if (isLoggedIn.value) {
    await loadDashboard()
    return
  }
  await loadHealth()
}

async function loadHealth() {
  clearError()
  try {
    const [backend, storage, database] = await Promise.all([
      getHealth(),
      getStorageHealth(),
      getDatabaseHealth(),
    ])

    health.backend = backend.data.status
    health.storage = storage.data.status
    health.database = database.data.status
  } catch (error) {
    health.backend = 'DOWN'
    setError(error)
  }
}

async function loadDashboard() {
  clearError()
  try {
    refreshPendingMultipartUploads()
    await loadHealth()
    const [bucketResult, keyResult] = await Promise.all([
      getBuckets(),
      getAccessKeys(),
    ])

    buckets.value = bucketResult.items
    accessKeys.value = keyResult.items
    syncAccessKeyBucketSelection()
    Object.assign(usage, summarizeBuckets(buckets.value))

    if (isAdmin.value) {
      const [
        usageResult,
        auditResult,
        userResult,
        organizationResult,
        organizationUsageResult,
        retentionResult,
        lifecycleRuleResult,
        lifecycleConflictResult,
      ] = await Promise.all([
        getUsage(),
        getAuditLogs(auditFilterPayload()),
        getUsers(),
        getOrganizations(),
        getOrganizationUsage(),
        getObjectRetentionStatus(),
        getObjectLifecycleRules(),
        getObjectLifecycleConflicts(),
      ])
      Object.assign(usage, usageResult.data)
      applyRetentionStatus(retentionResult.data)
      lifecycleRules.value = lifecycleRuleResult.data || []
      applyLifecycleRuleConflicts(lifecycleConflictResult.data)
      auditLogs.value = auditResult.items
      auditNextCursor.value = auditResult.nextCursor || ''
      users.value = userResult.items
      organizations.value = organizationResult.items
      organizationUsages.value = organizationUsageResult.items
    } else if (isOrgAdmin.value) {
      const [userResult, organizationResult, organizationUsageResult] = await Promise.all([
        getUsers(),
        getOrganizations(),
        getOrganizationUsage(),
      ])
      auditLogs.value = []
      auditNextCursor.value = ''
      users.value = userResult.items
      organizations.value = organizationResult.items
      organizationUsages.value = organizationUsageResult.items
      resetRetentionPolicy()
      resetLifecycleRules()
      resetLifecycleRuleConflicts()
      resetLifecycleXml()
      resetBucketLifecycleXml()
      resetBucketTags()
    } else {
      auditLogs.value = []
      auditNextCursor.value = ''
      users.value = []
      organizations.value = []
      organizationUsages.value = []
      resetRetentionPolicy()
      resetLifecycleRules()
      resetLifecycleRuleConflicts()
      resetLifecycleXml()
      resetBucketLifecycleXml()
      resetBucketTags()
    }

    if (!selectedBucket.value && buckets.value.length > 0) {
      selectedBucket.value = buckets.value[0].name
    }
    refreshPendingMultipartUploads()
    if (selectedBucket.value) {
      await loadSelectedBucketDetails()
    }
  } catch (error) {
    health.backend = 'DOWN'
    setError(error)
  }
}

async function handleLoadAuditLogs() {
  const result = await runAction(() => getAuditLogs(auditFilterPayload()))
  if (result) {
    auditLogs.value = result.items
    auditNextCursor.value = result.nextCursor || ''
  }
}

async function handleLoadNextAuditLogs() {
  if (!auditNextCursor.value) {
    return
  }
  const result = await runAction(() => getAuditLogs(auditFilterPayload(auditNextCursor.value)))
  if (result) {
    auditLogs.value = [...auditLogs.value, ...result.items]
    auditNextCursor.value = result.nextCursor || ''
  }
}

async function handleResetAuditFilter() {
  auditFilter.eventType = ''
  auditFilter.actorId = ''
  auditFilter.requestId = ''
  auditFilter.targetType = ''
  auditFilter.targetId = ''
  auditFilter.result = ''
  auditFilter.from = ''
  auditFilter.to = ''
  auditFilter.limit = 50
  await handleLoadAuditLogs()
}

async function handleLogin() {
  const result = await runAction(() => login(loginForm.loginId, loginForm.password))
  if (result) {
    auth.applySession(result.data)
    await loadDashboard()
  }
}

async function handleLogout() {
  await runAction(() => logoutApi())
  resetSessionData()
  await loadHealth()
}

function resetSessionData() {
  buckets.value = []
  objects.value = []
  objectPrefixes.value = []
  accessKeys.value = []
  bucketPermissions.value = []
  users.value = []
  organizations.value = []
  organizationUsages.value = []
  quotaPolicies.value = []
  auditLogs.value = []
  auditNextCursor.value = ''
  selectedBucket.value = ''
  objectPrefix.value = ''
  objectSearch.value = ''
  objectTagFilter.value = ''
  objectViewMode.value = 'active'
  objectTagForm.key = ''
  objectTagForm.tags = ''
  objectMetadata.value = null
  resetObjectVersions()
  resetObjectShareLinks()
  presignedUrl.value = ''
  shareLinkUrl.value = ''
  shareLinkPassword.value = ''
  objectNextCursor.value = ''
  objectListLimit.value = 100
  pendingMultipartUploads.value = []
  resetRetentionPolicy()
  resetLifecycleRules()
  resetLifecycleRuleConflicts()
  resetLifecycleXml()
  resetBucketLifecycleXml()
  resetBucketTags()
  resetQuotaPolicyForm()
}

async function handleCreateBucket() {
  const quotaBytes = Number(bucketForm.quotaGb || 1) * 1024 * 1024 * 1024
  const payload = { name: bucketForm.name, quotaBytes }
  if (bucketForm.ownerType === 'ORG') {
    if (!canCreateOrgBucket.value) {
      setErrorMessage('조직 버킷 생성 권한이 없습니다.')
      return
    }
    if (isAdmin.value && !bucketForm.ownerId) {
      setErrorMessage('조직을 선택해야 합니다.')
      return
    }
    payload.ownerType = 'ORG'
    payload.ownerId = isAdmin.value ? Number(bucketForm.ownerId) : session.user?.organizationId
  }
  const result = await runAction(() => createBucket(payload))
  if (result) {
    bucketForm.name = ''
    bucketForm.ownerType = 'USER'
    bucketForm.ownerId = ''
    selectedBucket.value = result.data.name
    await loadDashboard()
  }
}

function handleDeleteBucket(bucketName) {
  openConfirmDialog({
    title: '버킷 삭제',
    message: `${bucketName} 버킷을 삭제합니다. 비어 있는 버킷만 삭제할 수 있습니다.`,
    confirmLabel: '삭제',
    action: async () => {
      const result = await runAction(() => runCommand(() => deleteBucket(bucketName)))
      if (!result) return false
      if (selectedBucket.value === bucketName) {
        selectedBucket.value = ''
        objectPrefix.value = ''
        objectSearch.value = ''
        objectTagFilter.value = ''
        objectViewMode.value = 'active'
        objectTagForm.key = ''
        objectTagForm.tags = ''
        objectPrefixes.value = []
        objectNextCursor.value = ''
        objectMetadata.value = null
        resetObjectVersions()
        resetObjectShareLinks()
        presignedUrl.value = ''
        shareLinkUrl.value = ''
        shareLinkPassword.value = ''
        objects.value = []
        bucketPermissions.value = []
        resetBucketLifecycleXml()
        resetBucketTags()
      }
      await loadDashboard()
      return true
    },
  })
}

async function handleCreatePresignedUploadUrl() {
  if (!selectedBucket.value || !objectForm.key) {
    setErrorMessage('버킷과 key를 입력해야 합니다.')
    return
  }
  const tagError = validateTagInput(objectForm.tags)
  if (tagError) {
    setErrorMessage(tagError)
    return
  }
  const result = await runAction(() =>
    createPresignedUploadUrl(selectedBucket.value, {
      key: objectForm.key,
      tags: objectForm.tags,
      contentType: objectForm.file?.type || 'application/octet-stream',
      expiresInSeconds: 900,
    }),
  )
  if (result) {
    presignedUrl.value = result.data.url
    pendingUploadId.value = result.data.uploadId
  }
}

async function handleCompletePresignedUpload() {
  const result = await runAction(() =>
    completePresignedUpload(selectedBucket.value, {
      uploadId: pendingUploadId.value,
      key: objectForm.key,
    }),
  )
  if (result) {
    pendingUploadId.value = ''
    presignedUrl.value = ''
    await loadDashboard()
  }
}

async function handleCreatePresignedDownloadUrl(key) {
  const result = await runAction(() => createPresignedDownloadUrl(selectedBucket.value, key))
  if (result) {
    presignedUrl.value = result.data.url
  }
}

async function selectBucket(bucketName) {
  selectedBucket.value = bucketName
  presignedUrl.value = ''
  shareLinkUrl.value = ''
  shareLinkPassword.value = ''
  objectMetadata.value = null
  resetObjectVersions()
  resetObjectShareLinks()
  resetBucketLifecycleXml()
  resetBucketTags()
  refreshPendingMultipartUploads()
  await loadSelectedBucketDetails()
}

async function loadSelectedBucketDetails() {
  await loadObjects()
  await loadBucketPermissions()
  await loadBucketLifecycleXml()
  await loadBucketTags()
}

async function loadObjects({ append = false } = {}) {
  if (!selectedBucket.value) {
    objects.value = []
    objectPrefixes.value = []
    objectNextCursor.value = ''
    objectMetadata.value = null
    resetObjectVersions()
    resetObjectShareLinks()
    return
  }
  const tagError = validateTagInput(objectTagFilter.value)
  if (tagError) {
    setErrorMessage(tagError)
    return
  }
  const result = await runAction(() =>
    getObjects(selectedBucket.value, {
      prefix: objectPrefix.value,
      delimiter: objectViewMode.value === 'active' ? '/' : '',
      search: objectSearch.value,
      tag: objectTagFilter.value,
      cursor: append ? objectNextCursor.value : '',
      limit: objectListLimit.value,
      deleted: objectViewMode.value === 'trash',
    }),
  )
  if (result) {
    objects.value = append ? [...objects.value, ...result.items] : result.items
    objectPrefixes.value = objectViewMode.value === 'active'
      ? (append
        ? [...new Set([...objectPrefixes.value, ...(result.prefixes || [])])]
        : result.prefixes || [])
      : []
    objectNextCursor.value = result.nextCursor || ''
    if (!append) {
      objectMetadata.value = null
      resetObjectVersions()
      resetObjectShareLinks()
      shareLinkUrl.value = ''
      shareLinkPassword.value = ''
    }
  }
}

async function handleObjectViewModeChange(mode) {
  objectViewMode.value = mode
  objectNextCursor.value = ''
  objectMetadata.value = null
  resetObjectVersions()
  resetObjectShareLinks()
  await loadObjects()
}

async function handleOpenObjectPrefix(prefix) {
  objectPrefix.value = prefix
  await loadObjects()
}

async function handleSelectObjectPrefix(prefix) {
  objectPrefix.value = prefix
  await loadObjects()
}

async function handleObjectPrefixUp() {
  objectPrefix.value = parentObjectPrefix(objectPrefix.value)
  await loadObjects()
}

async function handleResetObjectFilter() {
  objectPrefix.value = ''
  objectSearch.value = ''
  objectTagFilter.value = ''
  await loadObjects()
}

function handleStartObjectTagEdit(object) {
  objectTagForm.key = object.key
  objectTagForm.tags = objectTagsToInput(object.tags)
}

async function handleLoadObjectMetadata(key) {
  const result = await runAction(() => getObjectMetadata(selectedBucket.value, key))
  if (result) {
    objectMetadata.value = result.data
  }
}

async function handleLoadObjectVersions(key) {
  objectVersions.key = key
  objectVersions.pending = true
  const result = await runAction(() => listObjectVersions(selectedBucket.value, key))
  objectVersions.pending = false
  if (result) {
    objectVersions.items = result.data || []
  }
}

function resetObjectVersions() {
  objectVersions.key = ''
  objectVersions.items = []
  objectVersions.pending = false
}

function resetObjectShareLinks() {
  objectShareLinks.key = ''
  objectShareLinks.items = []
  objectShareLinks.pending = false
}

async function handleCreateObjectShareLink(key) {
  const result = await runAction(() => createObjectShareLink(selectedBucket.value, key, {
    expiresInSeconds: 3600,
    note: 'Created from admin dashboard',
    maxDownloads: 100,
    password: shareLinkPassword.value,
  }))
  if (result) {
    shareLinkUrl.value = result.data.url
    await handleLoadObjectShareLinks(key)
    await refreshObjectShareAnalytics()
  }
}

async function refreshObjectShareAnalytics() {
  if (!isAdmin.value) {
    return
  }
  const result = await runAction(() => getObjectShareAnalytics(10))
  if (result) {
    applyObjectShareAnalytics(result.data)
  }
}

async function handleLoadObjectShareLinks(key) {
  objectShareLinks.key = key
  objectShareLinks.pending = true
  const result = await runAction(() => getObjectShareLinks(selectedBucket.value, key, 20))
  objectShareLinks.pending = false
  if (result) {
    objectShareLinks.items = result.items || []
  }
}

async function handleRevokeObjectShareLink(linkId) {
  if (!objectShareLinks.key) {
    return
  }
  objectShareLinks.pending = true
  const result = await runAction(() => runCommand(() => deleteObjectShareLink(selectedBucket.value, linkId)))
  objectShareLinks.pending = false
  if (result) {
    await handleLoadObjectShareLinks(objectShareLinks.key)
    await refreshObjectShareAnalytics()
  }
}

async function handleCleanupObjectShareLinks() {
  if (!selectedBucket.value) {
    return
  }
  objectShareLinks.pending = true
  const result = await runAction(() => cleanupObjectShareLinks(selectedBucket.value))
  objectShareLinks.pending = false
  if (result && objectShareLinks.key) {
    await handleLoadObjectShareLinks(objectShareLinks.key)
    await refreshObjectShareAnalytics()
  }
}

async function handleRestoreObjectVersion(versionId) {
  if (!objectVersions.key) {
    return
  }
  objectVersions.pending = true
  const result = await runAction(() => restoreObjectVersion(selectedBucket.value, objectVersions.key, versionId))
  objectVersions.pending = false
  if (result) {
    await loadDashboard()
    await handleLoadObjectVersions(result.data.key)
  }
}

async function handleDownloadObjectVersion(versionId) {
  if (!objectVersions.key) {
    return
  }
  const key = objectVersions.key
  const blob = await runAction(() => downloadObjectVersion(selectedBucket.value, key, versionId))
  if (!blob) {
    return
  }

  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `${key.split('/').pop() || 'download'}.version-${versionId}`
  link.click()
  URL.revokeObjectURL(url)
}

function handleDeleteObjectVersion(versionId) {
  const bucketName = selectedBucket.value
  const key = objectVersions.key
  if (!bucketName || !key) {
    return
  }
  openConfirmDialog({
    title: 'Object Version Delete',
    message: `${bucketName}/${key} version ${versionId} will be deleted permanently.`,
    confirmLabel: 'Delete',
    action: async () => {
      objectVersions.pending = true
      const result = await runAction(() => runCommand(() => deleteObjectVersion(bucketName, key, versionId)))
      objectVersions.pending = false
      if (!result) return false
      await loadDashboard()
      await handleLoadObjectVersions(key)
      return true
    },
  })
}

function handleResetObjectTagForm() {
  objectTagForm.key = ''
  objectTagForm.tags = ''
}

async function handleUpdateObjectTags() {
  if (!selectedBucket.value || !objectTagForm.key) {
    setErrorMessage('버킷과 object key를 선택해야 합니다.')
    return
  }
  const tagError = validateTagInput(objectTagForm.tags)
  if (tagError) {
    setErrorMessage(tagError)
    return
  }
  const result = await runAction(() =>
    updateObjectTags(selectedBucket.value, {
      key: objectTagForm.key,
      tags: objectTagForm.tags,
    }),
  )
  if (result) {
    objectTagForm.tags = objectTagsToInput(result.data.tags)
    await loadDashboard()
  }
}

async function handleLoadNextObjects() {
  if (!objectNextCursor.value) {
    return
  }
  await loadObjects({ append: true })
}

async function loadBucketPermissions() {
  if (!selectedBucket.value) {
    bucketPermissions.value = []
    return
  }
  try {
    const result = await getBucketPermissions(selectedBucket.value)
    bucketPermissions.value = result.items
  } catch {
    bucketPermissions.value = []
  }
}

function refreshPendingMultipartUploads() {
  pendingMultipartUploads.value = getStoredMultipartUploadSessions({
    bucketName: selectedBucket.value || undefined,
  })
}

function handleFileChange(event) {
  objectForm.file = event.target.files?.[0] ?? null
  lastUploadRequest.value = null
  uploadState.retryable = false
  uploadState.message = ''
  if (!objectForm.key && objectForm.file) {
    objectForm.key = objectForm.file.name
  }
  refreshPendingMultipartUploads()
  if (matchingMultipartResumeSession.value) {
    uploadState.message = 'Multipart resume ready'
  }
}

async function handleGrantBucketPermissionsLegacy() {
  if (!selectedBucket.value || !bucketPermissionForm.subjectId || bucketPermissionForm.permissions.length === 0) {
    errorMessage.value = '버킷, 대상, 권한을 선택해야 합니다.'
    return
  }
  const result = await runAction(() =>
    grantBucketPermissions(selectedBucket.value, {
      subjectType: bucketPermissionForm.subjectType,
      subjectId: Number(bucketPermissionForm.subjectId),
      permissions: bucketPermissionForm.permissions,
    }),
  )
  if (result) {
    bucketPermissions.value = result.items
  }
}

async function handleRevokeBucketPermissionLegacy(permissionId) {
  await runAction(() => revokeBucketPermission(selectedBucket.value, permissionId))
  await loadBucketPermissions()
}

async function handleUploadObject() {
  if (!selectedBucket.value || !objectForm.file) {
    setErrorMessage('버킷과 파일을 선택해야 합니다.')
    return
  }
  const tagError = validateTagInput(objectForm.tags)
  if (tagError) {
    setErrorMessage(tagError)
    return
  }
  const request = {
    bucketName: selectedBucket.value,
    key: objectForm.key,
    tags: objectForm.tags,
    file: objectForm.file,
  }
  lastUploadRequest.value = request
  await startObjectUpload(request)
}

async function startObjectUpload(request) {
  const controller = new AbortController()
  uploadController.value = controller
  uploadState.active = true
  uploadState.loadedBytes = 0
  uploadState.totalBytes = request.file.size || 0
  uploadState.percent = 0
  uploadState.message = ''
  uploadState.retryable = false
  clearError()

  try {
    const uploadFn = request.file.size >= MULTIPART_UPLOAD_THRESHOLD_BYTES ? uploadObjectMultipart : uploadObject
    uploadState.message = uploadFn === uploadObjectMultipart ? 'Multipart upload' : ''
    await uploadFn(request.bucketName, request.key, request.file, request.tags, updateUploadProgress, {
      signal: controller.signal,
      onResume: ({ completedBytes }) => {
        uploadState.message = completedBytes > 0 ? 'Multipart resume' : 'Multipart upload'
      },
    })
    uploadState.percent = 100
    uploadState.message = ''
    uploadState.retryable = false
    lastUploadRequest.value = null
    objectForm.key = ''
    objectForm.tags = ''
    objectForm.file = null
    refreshPendingMultipartUploads()
    await loadDashboard()
  } catch (error) {
    const aborted = controller.signal.aborted
    const message = aborted ? '업로드를 취소했습니다.' : error.message
    if (aborted) {
      setErrorMessage(message)
    } else {
      setError(error)
    }
    uploadState.message = message
    uploadState.retryable = true
    refreshPendingMultipartUploads()
  } finally {
    uploadState.active = false
    if (uploadController.value === controller) {
      uploadController.value = null
    }
  }
}

function handleCancelUpload() {
  uploadController.value?.abort()
}

async function handleRetryUpload() {
  if (!lastUploadRequest.value) {
    return
  }
  await startObjectUpload(lastUploadRequest.value)
}

async function handleResumeMatchingMultipartUpload(session) {
  if (!isMatchingResumeSession(session)) {
    return
  }
  await handleUploadObject()
}

function handleDiscardMultipartResume(storageKey) {
  deleteStoredMultipartUploadSession(storageKey)
  refreshPendingMultipartUploads()
}

function isMatchingResumeSession(session) {
  return Boolean(matchingMultipartResumeSession.value?.storageKey)
    && matchingMultipartResumeSession.value.storageKey === session.storageKey
}

function updateUploadProgress(progress) {
  uploadState.loadedBytes = progress.loaded
  uploadState.totalBytes = progress.total
  uploadState.percent = progress.percent
}

function handleDeleteObject(key) {
  const bucketName = selectedBucket.value
  openConfirmDialog({
    title: '파일 삭제',
    message: `${bucketName}/${key} 파일을 휴지통으로 이동합니다.`,
    confirmLabel: '휴지통 이동',
    action: async () => {
      const result = await runAction(() => runCommand(() => deleteObject(bucketName, key)))
      if (!result) return false
      await loadDashboard()
      return true
    },
  })
}

function handleRestoreObject(key) {
  const bucketName = selectedBucket.value
  openConfirmDialog({
    title: 'Object Restore',
    message: `${bucketName}/${key} 파일을 복구합니다.`,
    confirmLabel: 'Restore',
    action: async () => {
      const result = await runAction(() => restoreObject(bucketName, key))
      if (!result) return false
      await loadDashboard()
      return true
    },
  })
}

function handlePurgeObject(key) {
  const bucketName = selectedBucket.value
  openConfirmDialog({
    title: 'Object Purge',
    message: `${bucketName}/${key} 파일을 영구 삭제합니다. 되돌릴 수 없습니다.`,
    confirmLabel: 'Purge',
    action: async () => {
      const result = await runAction(() => runCommand(() => purgeObject(bucketName, key)))
      if (!result) return false
      await loadDashboard()
      return true
    },
  })
}

async function handleDownloadObject(key) {
  const blob = await runAction(() => downloadObject(selectedBucket.value, key))
  if (!blob) {
    return
  }

  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = key.split('/').pop() || 'download'
  link.click()
  URL.revokeObjectURL(url)
}

async function handleCreateAccessKey() {
  const result = await runAction(() =>
    createAccessKey({
      name: accessKeyForm.name,
      bucketScopes: accessKeyForm.scopes.map((scope) => ({
        bucketName: scope.bucketName,
        permissions: [...scope.permissions],
      })),
      expiresAt: null,
    }),
  )
  if (result) {
    newSecretKey.value = result.data.secretKey
    await loadDashboard()
  }
}

function handleDeleteAccessKey(keyId) {
  openConfirmDialog({
    title: 'Access Key 비활성화',
    message: `Access Key #${keyId}를 비활성화합니다. 기존 S3 클라이언트 접근이 중단됩니다.`,
    confirmLabel: '비활성화',
    action: async () => {
      const result = await runAction(() => runCommand(() => deleteAccessKey(keyId)))
      if (!result) return false
      await loadDashboard()
      return true
    },
  })
}

function handleAddAccessKeyScope() {
  if (!accessKeyForm.scopeBucket || accessKeyForm.scopePermissions.length === 0) {
    setErrorMessage('버킷과 권한을 선택해야 합니다.')
    return
  }
  const existing = accessKeyForm.scopes.find((scope) => scope.bucketName === accessKeyForm.scopeBucket)
  if (existing) {
    existing.permissions = mergePermissions(existing.permissions, accessKeyForm.scopePermissions)
    return
  }
  accessKeyForm.scopes.push({
    bucketName: accessKeyForm.scopeBucket,
    permissions: [...accessKeyForm.scopePermissions],
  })
}

function handleRemoveAccessKeyScope(bucketName) {
  const index = accessKeyForm.scopes.findIndex((scope) => scope.bucketName === bucketName)
  if (index >= 0) {
    accessKeyForm.scopes.splice(index, 1)
  }
}

async function handleGrantBucketPermissions() {
  if (!selectedBucket.value || !bucketPermissionForm.subjectId || bucketPermissionForm.permissions.length === 0) {
    setErrorMessage('버킷, 대상, 권한을 선택해야 합니다.')
    return
  }
  const result = await runAction(() =>
    grantBucketPermissions(selectedBucket.value, {
      subjectType: bucketPermissionForm.subjectType,
      subjectId: Number(bucketPermissionForm.subjectId),
      permissions: bucketPermissionForm.permissions,
    }),
  )
  if (result) {
    bucketPermissions.value = result.items
  }
}

function handleRevokeBucketPermission(permissionId) {
  const bucketName = selectedBucket.value
  openConfirmDialog({
    title: '버킷 권한 회수',
    message: `${bucketName} 버킷 권한 #${permissionId}를 회수합니다.`,
    confirmLabel: '회수',
    action: async () => {
      const result = await runAction(() => runCommand(() => revokeBucketPermission(bucketName, permissionId)))
      if (!result) return false
      await loadBucketPermissions()
      return true
    },
  })
}

function syncAccessKeyBucketSelection() {
  const bucketNames = buckets.value.map((bucket) => bucket.name)
  accessKeyForm.scopes = accessKeyForm.scopes.filter((scope) => bucketNames.includes(scope.bucketName))
  if (bucketNames.includes(accessKeyForm.scopeBucket)) {
    return
  }
  accessKeyForm.scopeBucket = bucketNames[0] ?? ''
}

async function handleCreateOrganization() {
  const defaultQuotaBytes = Number(organizationForm.defaultQuotaTb || 1) * 1024 * 1024 * 1024 * 1024
  const result = await runAction(() =>
    createOrganization({
      name: organizationForm.name,
      description: organizationForm.description,
      defaultQuotaBytes,
    }),
  )
  if (result) {
    organizationForm.name = ''
    organizationForm.description = ''
    await loadDashboard()
  }
}

async function handleCreateUser() {
  const result = await runAction(() =>
    createUser({
      loginId: userForm.loginId,
      email: userForm.email,
      name: userForm.name,
      password: userForm.password,
      role: userForm.role,
      organizationId: userForm.organizationId ? Number(userForm.organizationId) : null,
    }),
  )
  if (result) {
    userForm.loginId = ''
    userForm.email = ''
    userForm.name = ''
    userForm.password = ''
    userForm.organizationId = ''
    await loadDashboard()
  }
}

async function handleToggleUserStatus(user) {
  const nextStatus = user.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'
  if (nextStatus === 'INACTIVE') {
    openConfirmDialog({
      title: '사용자 비활성화',
      message: `${user.loginId} 사용자를 비활성화합니다. 연결된 Access Key도 사용할 수 없습니다.`,
      confirmLabel: '비활성화',
      action: () => applyUserStatus(user.id, nextStatus),
    })
    return
  }
  await applyUserStatus(user.id, nextStatus)
}

async function applyUserStatus(userId, nextStatus) {
  const result = await runAction(() => updateUserStatus(userId, nextStatus))
  if (!result) return false
  await loadDashboard()
  return true
}

function openConfirmDialog({ title, message, confirmLabel, action }) {
  Object.assign(confirmDialog, {
    open: true,
    title,
    message,
    confirmLabel: confirmLabel || '확인',
    pending: false,
    action,
  })
}

function closeConfirmDialog() {
  if (confirmDialog.pending) {
    return
  }
  Object.assign(confirmDialog, {
    open: false,
    title: '',
    message: '',
    confirmLabel: '확인',
    pending: false,
    action: null,
  })
}

async function handleConfirmDialogAction() {
  if (!confirmDialog.action) {
    closeConfirmDialog()
    return
  }
  confirmDialog.pending = true
  const action = confirmDialog.action
  const shouldClose = await action()
  confirmDialog.pending = false
  if (shouldClose !== false) {
    closeConfirmDialog()
  }
}

async function runAction(action) {
  clearError()
  try {
    return await action()
  } catch (error) {
    setError(error)
    return null
  }
}

async function runCommand(command) {
  await command()
  return true
}

function setError(error) {
  errorMessage.value = error?.message || '요청 처리 중 오류가 발생했습니다.'
  errorRequestId.value = error?.requestId || ''
}

function setErrorMessage(message) {
  errorMessage.value = message
  errorRequestId.value = ''
}

function clearError() {
  errorMessage.value = ''
  errorRequestId.value = ''
}

function formatBytes(value) {
  const bytes = Number(value || 0)
  if (bytes < 1024) return `${bytes} B`
  const units = ['KB', 'MB', 'GB', 'TB', 'PB']
  let size = bytes / 1024
  let unitIndex = 0
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024
    unitIndex += 1
  }
  return `${size.toFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]}`
}

function formatOptionalBytes(value) {
  if (value === null || value === undefined) {
    return '-'
  }
  return formatBytes(value)
}

function formatCount(value) {
  const count = Number(value || 0)
  return Number.isInteger(count) ? String(count) : count.toFixed(1)
}

function formatKeyScope(key) {
  if (key.bucketScopes?.length) {
    return key.bucketScopes
      .map((scope) => `${scope.bucketName}: ${scope.permissions?.join('+')}`)
      .join(', ')
  }
  return `${key.allowedBuckets?.join(', ')} / ${key.permissions?.join(', ')}`
}

function formatObjectTags(tags) {
  if (!tags || Object.keys(tags).length === 0) {
    return '-'
  }
  return objectTagsToInput(tags)
}

function formatChecksumMap(checksums) {
  if (!checksums || Object.keys(checksums).length === 0) {
    return '-'
  }
  return Object.entries(checksums)
    .map(([name, value]) => `${name}: ${value}`)
    .join(', ')
}

function formatDateTime(value) {
  if (!value) {
    return '-'
  }
  return new Date(value).toLocaleString()
}

function formatMultipartResumeStatus(session) {
  const updatedAt = formatDateTime(session.updatedAt)
  if (session.expired) {
    return `Expired / ${updatedAt}`
  }
  if (session.expiresAt) {
    return `Expires ${formatDateTime(session.expiresAt)} / ${updatedAt}`
  }
  return updatedAt
}

function metadataStatusLabel(status) {
  if (status === 'SYNCED') {
    return '동기화됨'
  }
  if (status === 'STALE') {
    return '불일치'
  }
  if (status === 'MISSING_IN_STORAGE') {
    return '스토리지 없음'
  }
  return status || '-'
}

function metadataStatusClass(status) {
  if (status === 'SYNCED') {
    return 'up'
  }
  if (status === 'STALE') {
    return 'mock'
  }
  return 'down'
}

function validateTagInput(tags) {
  return validateObjectTagInput(tags)
  if (!tags?.trim()) {
    return ''
  }
  const parsedKeys = new Set()
  for (const rawPair of tags.split(',')) {
    const pair = rawPair.trim()
    if (!pair) {
      continue
    }
    const separatorIndex = pair.indexOf('=')
    if (separatorIndex <= 0 || separatorIndex === pair.length - 1) {
      return '태그는 key=value 형식이어야 합니다.'
    }
    const key = pair.slice(0, separatorIndex).trim()
    const value = pair.slice(separatorIndex + 1).trim()
    if (!key || !value) {
      return '태그는 key=value 형식이어야 합니다.'
    }
    if (key.length > maxTagKeyLength) {
      return '태그 key는 128자 이하여야 합니다.'
    }
    if (!tagKeyPattern.test(key)) {
      return "태그 key는 영문/숫자와 . _ : / @ + - 만 사용할 수 있습니다."
    }
    if (value.length > maxTagValueLength) {
      return '태그 value는 256자 이하여야 합니다.'
    }
    if (/[\u0000-\u001F\u007F]/.test(value)) {
      return '태그 value에는 제어 문자를 사용할 수 없습니다.'
    }
    parsedKeys.add(key)
  }
  if (parsedKeys.size > maxTagCount) {
    return '태그는 최대 10개까지 입력할 수 있습니다.'
  }
  return ''
}

function objectTagsToInput(tags) {
  return tagsToInput(tags)
  if (!tags || Object.keys(tags).length === 0) {
    return ''
  }
  return Object.entries(tags)
    .map(([key, value]) => `${key}=${value}`)
    .join(', ')
}

function objectKeyParts(key) {
  return splitObjectKeyBySearch(key, objectSearch.value)
}

function mergePermissions(current, next) {
  const values = new Set([...(current ?? []), ...(next ?? [])])
  return ['READ', 'WRITE', 'DELETE', 'ADMIN'].filter((permission) => values.has(permission))
}

function auditFilterPayload(cursor = '') {
  return {
    eventType: auditFilter.eventType.trim(),
    actorId: auditFilter.actorId.trim(),
    requestId: auditFilter.requestId.trim(),
    targetType: auditFilter.targetType.trim(),
    targetId: auditFilter.targetId.trim(),
    result: auditFilter.result,
    cursor,
    from: localDateTimeToIso(auditFilter.from),
    to: localDateTimeToIso(auditFilter.to),
    limit: auditFilter.limit || 50,
  }
}

function localDateTimeToIso(value) {
  if (!value) {
    return ''
  }
  return new Date(value).toISOString()
}
</script>
