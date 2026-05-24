import { adminApiPath, useDirectAdminApi } from '../lib/adminApi'
import { DeployApiError } from './deployClient'

export function formatFetchError(e: unknown): string {
  if (e instanceof DeployApiError) return e.message
  if (e instanceof TypeError) {
    if (useDirectAdminApi()) {
      return '无法连接本机 API，请确认 RPC (:8080) 与 API (:8888) 已启动'
    }
    return '无法连接网关，请确认 Deploy Agent 已在 :19010 运行'
  }
  return '网络请求失败，请检查服务是否已启动'
}

export type AdminClientOptions = {
  baseUrl: string
  token: string
  apiTarget: string
}

type BaseResp<T> = {
  success: boolean
  code?: number
  message?: string
  data?: T
}

export function createAdminClient(opts: AdminClientOptions) {
  const base = opts.baseUrl.replace(/\/$/, '')

  async function api<T>(
    path: string,
    init?: RequestInit & { auth?: boolean },
  ): Promise<T> {
    const headers = new Headers(init?.headers)
    const useAuth = init?.auth !== false
    if (useAuth && opts.token) {
      headers.set('X-Admin-Token', opts.token)
    }
    const full = path.startsWith('http') ? path : `${base}${path}`
    const url = new URL(full)
    if (opts.apiTarget && path.includes('/api/deploy/')) {
      url.searchParams.set('target', opts.apiTarget)
    }
    let res: Response
    try {
      res = await fetch(url.toString(), { ...init, headers })
    } catch (e) {
      throw new DeployApiError(formatFetchError(e))
    }
    const text = await res.text()
    let data: Record<string, unknown>
    try {
      data = JSON.parse(text) as Record<string, unknown>
    } catch {
      data = { raw: text }
    }
    if (!res.ok) {
      const msg =
        (data.message as string) ||
        (data.error as string) ||
        res.statusText ||
        text
      throw new DeployApiError(msg, res.status)
    }
    return data as T
  }

  return {
    login: (username: string, password: string) =>
      api<BaseResp<{
        token: string
        admin_id: number
        username: string
        role: string
        expire_at: number
      }>>(adminApiPath('/login'), {
        method: 'POST',
        auth: false,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      }),

    me: () =>
      api<BaseResp<{ admin_id: number; username: string; role: string }>>(
        adminApiPath('/me'),
      ),

    dashboard: () =>
      api<
        BaseResp<{
          landing_feedback_total: number
          user_total: number
          server_time: string
          feishu_enabled: boolean
        }>
      >(adminApiPath('/dashboard')),

    listUsers: (params: {
      page?: number
      page_size?: number
      keyword?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.keyword) q.set('keyword', params.keyword)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            username: string
            email: string
            moe_no?: string
            role?: string
            is_vip: boolean
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/users')}${qs ? `?${qs}` : ''}`)
    },

    getUser: (userId: string | number) =>
      api<
        BaseResp<{
          id: string
          username: string
          email: string
          moe_no?: string
          role?: string
          is_vip: boolean
          signature?: string
          created_at: string
        }>
      >(adminApiPath(`/users/${userId}`)),

    updateUser: (
      userId: string | number,
      body: {
        role?: string
        is_vip?: boolean
        update_is_vip?: boolean
        signature?: string
        update_signature?: boolean
      },
    ) =>
      api<BaseResp<Record<string, unknown>>>(adminApiPath(`/users/${userId}`), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    listLandingFeedback: (params: {
      page?: number
      page_size?: number
      category?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.category) q.set('category', params.category)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: number
            email: string
            category: string
            content: string
            source: string
            client_ip?: string
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/landing/feedback')}${qs ? `?${qs}` : ''}`)
    },
  }
}

export type AdminClient = ReturnType<typeof createAdminClient>
