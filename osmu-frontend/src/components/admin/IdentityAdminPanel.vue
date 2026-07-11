<template>
  <article v-if="canUseAdminTools" class="panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Organizations</p>
        <h3>조직 관리</h3>
      </div>
    </div>
    <form class="inline-form organization-form" @submit.prevent="$emit('create-organization')">
      <input v-model="organizationForm.name" placeholder="AI Research Team" />
      <input v-model="organizationForm.description" placeholder="description" />
      <input v-model.number="organizationForm.defaultQuotaTb" min="1" type="number" />
      <button type="submit" :disabled="!isLoggedIn">생성</button>
    </form>
    <ul class="compact-list">
      <li v-for="organization in organizationUsages" :key="organization.id">
        <span class="list-main">
          <b>{{ organization.name }}</b>
          <small>{{ formatBytes(organization.usedBytes) }} / {{ formatBytes(organization.defaultQuotaBytes || organization.bucketQuotaBytes) }}</small>
        </span>
        <strong>#{{ organization.id }}</strong>
      </li>
      <li v-if="organizationUsages.length === 0" class="empty">조직 없음</li>
    </ul>
  </article>

  <article v-if="canUseAdminTools" class="panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Teams</p>
        <h3>팀 권한 그룹</h3>
      </div>
      <div class="panel-head-actions">
        <small>{{ teams.length }}{{ teamsNextCursor ? '+' : '' }} teams</small>
        <select data-testid="team-organization-filter" :value="teamOrganizationFilter" @change="$emit('update-team-organization-filter', $event.target.value)">
          <option value="">All organizations</option>
          <option v-for="organization in organizations" :key="organization.id" :value="organization.id">{{ organization.name }}</option>
        </select>
      </div>
    </div>
    <form class="inline-form team-form" @submit.prevent="$emit('create-team')">
      <select v-model="teamForm.organizationId">
        <option value="">Org</option>
        <option v-for="organization in organizations" :key="organization.id" :value="organization.id">{{ organization.name }}</option>
      </select>
      <input v-model="teamForm.name" placeholder="Data Platform" />
      <input v-model="teamForm.description" placeholder="description" />
      <select v-model="teamForm.memberIds" multiple>
        <option v-for="user in users" :key="user.id" :value="user.id">{{ user.loginId }}</option>
      </select>
      <button type="submit" :disabled="!isLoggedIn">생성</button>
    </form>
    <ul class="compact-list">
      <li v-for="team in teams" :key="team.id">
        <span class="list-main">
          <b>{{ team.name }}</b>
          <small>org {{ team.organizationId }} / members {{ team.memberIds?.length || 0 }}</small>
        </span>
        <button type="button" class="danger" @click="$emit('delete-team', team)">삭제</button>
      </li>
      <li v-if="teams.length === 0" class="empty">팀 없음</li>
    </ul>
    <button
      v-if="teamsNextCursor"
      data-testid="team-load-more-button"
      type="button"
      class="ghost"
      :disabled="teamsLoading"
      @click="$emit('load-more-teams')"
    >
      {{ teamsLoading ? 'Loading...' : 'Load more' }}
    </button>
  </article>

  <article v-if="canUseAdminTools" class="panel">
    <div class="panel-head">
      <div>
        <p class="eyebrow">Users</p>
        <h3>사용자 관리</h3>
      </div>
      <small>{{ users.length }}{{ usersNextCursor ? '+' : '' }} users</small>
    </div>
    <form class="inline-form user-form" @submit.prevent="$emit('create-user')">
      <input v-model="userForm.loginId" placeholder="user1" />
      <input v-model="userForm.email" placeholder="user1@example.com" />
      <input v-model="userForm.name" placeholder="User One" />
      <input v-model="userForm.password" type="password" placeholder="password" />
      <select v-model="userForm.organizationId">
        <option value="">No org</option>
        <option v-for="organization in organizations" :key="organization.id" :value="organization.id">{{ organization.name }}</option>
      </select>
      <select v-model="userForm.role">
        <option value="USER">USER</option>
        <option v-if="isAdmin" value="ORG_ADMIN">ORG_ADMIN</option>
        <option v-if="isAdmin" value="AUDITOR">AUDITOR</option>
        <option v-if="isAdmin" value="ADMIN">ADMIN</option>
      </select>
      <button type="submit" :disabled="!isLoggedIn">생성</button>
    </form>
    <ul class="compact-list">
      <li v-for="user in users" :key="user.id">
        <span>{{ user.loginId }} / {{ user.role }} / org {{ user.organizationId || '-' }}</span>
        <button type="button" :class="user.status === 'ACTIVE' ? 'danger' : 'ghost'" :disabled="session.user?.id === user.id" @click="$emit('toggle-user-status', user)">
          {{ user.status === 'ACTIVE' ? '비활성화' : '활성화' }}
        </button>
      </li>
      <li v-if="users.length === 0" class="empty">사용자 없음</li>
    </ul>
    <button
      v-if="usersNextCursor"
      data-testid="user-load-more-button"
      type="button"
      class="ghost"
      :disabled="usersLoading"
      @click="$emit('load-more-users')"
    >
      {{ usersLoading ? 'Loading...' : 'Load more' }}
    </button>
  </article>
</template>

<script setup>
defineProps({
  canUseAdminTools: { type: Boolean, required: true },
  organizationForm: { type: Object, required: true },
  organizationUsages: { type: Array, required: true },
  teamForm: { type: Object, required: true },
  teamOrganizationFilter: { type: String, default: '' },
  teams: { type: Array, required: true },
  teamsNextCursor: { type: String, default: '' },
  teamsLoading: { type: Boolean, required: true },
  userForm: { type: Object, required: true },
  users: { type: Array, required: true },
  usersNextCursor: { type: String, default: '' },
  usersLoading: { type: Boolean, required: true },
  organizations: { type: Array, required: true },
  isLoggedIn: { type: Boolean, required: true },
  isAdmin: { type: Boolean, required: true },
  session: { type: Object, required: true },
  formatBytes: { type: Function, required: true },
})

defineEmits([
  'create-organization',
  'create-team',
  'delete-team',
  'update-team-organization-filter',
  'load-more-teams',
  'create-user',
  'toggle-user-status',
  'load-more-users',
])
</script>
