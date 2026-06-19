import assert from 'node:assert/strict'
import test from 'node:test'
import { downloadObject, getBuckets } from '../services/api.js'
import { useAuthStore } from './auth.js'

const TOKEN_STORAGE_KEY = 'osmu.auth.tokens'

test('downloadObject retries once with refreshed access token', async () => {
  const { sessionStorage } = installBrowserStorage()
  const fetchMock = mockFetch([
    () => jsonResponse({ error: { code: 'AUTHENTICATION_REQUIRED', message: 'expired' } }, 401),
    () => jsonResponse({
      data: {
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        user: { loginId: 'admin', role: 'ADMIN' },
      },
    }),
    () => new Response('file-body', { status: 200 }),
  ])
  const auth = useAuthStore()
  const stopSync = auth.startAuthSync()

  try {
    auth.applySession({
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      user: { loginId: 'admin', role: 'ADMIN' },
    })

    const blob = await downloadObject('media', 'hello.txt')

    assert.equal(await blob.text(), 'file-body')
    assert.equal(fetchMock.calls[0].options.headers.get('Authorization'), 'Bearer old-access')
    assert.equal(fetchMock.calls[1].url, 'http://localhost:8080/api/auth/refresh')
    assert.deepEqual(JSON.parse(fetchMock.calls[1].options.body), { refreshToken: 'old-refresh' })
    assert.equal(fetchMock.calls[2].options.headers.get('Authorization'), 'Bearer new-access')
    assert.match(sessionStorage.getItem(TOKEN_STORAGE_KEY), /new-refresh/)
  } finally {
    stopSync()
    cleanupAuthTest(fetchMock)
  }
})

test('refresh failure clears authStore state and persisted tokens', async () => {
  const { sessionStorage, localStorage } = installBrowserStorage()
  const fetchMock = mockFetch([
    () => jsonResponse({ error: { code: 'AUTHENTICATION_REQUIRED', message: 'expired' } }, 401),
    () => jsonResponse({ error: { code: 'AUTHENTICATION_REQUIRED', message: 'revoked' } }, 401),
  ])
  const auth = useAuthStore()
  const expiredReasons = []
  const stopSync = auth.startAuthSync((reason) => {
    expiredReasons.push(reason)
  })

  try {
    auth.applySession({
      accessToken: 'expired-access',
      refreshToken: 'revoked-refresh',
      user: { loginId: 'viewer', role: 'USER' },
    })

    await assert.rejects(() => getBuckets(), { code: 'AUTHENTICATION_REQUIRED', status: 401 })

    assert.equal(auth.state.user, null)
    assert.equal(auth.state.accessToken, null)
    assert.equal(auth.state.refreshToken, null)
    assert.equal(auth.isLoggedIn.value, false)
    assert.equal(auth.state.sessionNoticeReason, 'session-expired')
    assert.equal(auth.consumeSessionNoticeReason(), 'session-expired')
    assert.equal(auth.state.sessionNoticeReason, '')
    assert.equal(sessionStorage.getItem(TOKEN_STORAGE_KEY), null)
    assert.equal(localStorage.getItem(TOKEN_STORAGE_KEY), null)
    assert.deepEqual(expiredReasons, ['session-expired'])
  } finally {
    stopSync()
    cleanupAuthTest(fetchMock)
  }
})

test('unexpected refresh failure leaves an invalid session notice', async () => {
  const { sessionStorage } = installBrowserStorage()
  const fetchMock = mockFetch([
    () => jsonResponse({ error: { code: 'AUTHENTICATION_REQUIRED', message: 'expired' } }, 401),
    () => jsonResponse({ error: { code: 'INTERNAL_ERROR', message: 'refresh failed' } }, 500),
  ])
  const auth = useAuthStore()
  const expiredReasons = []
  const stopSync = auth.startAuthSync((reason) => {
    expiredReasons.push(reason)
  })

  try {
    auth.applySession({
      accessToken: 'expired-access',
      refreshToken: 'server-error-refresh',
      user: { loginId: 'viewer', role: 'USER' },
    })

    await assert.rejects(() => getBuckets(), { code: 'AUTHENTICATION_REQUIRED', status: 401 })

    assert.equal(auth.state.user, null)
    assert.equal(auth.state.accessToken, null)
    assert.equal(auth.state.refreshToken, null)
    assert.equal(auth.state.sessionNoticeReason, 'session-invalid')
    assert.equal(auth.consumeSessionNoticeReason(), 'session-invalid')
    assert.deepEqual(expiredReasons, ['session-invalid'])
    assert.equal(sessionStorage.getItem(TOKEN_STORAGE_KEY), null)
  } finally {
    stopSync()
    cleanupAuthTest(fetchMock)
  }
})

