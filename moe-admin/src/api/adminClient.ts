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
  cloudApiBaseUrl?: string
}

function resolveAdminRequestUrl(path: string, opts: AdminClientOptions): string {
  if (path.startsWith('http')) return path
  const base = opts.baseUrl.replace(/\/$/, '')
  if (useDirectAdminApi()) {
    if (opts.apiTarget === 'cloud' && opts.cloudApiBaseUrl) {
      const cloudBase = opts.cloudApiBaseUrl.replace(/\/$/, '')
      const adminPath = path.replace(/^\/api\/deploy\/admin/, '/api/admin')
      return `${cloudBase}${adminPath}`
    }
    return `${base}${path}`
  }
  const url = new URL(`${base}${path}`)
  if (opts.apiTarget && path.includes('/api/deploy/')) {
    url.searchParams.set('target', opts.apiTarget)
  }
  return url.toString()
}

type BaseResp<T> = {
  success: boolean
  code?: number
  message?: string
  data?: T
}

export type AdminUserBehaviorScreenStat = {
  screen: string
  label: string
  visit_count: number
  total_duration_ms: number
}

export type AdminUserBehaviorSummary = {
  tags?: string[]
  last_active_at?: string
  total_events_7d?: number
  top_screens?: AdminUserBehaviorScreenStat[]
}

export type AdminUserProfileData = {
  user: {
    id: string
    username: string
    email: string
    moe_no?: string
    avatar?: string
    signature?: string
    role?: string
    is_vip: boolean
    created_at: string
  }
  counts: {
    posts: number
    comments: number
    following: number
    followers: number
    check_ins: number
    achievements_unlocked: number
    vip_orders: number
    gift_sent: number
    gift_received: number
    gift_stocks: number
    transactions: number
    ai_agents: number
    groups_joined: number
  }
  level?: {
    level: number
    experience: number
    total_exp: number
    level_title?: string
  }
  links: Array<{
    label: string
    admin_route: string
    hint?: string
  }>
  behavior?: AdminUserBehaviorSummary
}

