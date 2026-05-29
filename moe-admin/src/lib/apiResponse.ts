const ENVELOPE_KEYS = new Set(['code', 'message', 'success', 'reason'])

/** 与 Flutter `api_response.dart` 对齐：兼容嵌套 data 与 proto/compat 压平信封。 */
export function isApiSuccess(json: Record<string, unknown>): boolean {
  if (json.success === false) return false
  const code = json.code
  if (typeof code === 'number' && code !== 0 && code !== 200) return false
  return true
}

/** 去掉 code/message/success/reason，得到业务字段。 */
export function apiPayload(json: Record<string, unknown>): Record<string, unknown> {
  const nested = json.data
  if (nested && typeof nested === 'object' && !Array.isArray(nested)) {
    return { ...(nested as Record<string, unknown>) }
  }

  const out: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(json)) {
    if (!ENVELOPE_KEYS.has(key) && key !== 'data') {
      out[key] = value
    }
  }
  return out
}

/** protojson camelCase → 管理台习惯的 snake_case 别名（不覆盖已有键）。 */
export function withSnakeAliases(
  payload: Record<string, unknown>,
): Record<string, unknown> {
  const out = { ...payload }
  for (const [key, value] of Object.entries(payload)) {
    const snake = key.replace(/[A-Z]/g, (m) => `_${m.toLowerCase()}`)
    if (snake !== key && out[snake] === undefined) {
      out[snake] = value
    }
  }
  return out
}

export type NormalizedResp<T> = {
  success: boolean
  code?: number
  message?: string
  data?: T
}

export function normalizeAdminResponse<T>(
  raw: Record<string, unknown>,
): NormalizedResp<T> {
  const success = isApiSuccess(raw)
  const nested = raw.data

  if (nested !== undefined && (Array.isArray(nested) || typeof nested !== 'object')) {
    return {
      success,
      code: raw.code as number | undefined,
      message: raw.message as string | undefined,
      data: nested as T,
    }
  }

  if (nested !== undefined && typeof nested === 'object' && nested !== null) {
    return {
      success,
      code: raw.code as number | undefined,
      message: raw.message as string | undefined,
      data: withSnakeAliases(nested as Record<string, unknown>) as T,
    }
  }

  const payload = withSnakeAliases(apiPayload(raw))
  const hasPayload = Object.keys(payload).length > 0
  return {
    success,
    code: raw.code as number | undefined,
    message: raw.message as string | undefined,
    data: (hasPayload ? payload : undefined) as T | undefined,
  }
}

/** 列表接口：兼容 `data: T[]` 与 proto `data: { items: T[] }`。 */
export function unwrapListItems<T>(
  data: T[] | { items?: T[] } | null | undefined,
): T[] {
  if (Array.isArray(data)) return data
  if (data && typeof data === 'object' && Array.isArray(data.items)) {
    return data.items
  }
  return []
}
