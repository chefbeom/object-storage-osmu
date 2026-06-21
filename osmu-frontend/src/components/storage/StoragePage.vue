<template>
  <section id="storage-workbench" class="content-grid single-page-grid">
    <article id="storage-buckets" class="panel" data-testid="bucket-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Buckets</p>
          <h3>Bucket management</h3>
        </div>
        <span class="bucket-label">{{ buckets.length }} buckets</span>
      </div>

      <form class="inline-form bucket-form" data-testid="bucket-create-form" @submit.prevent="$emit('create-bucket')">
        <input data-testid="bucket-name-input" v-model="bucketForm.name" placeholder="project-data" />
        <input data-testid="bucket-quota-input" v-model.number="bucketForm.quotaGb" min="1" type="number" />
        <select data-testid="bucket-owner-type-select" v-model="bucketForm.ownerType" :disabled="!canCreateOrgBucket">
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
          data-testid="bucket-create-button"
          type="submit"
          :disabled="!isLoggedIn || !bucketForm.name || (bucketForm.ownerType === 'ORG' && isAdmin && !bucketForm.ownerId)"
        >
          Create
        </button>
      </form>

      <div class="table-wrap">
        <table data-testid="bucket-table">
          <thead>
            <tr>
              <th>Bucket</th>
              <th>Usage</th>
              <th>Objects</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="bucket in bucketRows"
              :key="bucket.name"
              :data-testid="`bucket-row-${bucket.name}`"
              :class="{ selected: selectedBucket === bucket.name }"
              @click="$emit('select-bucket', bucket.name)"
            >
              <td>
                <strong data-testid="bucket-row-name">{{ bucket.name }}</strong>
                <small>{{ bucket.ownerType || 'USER' }} #{{ bucket.ownerId || '-' }}</small>
              </td>
              <td data-testid="bucket-row-usage">{{ bucket.usageLabel }}</td>
              <td data-testid="bucket-row-object-count">{{ bucket.objectCount }}</td>
              <td class="actions">
                <button data-testid="bucket-sync-button" type="button" class="ghost" @click.stop="$emit('sync-bucket', bucket.name)">
                  Sync
                </button>
                <button data-testid="bucket-delete-button" type="button" class="danger" @click.stop="$emit('delete-bucket', bucket.name)">
                  Delete
                </button>
              </td>
            </tr>
            <tr v-if="buckets.length === 0">
              <td colspan="4" class="empty">Create or select a bucket after login.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </article>

    <article v-if="isLoggedIn && selectedBucket" class="panel" data-testid="storage-profile-panel">
      <div class="panel-head">
        <div>
          <p class="eyebrow">Storage Profile</p>
          <h3>Bucket profile request</h3>
        </div>
        <span class="bucket-label">{{ selectedBucket }}</span>
      </div>

      <div class="storage-expansion-preview">
        <dl class="detail-list">
          <div>
            <dt>Active</dt>
            <dd>{{ bucketStorageProfile?.assignment?.profile?.name || 'Standard' }}</dd>
          </div>
          <div>
            <dt>Alias</dt>
            <dd>{{ bucketStorageProfile?.assignment?.profile?.alias || 'Erasure Coding' }}</dd>
          </div>
          <div>
            <dt>Risk</dt>
            <dd>{{ bucketStorageProfile?.assignment?.profile?.riskLevel || 'MEDIUM' }}</dd>
          </div>
          <div>
            <dt>MinIO binding</dt>
            <dd>{{ bucketStorageProfile?.assignment?.profile?.poolSelector || 'osmu.storage-profile=standard' }}</dd>
          </div>
        </dl>
      </div>

      <form class="inline-form" data-testid="storage-profile-request-form" @submit.prevent="$emit('create-storage-profile-request')">
        <select data-testid="storage-profile-select" v-model="storageProfileForm.requestedProfile">
          <option v-for="profile in storageProfiles" :key="profile.code" :value="profile.code">
            {{ profile.name }} / {{ profile.alias }}
          </option>
        </select>
        <input
          data-testid="storage-profile-reason-input"
          v-model="storageProfileForm.reason"
          placeholder="Reason: video ingest throughput"
        />
        <button data-testid="storage-profile-request-button" type="submit" :disabled="!storageProfileForm.requestedProfile">
          Request
        </button>
        <button type="button" class="ghost" @click="$emit('refresh-bucket-storage-profile')">Refresh</button>
      </form>

      <div class="table-wrap">
        <table data-testid="storage-profile-request-table">
          <thead>
            <tr>
              <th>Bucket</th>
              <th>Requested</th>
              <th>Status</th>
              <th>Updated</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="request in visibleStorageProfileRequests"
              :key="request.id"
              data-testid="storage-profile-request-row"
            >
              <td>{{ request.bucketName }}</td>
              <td>{{ request.requestedProfile?.name || request.requestedProfile?.code }}</td>
              <td><strong data-testid="storage-profile-request-status" :class="['status-pill', statusClass(request.status)]">{{ request.status }}</strong></td>
              <td>{{ formatDateTime(request.updatedAt) }}</td>
            </tr>
            <tr v-if="visibleStorageProfileRequests.length === 0">
              <td colspan="4" class="empty">No storage profile request for selected bucket.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </article>
  </section>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  buckets: { type: Array, required: true },
  bucketRows: { type: Array, required: true },
  bucketForm: { type: Object, required: true },
  canCreateOrgBucket: { type: Boolean, required: true },
  isAdmin: { type: Boolean, required: true },
  organizations: { type: Array, required: true },
  isLoggedIn: { type: Boolean, required: true },
  selectedBucket: { type: String, required: true },
  storageProfiles: { type: Array, required: true },
  bucketStorageProfile: { type: Object, default: null },
  storageProfileForm: { type: Object, required: true },
  storageProfileRequests: { type: Array, required: true },
  formatDateTime: { type: Function, required: true },
  statusClass: { type: Function, required: true },
})

defineEmits([
  'create-bucket',
  'select-bucket',
  'sync-bucket',
  'delete-bucket',
  'create-storage-profile-request',
  'refresh-bucket-storage-profile',
])

const visibleStorageProfileRequests = computed(() => props.storageProfileRequests
  .filter((request) => request.bucketName === props.selectedBucket)
  .slice(0, 5))
</script>
