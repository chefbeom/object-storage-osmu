<template>
  <main class="login-page">
    <section class="login-rail" aria-labelledby="login-title">
      <p class="eyebrow">Private Object Storage</p>
      <h1 id="login-title">OSMU</h1>
      <p>
        관리자는 스토리지 운영과 권한을 제어하고, 개발자는 S3 호환 API Key로
        데이터를 저장하고 재사용하는 콘솔입니다.
      </p>
      <div class="login-capability-list">
        <span>REST API</span>
        <span>S3 Compatible</span>
        <span>MinIO Pool</span>
        <span>Access Key</span>
      </div>
    </section>

    <section class="login-panel" aria-label="로그인">
      <form class="login-form" data-testid="login-form" @submit.prevent="handleLogin">
        <div>
          <p class="eyebrow">Sign in</p>
          <h2>계정으로 로그인</h2>
        </div>

        <div class="login-mode-grid" role="radiogroup" aria-label="로그인 유형">
          <label
            :class="['login-role-card', { active: loginForm.mode === 'admin' }]"
            data-testid="login-role-admin"
          >
            <input
              data-testid="login-mode-admin"
              v-model="loginForm.mode"
              type="radio"
              value="admin"
            />
            <span>
              <strong>관리자</strong>
              <small>용량 증설, JBOD 및 RAID 0/1/5/6/10-like, IAM User 발급, 권한 부여 및 운영 작업</small>
            </span>
          </label>

          <label
            :class="['login-role-card', { active: loginForm.mode === 'developer' }]"
            data-testid="login-role-developer"
          >
            <input
              data-testid="login-mode-developer"
              v-model="loginForm.mode"
              type="radio"
              value="developer"
            />
            <span>
              <strong>개발자</strong>
              <small>API Key로 S3 호환 bucket에 데이터 저장과 조회</small>
            </span>
          </label>
        </div>

        <label>
          아이디
          <input
            data-testid="login-id-input"
            v-model.trim="loginForm.loginId"
            autocomplete="username"
            placeholder="admin"
            required
          />
        </label>

        <label>
          비밀번호
          <span class="password-field">
            <input
              data-testid="login-password-input"
              v-model="loginForm.password"
              :type="showPassword ? 'text' : 'password'"
              autocomplete="current-password"
              placeholder="password"
              required
            />
            <button
              data-testid="login-password-toggle"
              type="button"
              class="ghost password-toggle"
              @click="showPassword = !showPassword"
            >
              {{ showPassword ? '숨기기' : '보기' }}
            </button>
          </span>
        </label>

        <div class="login-options">
          <label class="check">
            <input
              data-testid="login-auto-login-checkbox"
              v-model="loginForm.autoLogin"
              type="checkbox"
            />
            자동 로그인
          </label>
          <label class="check">
            <input
              data-testid="login-remember-id-checkbox"
              v-model="loginForm.rememberId"
              type="checkbox"
            />
            아이디 저장
          </label>
        </div>

        <p v-if="sessionNotice" class="notice" data-testid="login-info-alert">
          {{ sessionNotice }}
        </p>
        <p v-if="errorMessage" class="alert" data-testid="login-error-alert">
          {{ errorMessage }}
        </p>

        <button data-testid="login-submit-button" type="submit" :disabled="pending">
          {{ pending ? '로그인 중' : loginButtonLabel }}
        </button>
      </form>
    </section>
  </main>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { login } from '@/services/api'
import { useAuthStore } from '@/stores/auth'

const REMEMBERED_LOGIN_ID_KEY = 'osmu.login.rememberedId'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const loginForm = reactive({
  loginId: '',
  password: '',
  mode: 'admin',
  autoLogin: false,
  rememberId: false,
})
const showPassword = ref(false)
const pending = ref(false)
const errorMessage = ref('')

const loginButtonLabel = computed(() => (
  loginForm.mode === 'developer' ? '개발자 콘솔로 로그인' : '관리자 콘솔로 로그인'
))
const sessionNotice = computed(() => sessionNoticeMessage(route.query.reason))

onMounted(() => {
  const rememberedLoginId = readRememberedLoginId()
  if (rememberedLoginId) {
    loginForm.loginId = rememberedLoginId
    loginForm.rememberId = true
  }
  if (route.query.mode === 'developer') {
    loginForm.mode = 'developer'
  }
})

async function handleLogin() {
  errorMessage.value = ''
  pending.value = true
  try {
    const result = await login(loginForm.loginId, loginForm.password)
    persistRememberedLoginId()
    auth.applySession(result.data, { rememberSession: loginForm.autoLogin })
    await router.push(nextPath(result.data?.user?.role))
  } catch (error) {
    errorMessage.value = error?.message || '로그인 실패'
  } finally {
    pending.value = false
  }
}

function persistRememberedLoginId() {
  const storage = browserLocalStorage()
  if (!storage) return
  if (loginForm.rememberId || loginForm.autoLogin) {
    storage.setItem(REMEMBERED_LOGIN_ID_KEY, loginForm.loginId)
    return
  }
  storage.removeItem(REMEMBERED_LOGIN_ID_KEY)
}

function readRememberedLoginId() {
  return browserLocalStorage()?.getItem(REMEMBERED_LOGIN_ID_KEY) || ''
}

function nextPath(role) {
  const redirect = safeRedirectPath(route.query.redirect)
  if (redirect && canAccessPath(redirect, role)) {
    return redirect
  }
  if (loginForm.mode === 'admin' && (role === 'ADMIN' || role === 'ORG_ADMIN')) {
    return '/admin'
  }
  if (loginForm.mode === 'admin' && role === 'USER') {
    return { path: '/developer', query: { notice: 'admin-role-required' } }
  }
  return loginForm.mode === 'developer' || role === 'USER' ? '/developer' : '/dashboard'
}

function safeRedirectPath(value) {
  const path = Array.isArray(value) ? value[0] : value
  if (typeof path !== 'string') {
    return ''
  }
  return path.startsWith('/') && !path.startsWith('//') ? path : ''
}

function canAccessPath(path, role) {
  if (path.startsWith('/audit')) {
    return role === 'ADMIN' || role === 'AUDITOR'
  }
  if (path.startsWith('/admin')) {
    return role === 'ADMIN' || role === 'ORG_ADMIN'
  }
  return true
}

function browserLocalStorage() {
  try {
    return typeof window === 'undefined' ? null : window.localStorage
  } catch {
    return null
  }
}

function sessionNoticeMessage(reason) {
  const value = Array.isArray(reason) ? reason[0] : reason
  if (value === 'session-expired') {
    return '세션이 만료되었습니다. 다시 로그인해주세요.'
  }
  if (value === 'session-invalid') {
    return '저장된 로그인 정보를 확인할 수 없습니다. 다시 로그인해주세요.'
  }
  return ''
}
</script>
