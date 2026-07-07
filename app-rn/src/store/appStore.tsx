import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';

import { ApiClient } from '../services/apiClient';
import { LifeWsClient, type LifeWsStatus } from '../services/lifeWsClient';
import {
  clearSession,
  loadSession,
  saveLastLoginAccount,
  saveSession,
} from '../services/tokenStorage';
import type { AiAgentCard, AiProviderProfile } from '../types/ai';
import type { AuthSession } from '../types/auth';
import type { ChatConversation, ChatMessage } from '../types/chat';
import type { FeedPost } from '../types/feed';
import type { LifeWorldSnapshot } from '../types/life';
import type { UserProfile } from '../types/profile';

type RootTab = 'home' | 'chat' | 'ai' | 'profile';

interface AppStoreValue {
  bootstrapped: boolean;
  bootMessage: string;
  activeTab: RootTab;
  session: AuthSession | null;
  apiClient: ApiClient;
  feedPosts: FeedPost[];
  conversations: ChatConversation[];
  selectedPeerId: string | null;
  messagesByPeer: Record<string, ChatMessage[]>;
  aiAgents: AiAgentCard[];
  myAiAgents: AiAgentCard[];
  aiProviders: AiProviderProfile[];
  profile: UserProfile | null;
  wsStatus: LifeWsStatus;
  worldSnapshot: LifeWorldSnapshot | null;
  setActiveTab: (tab: RootTab) => void;
  setFeedPosts: (posts: FeedPost[]) => void;
  setConversations: (items: ChatConversation[]) => void;
  setSelectedPeerId: (peerId: string | null) => void;
  setMessagesForPeer: (peerId: string, messages: ChatMessage[]) => void;
  appendMessageForPeer: (peerId: string, message: ChatMessage) => void;
  setAiAgents: (items: AiAgentCard[]) => void;
  setMyAiAgents: (items: AiAgentCard[]) => void;
  setAiProviders: (items: AiProviderProfile[]) => void;
  setProfile: (profile: UserProfile | null) => void;
  loginDemo: () => Promise<void>;
  completeSession: (session: AuthSession, account?: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AppStoreContext = createContext<AppStoreValue | null>(null);

const demoSession: AuthSession = {
  token: 'demo-token',
  userId: '10001',
  nickname: 'Moe Explorer',
};

export function AppStoreProvider({ children }: { children: React.ReactNode }) {
  const [bootstrapped, setBootstrapped] = useState(false);
  const [bootMessage, setBootMessage] = useState('正在恢复会话...');
  const [activeTab, setActiveTab] = useState<RootTab>('home');
  const [session, setSession] = useState<AuthSession | null>(null);
  const [feedPosts, setFeedPosts] = useState<FeedPost[]>([]);
  const [conversations, setConversations] = useState<ChatConversation[]>([]);
  const [selectedPeerId, setSelectedPeerId] = useState<string | null>(null);
  const [messagesByPeer, setMessagesByPeer] = useState<Record<string, ChatMessage[]>>({});
  const [aiAgents, setAiAgents] = useState<AiAgentCard[]>([]);
  const [myAiAgents, setMyAiAgents] = useState<AiAgentCard[]>([]);
  const [aiProviders, setAiProviders] = useState<AiProviderProfile[]>([]);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [wsStatus, setWsStatus] = useState<LifeWsStatus>('idle');
  const [worldSnapshot, setWorldSnapshot] = useState<LifeWorldSnapshot | null>(null);

  useEffect(() => {
    let mounted = true;
    setBootMessage('正在恢复会话...');
    loadSession()
      .then((nextSession) => {
        if (mounted) {
          setSession(nextSession);
          setBootMessage(nextSession ? '正在恢复用户状态...' : '正在准备登录入口...');
          setBootstrapped(true);
        }
      })
      .catch(() => {
        if (mounted) {
          setBootMessage('本地会话读取失败，已切换到登录入口');
          setBootstrapped(true);
        }
      });

    return () => {
      mounted = false;
    };
  }, []);

  const logout = async () => {
    await clearSession();
    setSession(null);
    setFeedPosts([]);
    setConversations([]);
    setSelectedPeerId(null);
    setMessagesByPeer({});
    setAiAgents([]);
    setMyAiAgents([]);
    setAiProviders([]);
    setProfile(null);
    setWsStatus('idle');
    setWorldSnapshot(null);
    setActiveTab('home');
  };

  const completeSession = async (nextSession: AuthSession, account?: string) => {
    await saveSession(nextSession);
    if (account?.trim()) {
      await saveLastLoginAccount(account);
    }
    setSession(nextSession);
  };

  const apiClient = useMemo(
    () =>
      new ApiClient({
        getToken: () => session?.token ?? null,
        onUnauthorized: () => {
          void logout();
        },
      }),
    [session],
  );

  useEffect(() => {
    if (!session?.token) {
      return;
    }

    const client = new LifeWsClient({
      getToken: () => session.token,
      onStatusChange: (status) => {
        setWsStatus(status);
      },
      onSnapshot: (snapshot) => {
        setWorldSnapshot(snapshot);
      },
    });

    client.connect();
    return () => {
      client.disconnect();
    };
  }, [session?.token]);

  const setMessagesForPeer = (peerId: string, messages: ChatMessage[]) => {
    setMessagesByPeer((current) => ({
      ...current,
      [peerId]: messages,
    }));
  };

  const appendMessageForPeer = (peerId: string, message: ChatMessage) => {
    setMessagesByPeer((current) => ({
      ...current,
      [peerId]: [...(current[peerId] ?? []), message],
    }));
  };

  const loginDemo = async () => {
    await saveSession(demoSession);
    setSession(demoSession);
  };

  const value = useMemo<AppStoreValue>(
    () => ({
      bootstrapped,
      bootMessage,
      activeTab,
      session,
      apiClient,
      feedPosts,
      conversations,
      selectedPeerId,
      messagesByPeer,
      aiAgents,
      myAiAgents,
      aiProviders,
      profile,
      wsStatus,
      worldSnapshot,
      setActiveTab,
      setFeedPosts,
      setConversations,
      setSelectedPeerId,
      setMessagesForPeer,
      appendMessageForPeer,
      setAiAgents,
      setMyAiAgents,
      setAiProviders,
      setProfile,
      loginDemo,
      completeSession,
      logout,
    }),
    [
      activeTab,
      aiAgents,
      aiProviders,
      apiClient,
      bootstrapped,
      bootMessage,
      conversations,
      feedPosts,
      messagesByPeer,
      myAiAgents,
      profile,
      selectedPeerId,
      session,
      worldSnapshot,
      wsStatus,
    ],
  );

  return <AppStoreContext.Provider value={value}>{children}</AppStoreContext.Provider>;
}

export function useAppStore() {
  const context = useContext(AppStoreContext);
  if (!context) {
    throw new Error('useAppStore must be used inside AppStoreProvider');
  }
  return context;
}
