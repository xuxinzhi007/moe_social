import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import {
  createAdminClient,
  formatFetchError,
  type AdminClient,
} from '../api/adminClient'
import { useDeploy } from './DeployContext'
import { usePlatform } from './PlatformContext'
import {
  clearAdminSession,
  loadAdminToken,
  loadAdminUser,
  saveAdminSession,
  type StoredAdminUser,
} from '../lib/adminStorage'

type AdminAuthContextValue = {
  token: string
  user: StoredAdminUser | null
  client: AdminClient
  bootstrapped: boolean
  loggingIn: boolean
  login: (username: string, password: string) => Promise<string | null>
  logout: () => void
  refreshMe: () => Promise<void>
}

const AdminAuthContext = createContext<AdminAuthContextValue | null>(null)

export function AdminAuthProvider({ children }: { children: ReactNode }) {
  const { baseUrl } = useDeploy()
  const { apiTarget, health } = usePlatform()
  const [token, setToken] = useState(() => loadAdminToken())
  const [user, setUser] = useState<StoredAdminUser | null>(() => loadAdminUser())
  const [bootstrapped, setBootstrapped] = useState(false)
  const [loggingIn, setLoggingIn] = useState(false)

  const client = useMemo(
    () =>
      createAdminClient({
        baseUrl,
        token,
        apiTarget,
        cloudApiBaseUrl: health?.cloud_api?.base_url,
      }),
    [apiTarget, baseUrl, health?.cloud_api?.base_url, token],
  )

  const refreshMe = useCallback(async () => {
    if (!token) return
    try {
      const res = await client.me()
      if (res.success && res.data) {
        const u: StoredAdminUser = {
          admin_id: res.data.admin_id,
          username: res.data.username,
          role: res.data.role,
        }
        setUser(u)
        saveAdminSession(token, u)
      }
    } catch {
      clearAdminSession()
      setToken('')
      setUser(null)
    }
  }, [client, token])

  useEffect(() => {
    let cancelled = false
    async function boot() {
      if (!token) {
        if (!cancelled) setBootstrapped(true)
        return
      }
      await refreshMe()
      if (!cancelled) setBootstrapped(true)
    }
    void boot()
    return () => {
      cancelled = true
    }
  }, [refreshMe, token])

  const login = useCallback(
    async (username: string, password: string) => {
      setLoggingIn(true)
      try {
        const res = await client.login(username, password)
        if (!res.success || !res.data?.token) {
          return res.message || '登录失败'
        }
        const t = res.data.token
        const u: StoredAdminUser = {
          admin_id: res.data.admin_id,
          username: res.data.username,
          role: res.data.role,
        }
        saveAdminSession(t, u)
        setToken(t)
        setUser(u)
        return null
      } catch (e) {
        return formatFetchError(e)
      } finally {
        setLoggingIn(false)
      }
    },
    [client],
  )

  const logout = useCallback(() => {
    clearAdminSession()
    setToken('')
    setUser(null)
  }, [])

  const value = useMemo(
    () => ({
      token,
      user,
      client,
      bootstrapped,
      loggingIn,
      login,
      logout,
      refreshMe,
    }),
    [
      bootstrapped,
      client,
      login,
      loggingIn,
      logout,
      refreshMe,
      token,
      user,
    ],
  )

  return (
    <AdminAuthContext.Provider value={value}>{children}</AdminAuthContext.Provider>
  )
}

export function useAdminAuth() {
  const ctx = useContext(AdminAuthContext)
  if (!ctx) {
    throw new Error('useAdminAuth must be used within AdminAuthProvider')
  }
  return ctx
}