test('restoreSession loads stored tokens and current user profile', async () => {
  const { sessionStorage } = installBrowserStorage()
  const auth = useAuthStore()
  auth.clearSession()
  sessionStorage.setItem(TOKEN_STORAGE_KEY, JSON.stringify({
    accessToken: 'stored-access',
    refreshToken: 'stored-refresh',
  }))
  const fetchMock = mockFetch([
    () => jsonResponse({
      data: {
        id: 7,
        loginId: 'org-admin',
        role: 'ORG_ADMIN',
        organizationId: 3,
      },
    }),
  ])

  try {
    const restored = await auth.restoreSession()

    assert.equal(restored, true)
    assert.equal(auth.state.accessToken, 'stored-access')
    assert.equal(auth.state.refreshToken, 'stored-refresh')
    assert.equal(auth.state.user.loginId, 'org-admin')
    assert.equal(auth.isOrgAdmin.value, true)
    assert.equal(auth.canUseAdminTools.value, true)
    assert.equal(fetchMock.calls[0].url, 'http://localhost:8080/api/users/me')
    assert.equal(fetchMock.calls[0].options.headers.get('Authorization'), 'Bearer stored-access')
  } finally {
    cleanupAuthTest(fetchMock)
  }
})

test('restoreSession clears stale stored tokens and auth state when profile request fails', async () => {
  const { sessionStorage, localStorage } = installBrowserStorage()
  const auth = useAuthStore()
  auth.clearSession()
  sessionStorage.setItem(TOKEN_STORAGE_KEY, JSON.stringify({
    accessToken: 'stale-access',
    refreshToken: 'stale-refresh',
  }))
  localStorage.setItem(TOKEN_STORAGE_KEY, JSON.stringify({
    accessToken: 'auto-stale-access',
    refreshToken: 'auto-stale-refresh',
  }))
  const fetchMock = mockFetch([
    () => jsonResponse({ error: { code: 'AUTHENTICATION_REQUIRED', message: 'revoked' } }, 401),
  ])

  try {
    const restored = await auth.restoreSession()

    assert.equal(restored, false)
    assert.equal(auth.state.user, null)
    assert.equal(auth.state.accessToken, null)
    assert.equal(auth.state.refreshToken, null)
    assert.equal(auth.state.rememberSession, false)
    assert.equal(auth.isLoggedIn.value, false)
    assert.equal(auth.state.sessionNoticeReason, 'session-expired')
    assert.equal(auth.consumeSessionNoticeReason(), 'session-expired')
    assert.equal(auth.state.sessionNoticeReason, '')
    assert.equal(sessionStorage.getItem(TOKEN_STORAGE_KEY), null)
    assert.equal(localStorage.getItem(TOKEN_STORAGE_KEY), null)
    assert.equal(fetchMock.calls[0].options.headers.get('Authorization'), 'Bearer auto-stale-access')
  } finally {
    cleanupAuthTest(fetchMock)
  }
})

test('restoreSession marks stored tokens invalid when profile check fails unexpectedly', async () => {
  const { sessionStorage } = installBrowserStorage()
  const auth = useAuthStore()
  auth.clearSession()
  sessionStorage.setItem(TOKEN_STORAGE_KEY, JSON.stringify({
    accessToken: 'stored-access',
    refreshToken: 'stored-refresh',
  }))
  const fetchMock = mockFetch([
    () => jsonResponse({ error: { code: 'INTERNAL_ERROR', message: 'profile check failed' } }, 500),
  ])

  try {
    const restored = await auth.restoreSession()

    assert.equal(restored, false)
    assert.equal(auth.state.user, null)
    assert.equal(auth.state.accessToken, null)
    assert.equal(auth.state.refreshToken, null)
    assert.equal(auth.state.sessionNoticeReason, 'session-invalid')
    assert.equal(auth.consumeSessionNoticeReason(), 'session-invalid')
    assert.equal(auth.state.sessionNoticeReason, '')
    assert.equal(sessionStorage.getItem(TOKEN_STORAGE_KEY), null)
  } finally {
    cleanupAuthTest(fetchMock)
  }
})

