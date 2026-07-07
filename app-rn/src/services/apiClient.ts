import { AppConfig } from '../config/appConfig';

export type ApiErrorKind =
  | 'unauthorized'
  | 'timeout'
  | 'network'
  | 'server'
  | 'client'
  | 'parse'
  | 'unknown';

export class ApiError extends Error {
  status?: number;

  body?: unknown;

  kind: ApiErrorKind;

  constructor(message: string, options: { status?: number; body?: unknown; kind?: ApiErrorKind } = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = options.status;
    this.body = options.body;
    this.kind = options.kind ?? 'unknown';
  }
}

type RequestMethod = 'GET' | 'POST' | 'PUT' | 'DELETE';

type QueryValue = string | number | boolean | null | undefined;

export type QueryParams = Record<string, QueryValue>;

export interface ApiClientOptions {
  getToken?: () => string | null;
  onUnauthorized?: () => void;
  timeoutMs?: number;
  retryCount?: number;
  debug?: boolean;
}

interface RequestOptions {
  retryCount?: number;
  timeoutMs?: number;
}

function wait(ms: number) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

export class ApiClient {
  private readonly getToken?: () => string | null;

  private readonly onUnauthorized?: () => void;

  private readonly timeoutMs: number;

  private readonly retryCount: number;

  private readonly debug: boolean;

  constructor(options: ApiClientOptions = {}) {
    this.getToken = options.getToken;
    this.onUnauthorized = options.onUnauthorized;
    this.timeoutMs = options.timeoutMs ?? 12000;
    this.retryCount = options.retryCount ?? 1;
    this.debug = options.debug ?? false;
  }

  async get<T>(path: string, options?: RequestOptions) {
    return this.request<T>(path, 'GET', undefined, undefined, options);
  }

  async getWithQuery<T>(path: string, query?: QueryParams, options?: RequestOptions) {
    return this.request<T>(path, 'GET', undefined, query, options);
  }

  async post<T>(path: string, body?: unknown, options?: RequestOptions) {
    return this.request<T>(path, 'POST', body, undefined, options);
  }

  async put<T>(path: string, body?: unknown, options?: RequestOptions) {
    return this.request<T>(path, 'PUT', body, undefined, options);
  }

  async delete<T>(path: string, query?: QueryParams, options?: RequestOptions) {
    return this.request<T>(path, 'DELETE', undefined, query, options);
  }

  private async request<T>(
    path: string,
    method: RequestMethod,
    body?: unknown,
    query?: QueryParams,
    options?: RequestOptions,
  ): Promise<T> {
    const retries = options?.retryCount ?? this.retryCount;
    let attempt = 0;

    while (true) {
      try {
        return await this.executeRequest<T>(path, method, body, query, options?.timeoutMs);
      } catch (error) {
        const apiError = this.normalizeError(error);
        const canRetry = attempt < retries && this.shouldRetry(apiError, method);
        if (!canRetry) {
          throw apiError;
        }

        attempt += 1;
        await wait(400 * attempt);
      }
    }
  }

  private async executeRequest<T>(
    path: string,
    method: RequestMethod,
    body?: unknown,
    query?: QueryParams,
    timeoutMs?: number,
  ): Promise<T> {
    const url = this.buildUrl(path, query);
    const token = this.getToken?.();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs ?? this.timeoutMs);

    try {
      this.log(`${method} ${url}`);
      const response = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: body == null ? undefined : JSON.stringify(body),
        signal: controller.signal,
      });

      const text = await response.text();
      const data = text ? this.safeJson(text) : null;

      if (response.status === 401) {
        this.onUnauthorized?.();
        throw new ApiError(this.pickMessage(data) ?? '登录状态已失效，请重新登录', {
          status: response.status,
          body: data,
          kind: 'unauthorized',
        });
      }

      if (!response.ok) {
        throw new ApiError(
          this.pickMessage(data) ?? `Request failed: ${response.status}`,
          {
            status: response.status,
            body: data,
            kind: response.status >= 500 ? 'server' : 'client',
          },
        );
      }

      return data as T;
    } catch (error) {
      throw this.normalizeError(error);
    } finally {
      clearTimeout(timer);
    }
  }

  private buildUrl(path: string, query?: QueryParams) {
    const url = new URL(path, AppConfig.apiUrl);

    if (query) {
      Object.entries(query).forEach(([key, value]) => {
        if (value == null || value === '') {
          return;
        }
        url.searchParams.set(key, String(value));
      });
    }

    return url.toString();
  }

  private safeJson(text: string) {
    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  }

  private pickMessage(data: unknown) {
    if (typeof data === 'string') {
      return data;
    }
    if (data && typeof data === 'object') {
      if ('message' in data) {
        return String((data as { message?: unknown }).message ?? '');
      }
      if ('error' in data) {
        return String((data as { error?: unknown }).error ?? '');
      }
    }
    return null;
  }

  private shouldRetry(error: ApiError, method: RequestMethod) {
    if (error.kind === 'unauthorized' || error.kind === 'client') {
      return false;
    }
    if (method !== 'GET' && method !== 'DELETE') {
      return error.kind === 'timeout' || error.kind === 'network';
    }
    return error.kind === 'timeout' || error.kind === 'network' || error.kind === 'server';
  }

  private normalizeError(error: unknown) {
    if (error instanceof ApiError) {
      return error;
    }

    if (error instanceof Error) {
      if (error.name === 'AbortError') {
        return new ApiError('请求超时，请稍后重试', { kind: 'timeout' });
      }

      if (
        error.message.includes('Network request failed') ||
        error.message.includes('Failed to fetch') ||
        error.message.includes('Load failed')
      ) {
        return new ApiError('网络连接失败，请检查当前网络或服务地址', { kind: 'network' });
      }

      return new ApiError(error.message, { kind: 'unknown' });
    }

    return new ApiError('请求失败，请稍后重试', { kind: 'unknown' });
  }

  private log(message: string) {
    if (!this.debug) {
      return;
    }
    console.log(`[api:${AppConfig.environment}] ${message}`);
  }
}

