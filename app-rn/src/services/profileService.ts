import type { ApiEnvelope } from '../types/api';
import type { UserProfile } from '../types/profile';

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

function asBoolean(value: unknown) {
  return typeof value === 'boolean' ? value : false;
}

function mapUser(value: unknown): UserProfile {
  const item = asRecord(value);
  return {
    id: asString(item.id),
    username: asString(item.username),
    email: asString(item.email),
    avatar: asString(item.avatar),
    signature: asString(item.signature),
    gender: asString(item.gender),
    birthday: asString(item.birthday),
    isVip: asBoolean(item.is_vip),
    vipExpiresAt: asString(item.vip_expires_at),
    balance: asNumber(item.balance),
    moeNo: asString(item.moe_no),
    displayUserId: asString(item.display_user_id),
    giftCharm: asNumber(item.gift_charm),
    receivedGiftValue: asNumber(item.received_gift_value),
  };
}

export async function getUserProfile(
  client: ApiClient,
  userId: string,
): Promise<UserProfile> {
  const response = await client.get<ApiEnvelope>(`/api/user/${userId}`);
  const root = asRecord(response);
  const data = asRecord(root.data);
  return mapUser(data.user ?? root.user);
}

export async function updateUserProfile(
  client: ApiClient,
  profile: Pick<UserProfile, 'id' | 'username' | 'signature' | 'gender' | 'birthday' | 'avatar' | 'email'>,
) {
  const response = await client.put<ApiEnvelope>(`/api/user/${profile.id}`, {
    user_id: profile.id,
    username: profile.username,
    email: profile.email,
    avatar: profile.avatar,
    signature: profile.signature,
    gender: profile.gender,
    birthday: profile.birthday,
  });
  const root = asRecord(response);
  const data = asRecord(root.data);
  return mapUser(data.user ?? root.user);
}
