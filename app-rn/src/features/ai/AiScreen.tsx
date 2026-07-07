import React, { useEffect, useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { ActionButton } from '../../components/ActionButton';
import { MetricCard } from '../../components/MetricCard';
import { Panel } from '../../components/Panel';
import { Screen } from '../../components/Screen';
import { StatusNotice } from '../../components/StatusNotice';
import {
  getAiProviders,
  getMyAiAgents,
  getPublicAiAgents,
  sendAiChatTurn,
} from '../../services/aiService';
import { useAppStore } from '../../store/appStore';
import { colors, radii, spacing } from '../../theme/tokens';
import type { AiAgentCard, AiChatTurn } from '../../types/ai';

export function AiScreen() {
  const {
    apiClient,
    session,
    aiAgents,
    myAiAgents,
    aiProviders,
    setAiAgents,
    setMyAiAgents,
    setAiProviders,
  } = useAppStore();
  const [selectedAgent, setSelectedAgent] = useState<AiAgentCard | null>(null);
  const [history, setHistory] = useState<AiChatTurn[]>([]);
  const [draft, setDraft] = useState('');
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!session?.userId) {
      return;
    }

    setLoading(true);
    setError('');
    Promise.all([
      getPublicAiAgents(apiClient),
      getMyAiAgents(apiClient, session.userId),
      getAiProviders(apiClient, session.userId),
    ])
      .then(([publicAgents, mine, providers]) => {
        setAiAgents(publicAgents);
        setMyAiAgents(mine);
        setAiProviders(providers);
        if (!selectedAgent) {
          const seed = mine[0] ?? publicAgents[0] ?? null;
          setSelectedAgent(seed);
          if (seed?.greeting) {
            setHistory([{ role: 'assistant', content: seed.greeting }]);
          }
        }
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : '加载 AI 资源失败');
      })
      .finally(() => {
        setLoading(false);
      });
  }, [apiClient, selectedAgent, session?.userId, setAiAgents, setAiProviders, setMyAiAgents]);

  const allAgents = useMemo(() => {
    const merged = [...myAiAgents, ...aiAgents];
    const seen = new Set<string>();
    return merged.filter((item) => {
      if (seen.has(item.id)) {
        return false;
      }
      seen.add(item.id);
      return true;
    });
  }, [aiAgents, myAiAgents]);

  const providerLabel = selectedAgent?.modelName || aiProviders[0]?.model || '未绑定模型';
  const providerCountLabel = aiProviders.length > 0 ? `${aiProviders.length} 已接入` : '待接入';
  const roleTag = selectedAgent?.tags[0] || '角色';

  const handleSend = async () => {
    if (!session?.userId || !selectedAgent || !draft.trim()) {
      return;
    }

    const nextHistory: AiChatTurn[] = [...history, { role: 'user', content: draft.trim() }];
    setHistory(nextHistory);
    setDraft('');
    setSending(true);
    setError('');
    try {
      const reply = await sendAiChatTurn(apiClient, session.userId, selectedAgent, nextHistory);
      setHistory((current) => [...current, { role: 'assistant', content: reply }]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'AI 对话失败');
    } finally {
      setSending(false);
    }
  };

  return (
    <Screen
      title="AI 互动"
      subtitle="继续把角色酒馆、Provider 上下文和聊天区层级做完整，让陪伴感和探索感都更清晰。"
      eyebrow="AI Tavern"
    >
      <Panel style={styles.heroPanel}>
        <View style={styles.heroTop}>
          <View style={styles.heroBadge}>
            <Text style={styles.heroBadgeText}>AI</Text>
          </View>
          <View style={styles.heroBody}>
            <Text style={styles.heroTitle}>角色酒馆</Text>
            <Text style={styles.heroCopy}>
              当前先把角色切换、首轮氛围和基础对话体验做顺，后续可以继续补流式输出、世界书和更强的设定展开。
            </Text>
          </View>
        </View>
        <View style={styles.metrics}>
          <MetricCard label="我的角色" value={myAiAgents.length} tone="primary" />
          <MetricCard label="公开角色" value={aiAgents.length} tone="accent" />
          <MetricCard label="Provider" value={providerCountLabel} tone="soft" />
        </View>
      </Panel>

      <Panel title="角色列表" subtle>
        {loading ? <StatusNotice title="正在同步角色资源" message="角色卡、Provider 和默认开场白正在加载中。" /> : null}
        {!loading && allAgents.length === 0 ? (
          <StatusNotice
            title="当前还没有可用角色"
            message="等迁移继续推进后，这里可以接回更完整的角色创建、收藏和筛选入口。"
          />
        ) : null}
        <View style={styles.agentGrid}>
          {allAgents.map((agent) => (
            <Pressable
              key={agent.id}
              onPress={() => {
                setSelectedAgent(agent);
                setHistory(agent.greeting ? [{ role: 'assistant', content: agent.greeting }] : []);
              }}
              style={({ pressed }) => [
                styles.agentCard,
                selectedAgent?.id === agent.id ? styles.agentCardActive : null,
                pressed ? styles.agentCardPressed : null,
              ]}
            >
              <View style={styles.agentCardTop}>
                <Text style={styles.agentPill}>{agent.tags[0] || '角色'}</Text>
                <View style={styles.agentSignal} />
              </View>
              <Text style={styles.agentName}>{agent.name}</Text>
              <Text style={styles.agentDesc} numberOfLines={3}>
                {agent.description || agent.greeting || '这个角色还没有补充介绍。'}
              </Text>
              <Text style={styles.agentMeta}>{agent.modelName || '未绑定模型'}</Text>
            </Pressable>
          ))}
        </View>
      </Panel>

      <Panel title={selectedAgent ? `和 ${selectedAgent.name} 聊聊` : 'AI 对话区'}>
        <View style={styles.chatHeader}>
          <View style={styles.chatHeaderMeta}>
            <Text style={styles.chatHeaderTitle}>{selectedAgent?.name || '先选择一个角色'}</Text>
            <Text style={styles.chatHeaderCopy}>
              {selectedAgent
                ? `当前模型：${providerLabel}。先把基础对话体验打顺，再继续补设定、参数和更细的角色差异感。`
                : '角色选中后，这里会进入更完整的酒馆聊天区和首轮引导区。'}
            </Text>
          </View>
          {selectedAgent ? (
            <View style={styles.statusChip}>
              <Text style={styles.statusChipText}>可对话</Text>
            </View>
          ) : null}
        </View>

        {selectedAgent ? (
          <View style={styles.contextRibbon}>
            <View style={styles.contextPill}>
              <Text style={styles.contextPillText}>{roleTag}</Text>
            </View>
            <View style={styles.contextBlock}>
              <Text style={styles.contextLabel}>模型</Text>
              <Text style={styles.contextValue}>{providerLabel}</Text>
            </View>
            <View style={styles.contextBlock}>
              <Text style={styles.contextLabel}>Provider</Text>
              <Text style={styles.contextValue}>{providerCountLabel}</Text>
            </View>
          </View>
        ) : null}

        {error ? <StatusNotice title="AI 提示" message={error} tone="error" /> : null}

        {!selectedAgent ? (
          <StatusNotice title="先挑一个角色" message="角色卡已经可切换，选中之后就能继续完善聊天氛围和输出体验。" />
        ) : null}

        <View style={styles.chatHistory}>
          {history.length === 0 && selectedAgent ? (
            <View style={styles.emptyState}>
              <Text style={styles.emptyEyebrow}>New Session</Text>
              <Text style={styles.emptyTitle}>准备开始一段新的对话</Text>
              <Text style={styles.emptyCopy}>你可以先发一句问候，让角色从这里开始回应你，也更方便继续调细节奏和氛围。</Text>
            </View>
          ) : null}
          {history.map((item, index) => (
            <View
              key={`${item.role}-${index}`}
              style={[styles.chatRow, item.role === 'user' ? styles.chatRowMine : null]}
            >
              {item.role === 'assistant' ? <View style={styles.chatHalo} /> : null}
              <View style={[styles.chatBubble, item.role === 'user' ? styles.chatMine : styles.chatAssistant]}>
                <Text style={styles.chatRole}>{item.role === 'user' ? '我' : selectedAgent?.name || 'AI'}</Text>
                <Text style={styles.chatText}>{item.content}</Text>
              </View>
            </View>
          ))}
        </View>

        <View style={styles.composer}>
          <View style={styles.composerHintRow}>
            <Text style={styles.composerHint}>
              {selectedAgent ? '可以试着提问设定、情绪或陪伴场景，观察角色回应是否足够自然。' : '先选择角色后再开始对话。'}
            </Text>
            <Text style={styles.composerMeta}>{draft.trim().length}/400</Text>
          </View>
          <TextInput
            value={draft}
            onChangeText={(value) => setDraft(value.slice(0, 400))}
            placeholder="和角色说点什么..."
            placeholderTextColor={colors.textMuted}
            style={styles.input}
            editable={Boolean(selectedAgent) && !sending}
            multiline
          />
          <ActionButton
            label={sending ? '思考中...' : '发送对话'}
            onPress={() => void handleSend()}
            compact
            disabled={!selectedAgent || !draft.trim() || sending}
          />
        </View>
      </Panel>
    </Screen>
  );
}