export function createAdminClient(opts: AdminClientOptions) {
  async function api<T>(
    path: string,
    init?: RequestInit & { auth?: boolean },
  ): Promise<T> {
    const headers = new Headers(init?.headers)
    const useAuth = init?.auth !== false
    if (useAuth && opts.token) {
      headers.set('X-Admin-Token', opts.token)
    }
    const full = resolveAdminRequestUrl(path, opts)
    let res: Response
    try {
      res = await fetch(full, { ...init, headers })
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
            avatar?: string
            signature?: string
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
        avatar?: string
        update_avatar?: boolean
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

    listAchievements: (params: {
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
            description: string
            category: string
            rarity: string
            enabled: boolean
            sort_order: number
          }>
          total: number
        }>
      >(`${adminApiPath('/growth/achievements')}${qs ? `?${qs}` : ''}`)
    },

    bootstrapAchievements: () =>
      api<BaseResp<{ created: number }>>(adminApiPath('/achievements/bootstrap'), {
        method: 'POST',
      }),

    bootstrapLevels: () =>
      api<
        BaseResp<{
          level_configs_created: number
          check_in_rewards_created: number
        }>
      >(adminApiPath('/growth/levels/bootstrap'), { method: 'POST' }),

    getGrowthStats: () =>
      api<
        BaseResp<{
          achievement_definitions: number
          unlocked_progress_records: number
          level_configs: number
          check_in_rewards: number
          user_levels: number
          check_ins_today: number
          total_check_ins: number
        }>
      >(adminApiPath('/growth/stats')),

    listLevelConfigs: () =>
      api<
        BaseResp<
          Array<{
            id: string
            level: number
            title: string
            min_exp: number
            max_exp: number
            privileges: string
            badge_url: string
          }>
        >
      >(adminApiPath('/growth/levels')),

    updateLevelConfig: (
      levelId: string | number,
      body: {
        title?: string
        min_exp?: number
        max_exp?: number
        privileges?: string
        badge_url?: string
        update_title?: boolean
        update_min_exp?: boolean
        update_max_exp?: boolean
        update_privileges?: boolean
        update_badge_url?: boolean
      },
    ) =>
      api<
        BaseResp<{
          id: string
          level: number
          title: string
          min_exp: number
          max_exp: number
          privileges: string
          badge_url: string
        }>
      >(adminApiPath(`/growth/levels/${levelId}`), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    listCheckInRewards: () =>
      api<
        BaseResp<
          Array<{
            id: string
            consecutive_days: number
            exp_reward: number
            extra_reward: string
          }>
        >
      >(adminApiPath('/growth/check-in-rewards')),

    updateCheckInReward: (
      rewardId: string | number,
      body: {
        consecutive_days?: number
        exp_reward?: number
        extra_reward?: string
        update_consecutive_days?: boolean
        update_exp_reward?: boolean
        update_extra_reward?: boolean
      },
    ) =>
      api<
        BaseResp<{
          id: string
          consecutive_days: number
          exp_reward: number
          extra_reward: string
        }>
      >(adminApiPath(`/growth/check-in-rewards/${rewardId}`), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    updateAchievement: (
      achievementId: string,
      body: {
        name?: string
        description?: string
        enabled?: boolean
        exp_reward?: number
        sort_order?: number
        update_name?: boolean
        update_description?: boolean
        update_enabled?: boolean
        update_exp_reward?: boolean
        update_sort_order?: boolean
      },
    ) =>
      api<
        BaseResp<{
          id: string
          name: string
          description: string
          category: string
          rarity: string
          enabled: boolean
          sort_order: number
          exp_reward: number
        }>
      >(adminApiPath(`/growth/achievements/${achievementId}`), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    getUserProfile: (userId: string | number) =>
      api<BaseResp<AdminUserProfileData>>(adminApiPath(`/users/${userId}/profile`)),

    listMediaImages: (params: {
      page?: number
      page_size?: number
      keyword?: string
      owner_folder?: string
      media_kind?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.owner_folder) q.set('owner_folder', params.owner_folder)
      if (params.media_kind) q.set('media_kind', params.media_kind)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            filename: string
            file_name: string
            owner_folder: string
            media_kind: string
            url: string
            size: number
            created_at: string
            owner_hint?: string
          }>
          total: number
          owners: Array<{
            owner_folder: string
            user_id?: string
            username_hint?: string
            file_count: number
            total_bytes: number
          }>
        }>
      >(`${adminApiPath('/media/images')}${qs ? `?${qs}` : ''}`)
    },

    deleteMediaImage: (filename: string) =>
      api<BaseResp<unknown>>(
        adminApiPath(`/media/images/${encodeURIComponent(filename)}`),
        { method: 'DELETE' },
      ),

    listAnnouncements: (params: {
      page?: number
      page_size?: number
      keyword?: string
      status?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.status) q.set('status', params.status)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            title: string
            content: string
            status: string
            published_at?: string
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/announcements')}${qs ? `?${qs}` : ''}`)
    },

    createAnnouncement: (body: { title: string; content: string }) =>
      api<BaseResp<{ id: string; title: string; content: string; status: string }>>(
        adminApiPath('/announcements'),
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        },
      ),

    updateAnnouncement: (
      id: string,
      body: { title?: string; content?: string },
    ) =>
      api<BaseResp<Record<string, unknown>>>(adminApiPath(`/announcements/${id}`), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    deleteAnnouncement: (id: string) =>
      api<BaseResp<unknown>>(adminApiPath(`/announcements/${id}`), { method: 'DELETE' }),

    publishAnnouncement: (id: string) =>
      api<BaseResp<Record<string, unknown>>>(
        adminApiPath(`/announcements/${id}/publish`),
        { method: 'POST' },
      ),

    broadcastNotification: (body: { title: string; content: string }) =>
      api<
        BaseResp<{ notifications_created: number; ws_sent: number }>
      >(adminApiPath('/notifications/broadcast'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    sendNotification: (body: { user_id: string; title: string; content: string }) =>
      api<
        BaseResp<{ notification_id: string; ws_sent: boolean }>
      >(adminApiPath('/notifications/send'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    listAiAgents: (params: {
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
            owner_user_id: string
            owner_name: string
            payload_json: string
          }>
          total: number
        }>
      >(`${adminApiPath('/ai/agents')}${qs ? `?${qs}` : ''}`)
    },

    deleteAiAgent: (body: { user_id: string; agent_id: string }) =>
      api<BaseResp<unknown>>(adminApiPath('/ai/agents'), {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    listFollows: (params: {
      page?: number
      page_size?: number
      keyword?: string
      user_id?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.user_id) q.set('user_id', params.user_id)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            follower_id: string
            follower_name: string
            following_id: string
            following_name: string
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/social/follows')}${qs ? `?${qs}` : ''}`)
    },

    listFriendRequests: (params: {
      page?: number
      page_size?: number
      keyword?: string
      status?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.status) q.set('status', params.status)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            from_user_id: string
            from_user_name: string
            to_user_id: string
            to_user_name: string
            status: string
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/social/friend-requests')}${qs ? `?${qs}` : ''}`)
    },

    deleteFollow: (followId: string) =>
      api<BaseResp<unknown>>(adminApiPath(`/social/follows/${followId}`), {
        method: 'DELETE',
      }),

    listAccounts: (params: {
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
            role: string
            last_login_at?: string
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/accounts')}${qs ? `?${qs}` : ''}`)
    },

    createAccount: (body: { username: string; password: string; role?: string }) =>
      api<BaseResp<{ id: string; username: string; role: string }>>(
        adminApiPath('/accounts'),
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        },
      ),

    updateAccount: (
      id: string,
      body: { username?: string; password?: string; role?: string },
    ) =>
      api<BaseResp<Record<string, unknown>>>(adminApiPath(`/accounts/${id}`), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    deleteAccount: (id: string) =>
      api<BaseResp<unknown>>(adminApiPath(`/accounts/${id}`), { method: 'DELETE' }),

    listMenus: () =>
      api<
        BaseResp<
          Array<{
            id: string
            key: string
            kind: string
            parent_key: string
            path: string
            label: string
            icon: string
            caption: string
            status: string
            sort_order: number
            enabled: boolean
          }>
        >
      >(adminApiPath('/menus')),

    upsertMenu: (body: Record<string, unknown>) =>
      api<BaseResp<Record<string, unknown>>>(adminApiPath('/menus'), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    deleteMenu: (menuKey: string) =>
      api<BaseResp<unknown>>(adminApiPath(`/menus/${encodeURIComponent(menuKey)}`), {
        method: 'DELETE',
      }),

    bootstrapMenus: () =>
      api<BaseResp<{ created: number }>>(adminApiPath('/menus/bootstrap'), {
        method: 'POST',
      }),

    listAuditLogs: (params: {
      page?: number
      page_size?: number
      action?: string
      resource?: string
      admin_id?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.action) q.set('action', params.action)
      if (params.resource) q.set('resource', params.resource)
      if (params.admin_id) q.set('admin_id', params.admin_id)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            admin_id: string
            admin_name: string
            action: string
            resource: string
            resource_id: string
            detail: string
            ip: string
            created_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/audit-logs')}${qs ? `?${qs}` : ''}`)
    },

    getSchemaCatalog: () =>
      api<
        BaseResp<{
          summary: {
            total_tables: number
            managed_full: number
            managed_partial: number
            unmanaged: number
            total_rows: number
          }
          items: Array<{
            key: string
            table_name: string
            label: string
            domain: string
            coverage: string
            capabilities: string[]
            admin_route?: string
            bootstrap_key?: string
            row_count: number
            note?: string
          }>
        }>
      >(adminApiPath('/schema/catalog')),

    getRuntimeConfig: () =>
      api<
        BaseResp<{
          public_api_base_url: string
          api_public_base_url: string
          image_public_base_url: string
          image_local_dir: string
          image_max_bytes: number
          config_file: string
          requires_restart: boolean
        }>
      >(adminApiPath('/runtime-config')),

    updateRuntimeConfig: (body: {
      public_api_base_url?: string
      update_public_api_base_url?: boolean
      api_public_base_url?: string
      update_api_public_base_url?: boolean
      image_public_base_url?: string
      update_image_public_base_url?: boolean
      image_local_dir?: string
      update_image_local_dir?: boolean
      image_max_bytes?: number
      update_image_max_bytes?: boolean
    }) =>
      api<
        BaseResp<{
          public_api_base_url: string
          api_public_base_url: string
          image_public_base_url: string
          image_local_dir: string
          image_max_bytes: number
          config_file: string
          requires_restart: boolean
        }>
      >(adminApiPath('/runtime-config'), {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      }),

    listMemories: (params: {
      page?: number
      page_size?: number
      user_id?: string
      keyword?: string
      memory_type?: string
    } = {}) => {
      const q = new URLSearchParams()
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.user_id) q.set('user_id', params.user_id)
      if (params.keyword) q.set('keyword', params.keyword)
      if (params.memory_type) q.set('memory_type', params.memory_type)
      const qs = q.toString()
      return api<
        BaseResp<{
          items: Array<{
            id: string
            user_id: string
            username?: string
            key: string
            value: string
            memory_type: string
            confidence: number
            source: string
            updated_at: string
          }>
          total: number
        }>
      >(`${adminApiPath('/memories')}${qs ? `?${qs}` : ''}`)
    },

    getMemoryStats: () =>
      api<
        BaseResp<{
          total_memories: number
          users_with_memories: number
          total_feedbacks: number
          total_embeddings: number
          by_type: Array<{ memory_type: string; count: number }>
        }>
      >(adminApiPath('/memories/stats')),

    deleteMemory: (memoryId: string | number) =>
      api<BaseResp<unknown>>(adminApiPath(`/memories/${memoryId}`), { method: 'DELETE' }),
  }
}

export type AdminClient = ReturnType<typeof createAdminClient>
