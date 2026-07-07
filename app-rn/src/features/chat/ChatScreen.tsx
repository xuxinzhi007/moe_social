import React, { useEffect, useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { ActionButton } from '../../components/ActionButton';
import { Panel } from '../../components/Panel';
import { Screen } from '../../components/Screen';
import { StatusNotice } from '../../components/StatusNotice';
import {
  getPrivateConversations,
  getPrivateMessages,
  sendPrivateMessage,
} from '../../services/chatService';
import { useAppStore } from '../../store/appStore';
import { colors, radii, spacing } from '../../theme/tokens';

export function ChatScreen() {
  const {
    apiClient,
    session,
    conversations,
    selectedPeerId,
    messagesByPeer,
    setConversations,
    setSelectedPeerId,
    setMessagesForPeer,
    appendMessageForPeer,
  } = useAppStore();
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
    void getPrivateConversations(apiClient, session.userId)
      .then((items) => {
        setConversations(items);
        if (!selectedPeerId && items[0]?.peerId) {
          setSelectedPeerId(items[0].peerId);
        }
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : '加载会话失败');
      })
      .finally(() => {
        setLoading(false);
      });
  }, [apiClient, selectedPeerId, session?.userId, setConversations, setSelectedPeerId]);

  useEffect(() => {
    if (!session?.userId || !selectedPeerId) {
      return;
    }
    if (messagesByPeer[selectedPeerId]?.length) {
      return;
    }

    void getPrivateMessages(apiClient, session.userId, selectedPeerId)
      .then((items) => {
        setMessagesForPeer(selectedPeerId, items.reverse());
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : '加载消息失败');
      });
  }, [apiClient, messagesByPeer, selectedPeerId, session?.userId, setMessagesForPeer]);

  const currentConversation = useMemo(
    () => conversations.find((item) => item.peerId === selectedPeerId) ?? null,
    [conversations, selectedPeerId],
  );
  const messages = selectedPeerId ? messagesByPeer[selectedPeerId] ?? [] : [];
  const unreadTotal = conversations.reduce((sum, item) => sum + item.unreadCount, 0);
  const peerLabel =
    currentConversation?.peerName || currentConversation?.peerDisplayUserId || currentConversation?.peerMoeNo || '新朋友';

  const handleSend = async () => {
    if (!session?.userId || !selectedPeerId || !draft.trim()) {
      return;
    }

    setSending(true);
    setError('');
    try {
      const message = await sendPrivateMessage(apiClient, session.userId, selectedPeerId, draft.trim());
      appendMessageForPeer(selectedPeerId, message);
      setDraft('');
    } catch (err) {
      setError(err instanceof Error ? err.message : '发送失败');
    } finally {
      setSending(false);
    }
  };

  return (
    <Screen
      title="聊天"
      subtitle="继续把会话切换、消息阅读和输入反馈拉齐，让 RN 私信页更像真实社交产品的聊天空间。"
      eyebrow="Direct Chat"
    >
      <Panel style={styles.heroPanel}>
        <View style={styles.heroTop}>
          <View style={styles.heroBadge}>
            <Text style={styles.heroBadgeText}>DM</Text>
          </View>
          <View style={styles.heroBody}>
            <Text style={styles.heroTitle}>最近会话</Text>
            <Text style={styles.heroCopy}>
              这一版先把私信区的节奏做顺，后续可以在这套骨架上继续补图片、在线状态和更完整的沉浸式过渡。
            </Text>
          </View>
        </View>
        <View style={styles.heroStats}>
          <View style={styles.heroStat}>
            <Text style={styles.heroStatLabel}>会话数</Text>
            <Text style={styles.heroStatValue}>{conversations.length}</Text>
          </View>
          <View style={styles.heroStat}>
            <Text style={styles.heroStatLabel}>未读</Text>
            <Text style={styles.heroStatValue}>{unreadTotal}</Text>
          </View>
          <View style={styles.heroStat}>
            <Text style={styles.heroStatLabel}>状态</Text>
            <Text style={styles.heroStatValue}>{loading ? '同步中' : '可聊天'}</Text>
          </View>
        </View>
      </Panel>

      <Panel title="会话列表" subtle>
        <View style={styles.list}>
          {loading ? (
            <StatusNotice title="正在同步会话" message="最近联系的人和未读状态正在加载中。" />
          ) : null}
          {!loading && conversations.length === 0 ? (
            <StatusNotice title="还没有私信" message="可以先从首页或个人页建立关系，聊天页会在这里逐步变得更完整。" />
          ) : null}
          {conversations.map((item) => (
            <Pressable
              key={item.peerId}
              onPress={() => setSelectedPeerId(item.peerId)}
              style={({ pressed }) => [
                styles.conversation,
                item.peerId === selectedPeerId ? styles.conversationActive : null,
                pressed ? styles.conversationPressed : null,
              ]}
            >
              <View style={[styles.avatar, item.peerId === selectedPeerId ? styles.avatarActive : null]}>
                <Text style={styles.avatarText}>
                  {(item.peerName || item.peerDisplayUserId || '?').slice(0, 1).toUpperCase()}
                </Text>
              </View>
              <View style={styles.conversationBody}>
                <View style={styles.conversationHead}>
                  <Text style={styles.name}>{item.peerName || item.peerDisplayUserId || '未知用户'}</Text>
                  <Text style={styles.metaMini}>{item.lastMessage?.createdAt || '刚刚'}</Text>
                </View>
                <Text style={styles.preview} numberOfLines={1}>
                  {item.lastMessage?.body || '点进来和对方打个招呼吧。'}
                </Text>
              </View>
              {item.unreadCount > 0 ? (
                <View style={styles.badge}>
                  <Text style={styles.badgeText}>{item.unreadCount}</Text>
                </View>
              ) : (
                <View style={styles.trailingDot} />
              )}
            </Pressable>
          ))}
        </View>
      </Panel>

      <Panel title={currentConversation ? `与 ${peerLabel} 的对话` : '消息区'}>
        <View style={styles.chatHeader}>
          <View style={styles.chatHeaderMeta}>
            <Text style={styles.chatHeaderTitle}>{currentConversation ? peerLabel : '先选择一个会话开始聊天'}</Text>
            <Text style={styles.chatHeaderCopy}>
              {currentConversation
                ? '当前先打通基础消息流，后续会继续补在线状态、图片消息和更舒服的阅读节奏。'
                : '会话选中后，这里会进入更沉浸的阅读区和发送区。'}
            </Text>
          </View>
          {currentConversation ? (
            <View style={styles.onlineChip}>
              <Text style={styles.onlineChipText}>聊天入口已接通</Text>
            </View>
          ) : null}
        </View>

        {error ? <StatusNotice title="聊天提示" message={error} tone="error" /> : null}

        <View style={styles.chatStage}>
          {!selectedPeerId ? (
            <StatusNotice title="先选一个会话" message="左侧会话列表已经可用，点开后就能继续完善聊天体验。" />
          ) : null}
          {selectedPeerId && messages.length === 0 ? (
            <View style={styles.emptyState}>
              <Text style={styles.emptyEyebrow}>Fresh Thread</Text>
              <Text style={styles.emptyTitle}>这里还没有消息</Text>
              <Text style={styles.emptyCopy}>发一条试试，把这段对话真正点亮起来，也方便继续补齐后续互动细节。</Text>
            </View>
          ) : null}
          {messages.map((message) => {
            const mine = message.senderId === session?.userId;
            return (
              <View key={message.id} style={[styles.messageRow, mine ? styles.messageRowMine : null]}>
                {!mine ? <View style={styles.messageHalo} /> : null}
                <View style={[styles.bubble, mine ? styles.bubbleMine : styles.bubblePeer]}>
                  <Text style={styles.bubbleRole}>{mine ? '我' : peerLabel.slice(0, 8)}</Text>
                  <Text style={styles.bubbleText}>{message.body}</Text>
                  <Text style={styles.bubbleMeta}>{message.createdAt || '刚刚'}</Text>
                </View>
              </View>
            );
          })}
        </View>

        <View style={styles.composer}>
          <View style={styles.composerHintRow}>
            <Text style={styles.composerHint}>
              {selectedPeerId ? '输入一条轻松的问候，继续把发送和阅读节奏打磨顺。' : '先选择会话后再输入消息。'}
            </Text>
            <Text style={styles.composerMeta}>{draft.trim().length}/300</Text>
          </View>
          <TextInput
            value={draft}
            onChangeText={(value) => setDraft(value.slice(0, 300))}
            placeholder="输入消息..."
            placeholderTextColor={colors.textMuted}
            style={styles.input}
            editable={Boolean(selectedPeerId) && !sending}
            multiline
          />
          <ActionButton
            label={sending ? '发送中...' : '发送消息'}
            onPress={() => void handleSend()}
            compact
            disabled={!selectedPeerId || !draft.trim() || sending}
          />
        </View>
      </Panel>
    </Screen>
  );
}