const styles = StyleSheet.create({
  heroPanel: {
    backgroundColor: 'rgba(127,127,213,0.94)',
  },
  heroTop: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  heroBadge: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: 'rgba(255,255,255,0.24)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroBadgeText: {
    color: colors.white,
    fontSize: 22,
    fontWeight: '900',
  },
  heroBody: {
    flex: 1,
    gap: spacing.xxs,
  },
  heroTitle: {
    color: colors.white,
    fontSize: 22,
    fontWeight: '900',
  },
  heroCopy: {
    color: 'rgba(255,255,255,0.82)',
    fontSize: 13,
    lineHeight: 20,
  },
  metrics: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  agentGrid: {
    gap: spacing.sm,
  },
  agentCard: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: colors.line,
    backgroundColor: colors.white,
    padding: spacing.md,
    gap: 8,
  },
  agentCardActive: {
    borderColor: colors.primaryDeep,
    backgroundColor: colors.primarySoft,
  },
  agentCardPressed: {
    transform: [{ scale: 0.985 }, { translateY: 1 }],
    opacity: 0.94,
  },
  agentCardTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  agentPill: {
    alignSelf: 'flex-start',
    borderRadius: radii.pill,
    backgroundColor: colors.accentSoft,
    color: colors.primaryDeep,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xxs,
    fontSize: 11,
    fontWeight: '800',
  },
  agentSignal: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: colors.secondary,
  },
  agentName: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '800',
  },
  agentDesc: {
    color: colors.textMuted,
    lineHeight: 20,
  },
  agentMeta: {
    color: colors.primaryDeep,
    fontSize: 12,
    fontWeight: '700',
  },
  chatHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: spacing.sm,
  },
  chatHeaderMeta: {
    flex: 1,
    gap: 4,
  },
  chatHeaderTitle: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '800',
  },
  chatHeaderCopy: {
    color: colors.textMuted,
    fontSize: 12,
    lineHeight: 18,
  },
  statusChip: {
    borderRadius: radii.pill,
    backgroundColor: colors.panelSoft,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  statusChipText: {
    color: colors.primaryDeep,
    fontSize: 11,
    fontWeight: '800',
  },
  contextRibbon: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: radii.lg,
    backgroundColor: colors.panelSoft,
    borderWidth: 1,
    borderColor: colors.line,
  },
  contextPill: {
    borderRadius: radii.pill,
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    justifyContent: 'center',
  },
  contextPillText: {
    color: colors.white,
    fontSize: 11,
    fontWeight: '800',
    textTransform: 'uppercase',
  },
  contextBlock: {
    flex: 1,
    minWidth: 110,
    gap: 4,
    justifyContent: 'center',
  },
  contextLabel: {
    color: colors.textSoft,
    fontSize: 11,
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  contextValue: {
    color: colors.text,
    fontSize: 13,
    fontWeight: '800',
  },
  chatHistory: {
    gap: spacing.sm,
    borderRadius: radii.lg,
    backgroundColor: 'rgba(248,245,255,0.72)',
    borderWidth: 1,
    borderColor: colors.line,
    padding: spacing.md,
  },
  emptyState: {
    borderRadius: radii.lg,
    backgroundColor: colors.panelSoft,
    padding: spacing.md,
    gap: 6,
    borderWidth: 1,
    borderColor: colors.line,
  },
  emptyEyebrow: {
    color: colors.primaryDeep,
    fontSize: 11,
    fontWeight: '800',
    textTransform: 'uppercase',
  },
  emptyTitle: {
    color: colors.text,
    fontWeight: '800',
    fontSize: 16,
  },
  emptyCopy: {
    color: colors.textMuted,
    fontSize: 13,
    lineHeight: 19,
  },
  chatRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: spacing.xs,
  },
  chatRowMine: {
    justifyContent: 'flex-end',
  },
  chatHalo: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: colors.secondarySoft,
    marginBottom: 10,
  },
  chatBubble: {
    borderRadius: radii.lg,
    padding: spacing.sm,
    gap: 6,
    maxWidth: '88%',
    borderWidth: 1,
    borderColor: 'rgba(110, 106, 164, 0.10)',
  },
  chatMine: {
    backgroundColor: colors.primarySoft,
  },
  chatAssistant: {
    backgroundColor: colors.white,
  },
  chatRole: {
    color: colors.primaryDeep,
    fontSize: 12,
    fontWeight: '700',
  },
  chatText: {
    color: colors.text,
    lineHeight: 20,
  },
  composer: {
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: radii.lg,
    backgroundColor: colors.panelSoft,
    borderWidth: 1,
    borderColor: colors.line,
  },
  composerHintRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: spacing.sm,
  },
  composerHint: {
    color: colors.textMuted,
    fontSize: 12,
    lineHeight: 18,
    flex: 1,
  },
  composerMeta: {
    color: colors.textSoft,
    fontSize: 11,
    fontWeight: '700',
  },
  input: {
    minHeight: 96,
    borderRadius: radii.lg,
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    color: colors.text,
    textAlignVertical: 'top',
  },
});
