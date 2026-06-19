import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import LoginView from '../views/LoginView.vue'
import { useAuthStore } from '../stores/auth.js'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: '/dashboard',
    },
    {
      path: '/login',
      name: 'login',
      component: LoginView,
      meta: { public: true },
    },
    {
      path: '/dashboard',
      name: 'dashboard',
      component: HomeView,
      meta: { requiresAuth: true },
    },
    {
      path: '/storage',
      name: 'storage',
      component: HomeView,
      meta: { requiresAuth: true },
    },
    {
      path: '/objects',
      name: 'objects',
      component: HomeView,
      meta: { requiresAuth: true },
    },
    {
      path: '/developer',
      name: 'developer',
      component: HomeView,
      meta: { requiresAuth: true },
    },
    {
      path: '/admin',
      name: 'admin',
      component: HomeView,
      meta: { requiresAuth: true, roles: ['ADMIN', 'ORG_ADMIN'] },
    },
    {
      path: '/audit',
      name: 'audit',
      component: HomeView,
      meta: { requiresAuth: true, roles: ['ADMIN', 'AUDITOR'] },
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/dashboard',
    },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  const hasSession = auth.isLoggedIn.value || await auth.restoreSession()

  if (to.name === 'login') {
    if (hasSession) {
      const redirect = safeRedirectPath(to.query.redirect)
      if (redirect && canAccessPath(redirect, auth.state.user?.role)) {
        return redirect
      }
      if (to.query.mode === 'developer') {
        return '/developer'
      }
      if (to.query.mode === 'admin') {
        return adminLandingPathForRole(auth.state.user?.role)
      }
      return defaultLandingPathForRole(auth.state.user?.role)
    }
    return true
  }

  if (to.meta.requiresAuth && !hasSession) {
    const reason = auth.consumeSessionNoticeReason()
    return {
      name: 'login',
      query: {
        redirect: to.fullPath || '/dashboard',
        ...(reason ? { reason } : {}),
      },
    }
  }

  if (to.meta.roles && !to.meta.roles.includes(auth.state.user?.role)) {
    return fallbackPathForRole(auth.state.user?.role)
  }

  return true
})

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

function adminLandingPathForRole(role) {
  return role === 'ADMIN' || role === 'ORG_ADMIN' ? '/admin' : '/developer'
}

function defaultLandingPathForRole(role) {
  return role === 'USER' ? '/developer' : '/dashboard'
}

function fallbackPathForRole(role) {
  if (role === 'ADMIN') {
    return '/dashboard'
  }
  if (role === 'ORG_ADMIN') {
    return '/admin'
  }
  if (role === 'AUDITOR') {
    return '/dashboard'
  }
  return '/developer'
}

export default router