const styles = StyleSheet.create({
  heroPanel: {
    backgroundColor: 'rgba(134,168,231,0.94)',
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
    backgroundColor: 'rgba(255,255,255,0.26)',
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
  heroStats: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  heroStat: {
    flex: 1,
    borderRadius: radii.lg,
    padding: spacing.sm,
    backgroundColor: 'rgba(255,255,255,0.18)',
    gap: 4,
  },
  heroStatLabel: {
    color: 'rgba(255,255,255,0.72)',
    fontSize: 11,
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  heroStatValue: {
    color: colors.white,
    fontSize: 14,
    fontWeight: '800',
  },
  list: {
    gap: spacing.sm,
  },
  conversation: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.sm,
    borderRadius: radii.lg,
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
  },
  conversationActive: {
    borderColor: colors.primaryDeep,
    backgroundColor: colors.primarySoft,
  },
  conversationPressed: {
    transform: [{ scale: 0.985 }, { translateY: 1 }],
    opacity: 0.94,
  },
  avatar: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: colors.panelSoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarActive: {
    backgroundColor: colors.white,
  },
  avatarText: {
    color: colors.text,
    fontWeight: '800',
  },
  conversationBody: {
    flex: 1,
    gap: 4,
  },
  conversationHead: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: spacing.sm,
  },
  name: {
    color: colors.text,
    fontWeight: '800',
    flex: 1,
  },
  metaMini: {
    color: colors.textSoft,
    fontSize: 11,
    fontWeight: '700',
  },
  preview: {
    color: colors.textMuted,
    fontSize: 13,
  },
  badge: {
    minWidth: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: colors.primaryDeep,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 6,
  },
  badgeText: {
    color: colors.white,
    fontSize: 12,
    fontWeight: '700',
  },
  trailingDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.bgStrong,
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
  onlineChip: {
    borderRadius: radii.pill,
    backgroundColor: colors.panelSoft,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  onlineChipText: {
    color: colors.primaryDeep,
    fontSize: 11,
    fontWeight: '800',
  },
  chatStage: {
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
  messageRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: spacing.xs,
  },
  messageRowMine: {
    justifyContent: 'flex-end',
  },
  messageHalo: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: colors.accentSoft,
    marginBottom: 10,
  },
  bubble: {
    borderRadius: radii.lg,
    padding: spacing.sm,
    gap: 6,
    maxWidth: '88%',
    borderWidth: 1,
    borderColor: 'rgba(110, 106, 164, 0.10)',
  },
  bubbleMine: {
    alignSelf: 'flex-end',
    backgroundColor: colors.primarySoft,
    borderTopRightRadius: 8,
  },
  bubblePeer: {
    alignSelf: 'flex-start',
    backgroundColor: colors.white,
    borderTopLeftRadius: 8,
  },
  bubbleRole: {
    color: colors.primaryDeep,
    fontSize: 11,
    fontWeight: '800',
  },
  bubbleText: {
    color: colors.text,
    lineHeight: 20,
  },
  bubbleMeta: {
    color: colors.textMuted,
    fontSize: 11,
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
    minHeight: 88,
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
