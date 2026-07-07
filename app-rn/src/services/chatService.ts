import type { ApiEnvelope } from '../types/api';
import type { ChatConversation, ChatMessage } from '../types/chat';

import { ApiClient } from './apiClient';

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {};
}

function asString(value: unknown) {
  return typeof value === 'string' ? value : '';
}

function asNumber(value: unknown) {
  return typeof value === 'number' ? value : 0;
}

function asStringArray(value: unknown) {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : [];
}

function mapMessage(value: unknown): ChatMessage {
  const item = asRecord(value);
  return {
    id: asString(item.id),
    senderId: asString(item.sender_id),
    receiverId: asString(item.receiver_id),
    body: asString(item.body),
    imagePaths: asStringArray(item.image_paths),
    createdAt: asString(item.created_at),
    senderMoeNo: asString(item.sender_moe_no),
    receiverMoeNo: asString(item.receiver_moe_no),
  };
}

function mapConversation(value: unknown): ChatConversation {
  const item = asRecord(value);
  return {
    peerId: asString(item.peer_id),
    peerName: asString(item.peer_name),
    peerAvatar: asString(item.peer_avatar),
    peerMoeNo: asString(item.peer_moe_no),
    peerDisplayUserId: asString(item.peer_display_user_id),
    unreadCount: asNumber(item.unread_count),
    lastMessage: item.last_message ? mapMessage(item.last_message) : undefined,
  };
}

export async function getPrivateConversations(
  client: ApiClient,
  viewerId: string,
): Promise<ChatConversation[]> {
  const response = await client.getWithQuery<ApiEnvelope>('/api/private-messages/conversations', {
    viewer_id: viewerId,
    limit: 50,
    offset: 0,
  });
  const root = asRecord(response);
  const data = asRecord(root.data);
  const list = Array.isArray(data.conversations)
    ? data.conversations
    : Array.isArray(root.conversations)
      ? root.conversations
      : [];
  return list.map(mapConversation);
}

export async function getPrivateMessages(
  client: ApiClient,
  viewerId: string,
  peerId: string,
): Promise<ChatMessage[]> {
  const response = await client.getWithQuery<ApiEnvelope>('/api/private-messages', {
    viewer_id: viewerId,
    peer_id: peerId,
    limit: 50,
  });
  const root = asRecord(response);
  const data = asRecord(root.data);
  const list = Array.isArray(data.messages) ? data.messages : Array.isArray(root.messages) ? root.messages : [];
  return list.map(mapMessage);
}

export async function sendPrivateMessage(
  client: ApiClient,
  senderId: string,
  receiverId: string,
  body: string,
): Promise<ChatMessage> {
  const response = await client.post<ApiEnvelope>('/api/private-messages', {
    sender_id: senderId,
    receiver_id: receiverId,
    body,
    image_paths: [],
  });
  const root = asRecord(response);
  const data = asRecord(root.data);
  return mapMessage(data.message ?? root.message);
}