test('applySession stores auto-login tokens in localStorage', () => {
  const { sessionStorage, localStorage } = installBrowserStorage()
  const auth = useAuthStore()
  const stopSync = auth.startAuthSync()

  try {
    auth.applySession({
      accessToken: 'auto-access',
      refreshToken: 'auto-refresh',
      user: { loginId: 'admin', role: 'ADMIN' },
    }, { rememberSession: true })

    assert.equal(sessionStorage.getItem(TOKEN_STORAGE_KEY), null)
    assert.match(localStorage.getItem(TOKEN_STORAGE_KEY), /auto-refresh/)
    assert.equal(auth.state.rememberSession, true)
  } finally {
    auth.clearSession()
    stopSync()
    delete globalThis.window
  }
})

test('clearSession removes tokens without leaving an expiration notice', () => {
  const { sessionStorage, localStorage } = installBrowserStorage()
  const auth = useAuthStore()
  const stopSync = auth.startAuthSync()

  try {
    auth.applySession({
      accessToken: 'active-access',
      refreshToken: 'active-refresh',
      user: { loginId: 'admin', role: 'ADMIN' },
    }, { rememberSession: true })

    auth.clearSession()

    assert.equal(auth.state.user, null)
    assert.equal(auth.state.accessToken, null)
    assert.equal(auth.state.refreshToken, null)
    assert.equal(auth.state.sessionNoticeReason, '')
    assert.equal(auth.consumeSessionNoticeReason(), '')
    assert.equal(sessionStorage.getItem(TOKEN_STORAGE_KEY), null)
    assert.equal(localStorage.getItem(TOKEN_STORAGE_KEY), null)
  } finally {
    stopSync()
    delete globalThis.window
  }
})

test('auditor role can use audit tools without admin tools', () => {
  const auth = useAuthStore()
  const stopSync = auth.startAuthSync()

  try {
    auth.applySession({
      accessToken: 'auditor-access',
      refreshToken: 'auditor-refresh',
      user: { loginId: 'auditor', role: 'AUDITOR' },
    })

    assert.equal(auth.isAuditor.value, true)
    assert.equal(auth.canUseAuditTools.value, true)
    assert.equal(auth.isAdmin.value, false)
    assert.equal(auth.canUseAdminTools.value, false)
  } finally {
    auth.clearSession()
    stopSync()
    delete globalThis.window
  }
})

function installBrowserStorage() {
  const sessionStorage = createMemoryStorage()
  const localStorage = createMemoryStorage()
  globalThis.window = {
    sessionStorage,
    localStorage,
    setTimeout,
    clearTimeout,
  }
  return { sessionStorage, localStorage }
}

function createMemoryStorage() {
  const items = new Map()
  return {
    get length() {
      return items.size
    },
    key(index) {
      return Array.from(items.keys())[index] ?? null
    },
    getItem(key) {
      return items.has(key) ? items.get(key) : null
    },
    setItem(key, value) {
      items.set(key, String(value))
    },
    removeItem(key) {
      items.delete(key)
    },
    clear() {
      items.clear()
    },
  }
}

function mockFetch(handlers) {
  const previousFetch = globalThis.fetch
  const calls = []
  globalThis.fetch = async (url, options = {}) => {
    calls.push({ url: String(url), options })
    const handler = handlers.shift()
    assert.ok(handler, `Unexpected fetch call: ${url}`)
    return handler(url, options)
  }
  return {
    calls,
    restore() {
      globalThis.fetch = previousFetch
    },
  }
}

function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function cleanupAuthTest(fetchMock) {
  useAuthStore().clearSession()
  fetchMock.restore()
  delete globalThis.window
}
