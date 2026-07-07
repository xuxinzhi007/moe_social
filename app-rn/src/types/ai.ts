export interface AiResourceItem {
  id: string;
  payloadJson: string;
}

export interface AiAgentCard {
  id: string;
  name: string;
  description: string;
  avatar: string;
  greeting: string;
  modelName: string;
  tags: string[];
  raw: Record<string, unknown>;
}

export interface AiProviderProfile {
  id: string;
  name: string;
  baseUrl?: string;
  model?: string;
  providerType?: string;
  raw: Record<string, unknown>;
}

export interface AiChatTurn {
  role: 'user' | 'assistant';
  content: string;
}
