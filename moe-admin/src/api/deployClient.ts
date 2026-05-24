import type { DeployJob, HostInfo, RemoteCheck } from '../types/deploy'

export class DeployApiError extends Error {
  status?: number

  constructor(message: string, status?: number) {
    super(message)
    this.name = 'DeployApiError'
    this.status = status
  }
}

export type DeployClientOptions = {
  baseUrl: string
  token: string
}

export function createDeployClient(opts: DeployClientOptions) {
  const base = opts.baseUrl.replace(/\/$/, '')

  async function api<T>(path: string, init?: RequestInit): Promise<T> {
    const headers = new Headers(init?.headers)
    if (opts.token) headers.set('X-Deploy-Token', opts.token)
    const res = await fetch(base + path, { ...init, headers })
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
    probeAgent: () =>
      api<{ success?: boolean; running?: boolean; pid?: number }>(
        '/api/deploy/agent',
      ).catch(() => null),

    session: () =>
      api<{ success: boolean; message?: string }>('/api/deploy/session'),

    info: () =>
      api<{
        success: boolean
        paths?: Record<string, string>
        cloud_deploy?: Record<string, string>
      }>('/api/deploy/info'),

    targets: () =>
      api<{
        success: boolean
        targets: Array<{
          id?: string
          kind?: string
          label?: string
          host?: string
          user?: string
          backend_dir?: string
          api_base_url?: string
        }>
        default_target?: string
      }>('/api/deploy/targets'),

    host: (target: string, signal?: AbortSignal) =>
      api<{
        success: boolean
        host: HostInfo
        target?: Record<string, string>
        resolved_paths?: Record<string, string>
        remote_check?: RemoteCheck
      }>(`/api/deploy/host?target=${encodeURIComponent(target)}`, { signal }),

    status: (target: string) =>
      api<{ success: boolean; output?: string; message?: string }>(
        `/api/deploy/status?target=${encodeURIComponent(target)}`,
      ),

    sshCheck: (target = 'cloud') =>
      api<{ success: boolean; probe?: { message?: string; output?: string } }>(
        `/api/deploy/ssh-check?target=${encodeURIComponent(target)}`,
      ),

    remoteCheck: (target = 'cloud') =>
      api<{ success: boolean; check: RemoteCheck }>(
        `/api/deploy/remote-check?target=${encodeURIComponent(target)}`,
      ),

    remoteConfigGet: (target: string, file: string) =>
      api<{ success: boolean; content: string; path?: string }>(
        `/api/deploy/remote-config?target=${encodeURIComponent(target)}&file=${encodeURIComponent(file)}`,
      ),

    remoteConfigPut: (
      target: string,
      file: string,
      content: string,
    ) =>
      api<{ success: boolean; path?: string; backup_path?: string }>(
        '/api/deploy/remote-config',
        {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ target, file, content }),
        },
      ),

    releases: () =>
      api<{ success: boolean; tags?: string; github_latest?: unknown }>(
        '/api/deploy/releases',
      ),

    listJobs: () =>
      api<{ success: boolean; jobs: DeployJob[] }>('/api/deploy/jobs'),

    getJob: (id: string) =>
      api<{ success: boolean; job: DeployJob }>(`/api/deploy/jobs/${id}`),

    createJob: (type: string, target: string, params: Record<string, string> = {}) =>
      api<{ success: boolean; job_id: string; message?: string }>(
        '/api/deploy/jobs',
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ type, target, params }),
        },
      ),

    shutdownAgent: () =>
      api<{ success: boolean; message?: string }>('/api/deploy/shutdown', {
        method: 'POST',
      }),

    getBuildCache: () =>
      api<{ success: boolean; cache: BuildCacheStatusDto }>(
        '/api/deploy/build-cache',
      ),

    platformHealth: () =>
      api<{
        success: boolean
        agent?: { online: boolean; listen: string }
        local_api: {
          target: string
          base_url: string
          online: boolean
          message?: string
        }
        cloud_api: {
          target: string
          base_url: string
          online: boolean
          message?: string
        }
        default_target?: string
      }>('/api/deploy/platform/health'),

    adminDashboard: (target: string) =>
      api<{
        success: boolean
        message?: string
        data?: {
          landing_feedback_total: number
          user_total: number
          server_time: string
          feishu_enabled: boolean
        }
      }>(`/api/deploy/admin/dashboard?target=${encodeURIComponent(target)}`),

    listLandingFeedback: (
      target: string,
      params: { page?: number; page_size?: number; category?: string } = {},
    ) => {
      const q = new URLSearchParams()
      q.set('target', target)
      if (params.page) q.set('page', String(params.page))
      if (params.page_size) q.set('page_size', String(params.page_size))
      if (params.category) q.set('category', params.category)
      return api<{
        success: boolean
        code?: number
        message?: string
        data?: {
          items: Array<{
            id: number
            email: string
            category: string
            content: string
            source: string
            client_ip?: string
            user_agent?: string
            created_at: string
          }>
          total: number
        }
      }>(`/api/deploy/ops/landing-feedback?${q.toString()}`)
    },

    cleanBuildCache: (removeBinaries = false) =>
      api<{
        success: boolean
        message?: string
        freed_bytes?: number
        cache: BuildCacheStatusDto
      }>('/api/deploy/build-cache', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ remove_binaries: removeBinaries }),
      }),
  }
}

export type BuildCacheStatusDto = {
  root: string
  go_cache_dir: string
  tmp_dir: string
  cache_bytes: number
  binary_bytes: number
  total_reclaimable_bytes: number
  linux_binaries?: Array<{
    path: string
    exists: boolean
    size_bytes: number
  }>
}

export type DeployClient = ReturnType<typeof createDeployClient>
