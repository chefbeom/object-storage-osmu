import { computed, reactive } from 'vue'
import { clearAuthTokens, getCurrentUser, setAuthStateListener, setAuthTokens } from '../services/api.js'

const TOKEN_STORAGE_KEY = 'osmu.auth.tokens'

const state = reactive({
  user: null,
  accessToken: null,
  refreshToken: null,
})

const isLoggedIn = computed(() => Boolean(state.accessToken))
const isAdmin = computed(() => state.user?.role === 'ADMIN')
const isOrgAdmin = computed(() => state.user?.role === 'ORG_ADMIN')
const canUseAdminTools = computed(() => isAdmin.value || isOrgAdmin.value)

function applySession(data) {
  state.user = data.user
  state.accessToken = data.accessToken
  state.refreshToken = data.refreshToken
  persistTokens(data)
  setAuthTokens(data)
}

function syncTokens(tokens, onExpired) {
  state.accessToken = tokens.accessToken
  state.refreshToken = tokens.refreshToken
  if (!tokens.accessToken) {
    state.user = null
    clearStoredTokens()
    onExpired?.()
    return
  }
  persistTokens(tokens)
}

function startAuthSync(onExpired) {
  setAuthStateListener((tokens) => syncTokens(tokens, onExpired))
  return () => setAuthStateListener(null)
}

async function restoreSession() {
  const tokens = readStoredTokens()
  if (!tokens) {
    return false
  }

  state.accessToken = tokens.accessToken
  state.refreshToken = tokens.refreshToken
  setAuthTokens(tokens)

  try {
    const profile = await getCurrentUser()
    state.user = profile.data
    return true
  } catch {
    clearStoredTokens()
    clearAuthTokens()
    return false
  }
}

function persistTokens(tokens) {
  const storage = tokenStorage()
  if (!tokens?.accessToken || !tokens?.refreshToken || !storage) {
    clearStoredTokens()
    return
  }
  storage.setItem(TOKEN_STORAGE_KEY, JSON.stringify({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
  }))
}

function readStoredTokens() {
  const storage = tokenStorage()
  if (!storage) {
    return null
  }
  const raw = storage.getItem(TOKEN_STORAGE_KEY)
  if (!raw) {
    return null
  }
  try {
    const tokens = JSON.parse(raw)
    if (!tokens.accessToken || !tokens.refreshToken) {
      clearStoredTokens()
      return null
    }
    return tokens
  } catch {
    clearStoredTokens()
    return null
  }
}

function clearStoredTokens() {
  tokenStorage()?.removeItem(TOKEN_STORAGE_KEY)
}

function tokenStorage() {
  try {
    return typeof window === 'undefined' ? null : window.sessionStorage
  } catch {
    return null
  }
}

export function useAuthStore() {
  return {
    state,
    isLoggedIn,
    isAdmin,
    isOrgAdmin,
    canUseAdminTools,
    applySession,
    restoreSession,
    startAuthSync,
  }
}
