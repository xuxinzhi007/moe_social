const LS_URL = 'moe_deploy_url'
const LS_TOKEN = 'moe_deploy_token'
const LS_TARGET = 'moe_deploy_target'

/** Deploy Agent 固定端口（与 docs/dev/ports.md 一致） */
export const AGENT_URL = 'http://127.0.0.1:19010'

const FALLBACK_URL = AGENT_URL

function isDevUiPort(port: string) {
  return port === '5173' || port === '4173'
}

/** API 基址：始终指向 Agent :19010，避免误填 Vite 端口 :5173 */
export function resolveBaseUrl(): string {
  if (typeof window === 'undefined') return FALLBACK_URL

  const stored = localStorage.getItem(LS_URL)?.replace(/\/$/, '')
  const { origin, port } = window.location

  if (stored) {
    // 旧配置误存了前端 dev 地址，自动纠正
    if (isDevUiPort(new URL(stored).port || '')) {
      return FALLBACK_URL
    }
    return stored
  }

  if (port === '19010') return origin
  return FALLBACK_URL
}

export function loadConn(): {
  baseUrl: string
  token: string
  deployTarget: string
} {
  return {
    baseUrl: resolveBaseUrl(),
    token: localStorage.getItem(LS_TOKEN) || '',
    deployTarget: localStorage.getItem(LS_TARGET) || 'cloud',
  }
}

export function saveConn(baseUrl: string, token: string, deployTarget: string) {
  let url = baseUrl.replace(/\/$/, '')
  try {
    if (isDevUiPort(new URL(url).port || '')) {
      url = FALLBACK_URL
    }
  } catch {
  }
  localStorage.setItem(LS_URL, url)
  localStorage.setItem(LS_TOKEN, token)
  localStorage.setItem(LS_TARGET, deployTarget)
}

export { FALLBACK_URL as DEFAULT_URL }
