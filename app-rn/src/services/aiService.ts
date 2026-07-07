import type { ApiEnvelope } from '../types/api';
import type {
  AiAgentCard,
  AiChatTurn,
  AiProviderProfile,
  AiResourceItem,
} from '../types/ai';

import { ApiClient } from './apiClient';

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {};
}

function asString(value: unknown) {
  return typeof value === 'string' ? value : '';
}

function parseJsonObject(value: unknown) {
  if (typeof value !== 'string' || !value.trim()) {
    return {};
  }
  try {
    const parsed = JSON.parse(value) as unknown;
    return asRecord(parsed);
  } catch {
    return {};
  }
}

function mapResource(value: unknown): AiResourceItem {
  const item = asRecord(value);
  return {
    id: asString(item.id),
    payloadJson: asString(item.payload_json),
  };
}

function mapAgent(value: AiResourceItem): AiAgentCard {
  const payload = parseJsonObject(value.payloadJson);
  const tags = Array.isArray(payload.tags)
    ? payload.tags.filter((item): item is string => typeof item === 'string')
    : [];

  return {
    id: value.id,
    name: asString(payload.name) || asString(payload.title) || '未命名角色',
    description: asString(payload.description) || asString(payload.summary),
    avatar: asString(payload.avatar) || asString(payload.avatar_url),
    greeting: asString(payload.greeting) || asString(payload.opening),
    modelName: asString(payload.model_name) || asString(payload.model),
    tags,
    raw: payload,
  };
}

function mapProvider(value: AiResourceItem): AiProviderProfile {
  const payload = parseJsonObject(value.payloadJson);
  return {
    id: value.id,
    name: asString(payload.name) || '未命名 Provider',
    baseUrl: asString(payload.base_url),
    model: asString(payload.model),
    providerType: asString(payload.provider_type) || asString(payload.type),
    raw: payload,
  };
}

function unwrapItems(response: ApiEnvelope) {
  const root = asRecord(response);
  const data = asRecord(root.data);
  const list = Array.isArray(data.items) ? data.items : Array.isArray(root.items) ? root.items : [];
  return list.map(mapResource);
}

export async function getPublicAiAgents(client: ApiClient): Promise<AiAgentCard[]> {
  const response = await client.getWithQuery<ApiEnvelope>('/api/ai/agents/public', {
    limit: 24,
  });
  return unwrapItems(response).map(mapAgent);
}

export async function getMyAiAgents(
  client: ApiClient,
  userId: string,
): Promise<AiAgentCard[]> {
  const response = await client.getWithQuery<ApiEnvelope>('/api/ai/agents', {
    user_id: userId,
  });
  return unwrapItems(response).map(mapAgent);
}

export async function getAiProviders(
  client: ApiClient,
  userId: string,
): Promise<AiProviderProfile[]> {
  const response = await client.getWithQuery<ApiEnvelope>('/api/ai/providers', {
    user_id: userId,
  });
  return unwrapItems(response).map(mapProvider);
}

export async function sendAiChatTurn(
  client: ApiClient,
  userId: string,
  agent: AiAgentCard,
  history: AiChatTurn[],
): Promise<string> {
  const response = await client.post<Record<string, unknown>>('/api/llm/chat', {
    user_id: userId,
    messages: history.map((item) => ({
      role: item.role,
      content: item.content,
    })),
    agent_id: agent.id,
    agent_name: agent.name,
    model_name: agent.modelName,
    meta: agent.raw,
  });

  const root = asRecord(response);
  const data = asRecord(root.data);
  const content =
    asString(root.reply) ||
    asString(root.content) ||
    asString(data.reply) ||
    asString(data.content) ||
    asString(data.text);

  return content || '当前模型没有返回内容，请稍后重试。';
}
