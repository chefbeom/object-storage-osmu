import { computed, reactive } from 'vue'
import { clearAuthTokens, getCurrentUser, setAuthStateListener, setAuthTokens } from '../services/api.js'

const TOKEN_STORAGE_KEY = 'osmu.auth.tokens'

const state = reactive({
  user: null,
  accessToken: null,
  refreshToken: null,
  rememberSession: false,
})

const isLoggedIn = computed(() => Boolean(state.accessToken))
const isAdmin = computed(() => state.user?.role === 'ADMIN')
const isOrgAdmin = computed(() => state.user?.role === 'ORG_ADMIN')
const canUseAdminTools = computed(() => isAdmin.value || isOrgAdmin.value)

function applySession(data, options = {}) {
  state.user = data.user
  state.accessToken = data.accessToken
  state.refreshToken = data.refreshToken
  state.rememberSession = Boolean(options.rememberSession)
  persistTokens(data, state.rememberSession)
  setAuthTokens(data)
}

function syncTokens(tokens, onExpired) {
  state.accessToken = tokens.accessToken
  state.refreshToken = tokens.refreshToken
  if (!tokens.accessToken) {
    resetSessionState()
    onExpired?.()
    return
  }
  persistTokens(tokens, state.rememberSession)
}

function startAuthSync(onExpired) {
  setAuthStateListener((tokens) => syncTokens(tokens, onExpired))
  return () => setAuthStateListener(null)
}

async function restoreSession() {
  const stored = readStoredTokens()
  if (!stored) {
    return false
  }
  const { tokens, rememberSession } = stored

  state.accessToken = tokens.accessToken
  state.refreshToken = tokens.refreshToken
  state.rememberSession = rememberSession
  setAuthTokens(tokens)

  try {
    const profile = await getCurrentUser()
    state.user = profile.data
    return true
  } catch {
    resetSessionState()
    clearAuthTokens()
    return false
  }
}

function clearSession() {
  resetSessionState()
  clearAuthTokens()
}

function resetSessionState() {
  state.user = null
  state.accessToken = null
  state.refreshToken = null
  state.rememberSession = false
  clearStoredTokens()
}

function persistTokens(tokens, rememberSession = false) {
  const storage = tokenStorage(rememberSession)
  if (!tokens?.accessToken || !tokens?.refreshToken || !storage) {
    clearStoredTokens()
    return
  }
  storage.setItem(TOKEN_STORAGE_KEY, JSON.stringify({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
  }))
  tokenStorage(!rememberSession)?.removeItem(TOKEN_STORAGE_KEY)
}

function readStoredTokens() {
  return readStoredTokensFrom(tokenStorage(true), true)
    ?? readStoredTokensFrom(tokenStorage(false), false)
}

function readStoredTokensFrom(storage, rememberSession) {
  const raw = storage?.getItem(TOKEN_STORAGE_KEY)
  if (!raw) {
    return null
  }
  try {
    const tokens = JSON.parse(raw)
    if (!tokens.accessToken || !tokens.refreshToken) {
      storage.removeItem(TOKEN_STORAGE_KEY)
      return null
    }
    return { tokens, rememberSession }
  } catch {
    storage.removeItem(TOKEN_STORAGE_KEY)
    return null
  }
}

function clearStoredTokens() {
  tokenStorage(false)?.removeItem(TOKEN_STORAGE_KEY)
  tokenStorage(true)?.removeItem(TOKEN_STORAGE_KEY)
}

function tokenStorage(rememberSession = false) {
  try {
    if (typeof window === 'undefined') {
      return null
    }
    return rememberSession ? window.localStorage : window.sessionStorage
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
    clearSession,
  }
}
