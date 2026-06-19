<template>
  <article v-if="isLoggedIn && selectedBucket && canShowBucketPermissions" class="panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Permissions</p>
        <h3>버킷 권한</h3>
      </div>
      <strong class="bucket-label">{{ selectedBucket }}</strong>
    </div>
    <form class="inline-form permission-form" @submit.prevent="$emit('grant-bucket-permissions')">
      <select v-model="bucketPermissionForm.subjectType">
        <option value="USER">USER</option>
        <option value="ORGANIZATION">ORGANIZATION</option>
        <option value="TEAM">TEAM</option>
      </select>
      <select v-if="bucketPermissionForm.subjectType === 'USER' && users.length > 0" v-model="bucketPermissionForm.subjectId">
        <option value="">User</option>
        <option v-for="user in users" :key="user.id" :value="user.id">{{ user.loginId }}</option>
      </select>
      <select v-else-if="bucketPermissionForm.subjectType === 'ORGANIZATION' && organizations.length > 0" v-model="bucketPermissionForm.subjectId">
        <option value="">Org</option>
        <option v-for="organization in organizations" :key="organization.id" :value="organization.id">{{ organization.name }}</option>
      </select>
      <select v-else-if="bucketPermissionForm.subjectType === 'TEAM' && teams.length > 0" v-model="bucketPermissionForm.subjectId">
        <option value="">Team</option>
        <option v-for="team in teams" :key="team.id" :value="team.id">{{ team.name }}</option>
      </select>
      <input v-else v-model="bucketPermissionForm.subjectId" type="number" min="1" placeholder="subject id" />
      <div class="permission-row">
        <label class="check"><input v-model="bucketPermissionForm.permissions" type="checkbox" value="READ" />READ</label>
        <label class="check"><input v-model="bucketPermissionForm.permissions" type="checkbox" value="WRITE" />WRITE</label>
        <label class="check"><input v-model="bucketPermissionForm.permissions" type="checkbox" value="DELETE" />DELETE</label>
        <label class="check"><input v-model="bucketPermissionForm.permissions" type="checkbox" value="ADMIN" />ADMIN</label>
      </div>
      <button type="submit" :disabled="bucketPermissionForm.permissions.length === 0">부여</button>
    </form>
    <ul class="compact-list">
      <li v-for="permission in bucketPermissions" :key="permission.id">
        <span>{{ permission.subjectType }} #{{ permission.subjectId }} / {{ permission.permission }}</span>
        <button type="button" class="danger" @click="$emit('revoke-bucket-permission', permission.id)">회수</button>
      </li>
      <li v-if="bucketPermissions.length === 0" class="empty">권한 없음</li>
    </ul>
  </article>
</template>

<script setup>
defineProps({
  isLoggedIn: { type: Boolean, required: true },
  selectedBucket: { type: String, required: true },
  canShowBucketPermissions: { type: Boolean, required: true },
  bucketPermissionForm: { type: Object, required: true },
  users: { type: Array, required: true },
  organizations: { type: Array, required: true },
  teams: { type: Array, required: true },
  bucketPermissions: { type: Array, required: true },
})

defineEmits([
  'grant-bucket-permissions',
  'revoke-bucket-permission',
])
</script>
