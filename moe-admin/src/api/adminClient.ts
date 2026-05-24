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

    listVipPlans: (params: {
      page?: number
      page_size?: number
      keyword?: string
      include_deleted?: boolean
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.include_deleted) q.set('include_deleted', 'true')
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            name: string
            description: string
            price: number
            duration_days: number
            created_at: string
            updated_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/vip/plans')}${qs ? `?${qs}` : ''}`)
    },

    getVipPlan: (planId: string | number) =>
      api<
        BaseResp<{
          id: string
          name: string
          description: string
          price: number
          duration_days: number
          created_at: string
          updated_at: string
        }>
      >(adminApiPath(`/vip/plans/${planId}`)),

    createVipPlan: (body: {
      name: string
      description?: string
      price: number
      duration_days: number
    }) =>
      api<
        BaseResp<{
          id: string
          name: string
          description: string
          price: number
          duration_days: number
        }>
      >(adminApiPath('/vip/plans'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    updateVipPlan: (
      planId: string | number,
      body: {
        name?: string
        description?: string
        price?: number
        duration_days?: number
        update_name?: boolean
        update_description?: boolean
        update_price?: boolean
        update_duration_days?: boolean
      },
    ) =>
      api<BaseResp<Record<string, unknown>>>(adminApiPath(`/vip/plans/${planId}`), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    deleteVipPlan: (planId: string | number) =>
      api<BaseResp<unknown>>(adminApiPath(`/vip/plans/${planId}`), {
        method: 'DELETE',
      }),

    bootstrapVipPlans: () =>
      api<BaseResp<{ created: number }>>(adminApiPath('/vip/plans/bootstrap'), {
        method: 'POST',
      }),

    listGifts: (params: {
      page?: number
      page_size?: number
      keyword?: string
      category?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.category) q.set('category', params.category)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            name: string
            price: number
            icon: string
            description: string
            category: string
            sort_order: number
            created_at: string
            updated_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/gifts')}${qs ? `?${qs}` : ''}`)
    },

    createGift: (body: {
      name: string
      price: number
      icon?: string
      description?: string
      category?: string
      sort_order?: number
    }) =>
      api<BaseResp<Record<string, unknown>>>(adminApiPath('/gifts'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    updateGift: (
      giftId: string,
      body: Record<string, unknown>,
    ) =>
      api<BaseResp<Record<string, unknown>>>(adminApiPath(`/gifts/${giftId}`), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    deleteGift: (giftId: string) =>
      api<BaseResp<unknown>>(adminApiPath(`/gifts/${giftId}`), { method: 'DELETE' }),

    bootstrapGifts: () =>
      api<BaseResp<{ created: number }>>(adminApiPath('/gifts/bootstrap'), {
        method: 'POST',
      }),

    listVipOrders: (params: {
      page?: number
      page_size?: number
      user_id?: string
      keyword?: string
      status?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.user_id) q.set('user_id', params.user_id)
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.status) q.set('status', params.status)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            user_id: string
            plan_id: string
            plan_name: string
            amount: number
            status: string
            order_no: string
            created_at: string
            paid_at?: string
          }>
          total: number
        }>
      >(`${adminApiPath('/orders/vip')}${qs ? `?${qs}` : ''}`)
    },

    listGiftPurchaseOrders: (params: {
      page?: number
      page_size?: number
      user_id?: string
      keyword?: string
      status?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.user_id) q.set('user_id', params.user_id)
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.status) q.set('status', params.status)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            user_id: string
            order_no: string
            gift_id: string
            gift_name: string
            quantity: number
            total_amount: number
            status: string
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/orders/gift-purchase')}${qs ? `?${qs}` : ''}`)
    },

    listPosts: (params: {
      page?: number
      page_size?: number
      keyword?: string
      moderation_status?: string
      include_deleted?: boolean
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.moderation_status) q.set('moderation_status', params.moderation_status)
      if (params.include_deleted) q.set('include_deleted', 'true')
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            user_id: string
            user_name: string
            content: string
            moderation_status?: string
            likes: number
            comments: number
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/posts')}${qs ? `?${qs}` : ''}`)
    },

    deletePost: (postId: string) =>
      api<BaseResp<unknown>>(adminApiPath(`/posts/${postId}`), { method: 'DELETE' }),

    listComments: (params: {
      page?: number
      page_size?: number
      keyword?: string
      post_id?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.post_id) q.set('post_id', params.post_id)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            post_id: string
            user_id: string
            user_name: string
            content: string
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/comments')}${qs ? `?${qs}` : ''}`)
    },

    deleteComment: (commentId: string) =>
      api<BaseResp<unknown>>(adminApiPath(`/comments/${commentId}`), {
        method: 'DELETE',
      }),

    listPostReports: (params: { page?: number; page_size?: number } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            post_id: string
            reporter_user_id: string
            reason: string
            created_at: string
            post_content_preview: string
          }>
          total: number
        }>
      >(`${adminApiPath('/post-reports')}${qs ? `?${qs}` : ''}`)
    },

    listGroups: (params: {
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
            name: string
            description: string
            creator_name: string
            member_count: number
            status: string
            is_public: boolean
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/community/groups')}${qs ? `?${qs}` : ''}`)
    },

    deleteGroup: (groupId: string) =>
      api<BaseResp<unknown>>(adminApiPath(`/community/groups/${groupId}`), {
        method: 'DELETE',
      }),
  }
}

export type AdminClient = ReturnType<typeof createAdminClient>
