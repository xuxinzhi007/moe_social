import AsyncStorage from '@react-native-async-storage/async-storage';

import type { AuthSession } from '../types/auth';

const SESSION_KEY = 'moe_social_rn_session';
const LAST_LOGIN_ACCOUNT_KEY = 'moe_social_rn_last_login_account';

export async function saveSession(session: AuthSession) {
  await AsyncStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

export async function loadSession(): Promise<AuthSession | null> {
  const raw = await AsyncStorage.getItem(SESSION_KEY);
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw) as AuthSession;
  } catch {
    return null;
  }
}

export async function clearSession() {
  await AsyncStorage.removeItem(SESSION_KEY);
}

export async function saveLastLoginAccount(account: string) {
  const next = account.trim();
  if (!next) {
    return;
  }
  await AsyncStorage.setItem(LAST_LOGIN_ACCOUNT_KEY, next);
}

export async function loadLastLoginAccount() {
  const value = await AsyncStorage.getItem(LAST_LOGIN_ACCOUNT_KEY);
  return value?.trim() || '';
}
