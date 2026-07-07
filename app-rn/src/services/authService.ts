import { ApiClient, ApiError } from './apiClient';
import type { AuthSession } from '../types/auth';
import type { ApiEnvelope } from '../types/api';

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function messageOf(error: unknown) {
  if (error instanceof ApiError) {
    return error.message;
  }
  if (error instanceof Error) {
    return error.message;
  }
  return '请求失败，请稍后重试';
}

function parseSession(payload: unknown): AuthSession {
  const root = isRecord(payload) ? payload : {};
  const data = isRecord(root.data) ? root.data : root;
  const user = isRecord(data.user) ? data.user : isRecord(root.user) ? root.user : {};
  const token =
    (typeof data.token === 'string' && data.token) ||
    (typeof root.token === 'string' && root.token) ||
    '';

  if (!token) {
    throw new Error('登录响应缺少 token');
  }

  return {
    token,
    userId: typeof user.id === 'string' ? user.id : typeof user.id === 'number' ? String(user.id) : undefined,
    nickname:
      typeof user.username === 'string'
        ? user.username
        : typeof user.nickname === 'string'
          ? user.nickname
          : undefined,
  };
}

function pickAuthorizeUrl(payload: unknown) {
  const root = isRecord(payload) ? payload : {};
  const data = isRecord(root.data) ? root.data : root;
  const url =
    (typeof data.authorize_url === 'string' && data.authorize_url) ||
    (typeof root.authorize_url === 'string' && root.authorize_url) ||
    '';

  if (!url) {
    throw new Error('授权地址获取失败');
  }

  return url;
}

export async function loginWithPassword(
  client: ApiClient,
  account: string,
  password: string,
) {
  const normalized = account.trim();
  const body: Record<string, string> = { password };
  if (normalized.includes('@')) {
    body.email = normalized.toLowerCase();
  } else {
    body.username = normalized;
  }

  const response = await client.post<ApiEnvelope>('/api/user/login', body);
  return parseSession(response);
}

export async function registerWithPassword(
  client: ApiClient,
  username: string,
  email: string,
  password: string,
) {
  const response = await client.post<ApiEnvelope>('/api/user/register', {
    username: username.trim(),
    email: email.trim().toLowerCase(),
    password,
  });

  const session = parseSession(response);
  const root = isRecord(response) ? response : {};
  const data = isRecord(root.data) ? root.data : root;
  const user = isRecord(data.user) ? data.user : isRecord(root.user) ? root.user : {};
  const moeNo = typeof user.moe_no === 'string' ? user.moe_no : '';

  return { session, moeNo };
}

export async function checkEmailExists(client: ApiClient, email: string) {
  return client.post<ApiEnvelope>('/api/user/check-email', {
    email: email.trim().toLowerCase(),
  });
}

export async function sendResetCode(client: ApiClient, email: string) {
  return client.post<ApiEnvelope>('/api/user/send-reset-code', {
    email: email.trim().toLowerCase(),
  });
}

export async function verifyResetCode(
  client: ApiClient,
  email: string,
  code: string,
) {
  return client.post<ApiEnvelope>('/api/user/verify-reset-code', {
    email: email.trim().toLowerCase(),
    code: code.trim(),
  });
}

export async function resetPassword(
  client: ApiClient,
  email: string,
  code: string,
  newPassword: string,
) {
  return client.post<ApiEnvelope>('/api/user/reset-password', {
    email: email.trim().toLowerCase(),
    code: code.trim(),
    new_password: newPassword,
  });
}

export async function getWechatAuthorizeUrl(client: ApiClient, flow = 'website') {
  const response = await client.getWithQuery<ApiEnvelope>('/api/auth/wechat/authorize-url', {
    flow,
    state: 'app-rn-auth',
  });
  return pickAuthorizeUrl(response);
}

export async function getFeishuAuthorizeUrl(client: ApiClient) {
  const response = await client.getWithQuery<ApiEnvelope>('/api/auth/feishu/authorize-url', {
    state: 'app-rn-auth',
  });
  return pickAuthorizeUrl(response);
}

export { messageOf };
