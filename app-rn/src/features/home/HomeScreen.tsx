import React, { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { ActionButton } from '../../components/ActionButton';
import { MetricCard } from '../../components/MetricCard';
import { Panel } from '../../components/Panel';
import { Screen } from '../../components/Screen';
import { StatusNotice } from '../../components/StatusNotice';
import { getFeedPosts, likePost } from '../../services/feedService';
import { useAppStore } from '../../store/appStore';
import { colors, radii, spacing } from '../../theme/tokens';

const storySeeds = [
  { id: 's1', title: '推荐', tint: 'lilac' as const },
  { id: 's2', title: '关系', tint: 'blue' as const },
  { id: 's3', title: '手绘', tint: 'mint' as const },
  { id: 's4', title: '世界', tint: 'amber' as const },
];

const trendTags = ['数字生命', 'AI 酒馆', '手绘动态', '萌系社交'];

export function HomeScreen() {
  const { apiClient, session, feedPosts, setFeedPosts, setActiveTab } = useAppStore();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const loadPosts = async () => {
    setLoading(true);
    setError('');
    try {
      const result = await getFeedPosts(apiClient, session?.userId);
      setFeedPosts(result.posts);
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载首页失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadPosts();
  }, [apiClient, session?.userId]);

  const handleLike = async (postId: string) => {
    if (!session?.userId) {
      return;
    }

    try {
      const updated = await likePost(apiClient, postId, session.userId);
      setFeedPosts(feedPosts.map((item) => (item.id === postId ? updated : item)));
    } catch (err) {
      setError(err instanceof Error ? err.message : '点赞失败');
    }
  };

  return (
    <Screen
      title={`首页，你好 ${session?.nickname ?? 'Explorer'}`}
      subtitle="继续把推荐氛围、快捷入口和动态流节奏拉齐，让 RN 首页更接近正式产品的第一印象。"
      eyebrow="Moe Feed"
    >
      <Panel style={styles.heroPanel}>
        <View style={styles.heroTop}>
          <View style={styles.heroBadge}>
            <Text style={styles.heroBadgeText}>MS</Text>
          </View>
          <View style={styles.heroBody}>
            <Text style={styles.heroTitle}>发现更可爱的世界</Text>
            <Text style={styles.heroCopy}>
              首页先承担内容分发和关系触达，把动态、聊天和 AI 入口组织得更顺手，也给后续动画留出空间。
            </Text>
          </View>
        </View>
        <View style={styles.metricRow}>
          <MetricCard label="动态数量" value={feedPosts.length} tone="soft" />
          <MetricCard label="已接入口" value="3" tone="accent" />
        </View>
      </Panel>

      <Panel title="今日灵感" subtle>
        <View style={styles.storyRow}>
          {storySeeds.map((item) => (
            <Pressable
              key={item.id}
              style={({ pressed }) => [
                styles.storyCard,
                storyCardTone(item.tint),
                pressed ? styles.storyCardPressed : null,
              ]}
            >
              <View style={styles.storyOrb} />
              <Text style={styles.storyTitle}>{item.title}</Text>
            </Pressable>
          ))}
        </View>
        <View style={styles.trendWrap}>
          {trendTags.map((tag) => (
            <View key={tag} style={styles.trendChip}>
              <Text style={styles.trendText}>#{tag}</Text>
            </View>
          ))}
        </View>
      </Panel>

      <Panel title="快速入口" subtle>
        <View style={styles.quickGrid}>
          <Pressable
            onPress={() => setActiveTab('chat')}
            style={({ pressed }) => [
              styles.quickCard,
              styles.quickCardLilac,
              pressed ? styles.quickCardPressed : null,
            ]}
          >
            <Text style={styles.quickEyebrow}>新消息</Text>
            <Text style={styles.quickTitle}>去聊天</Text>
            <Text style={styles.quickSub}>查看私信会话、最近消息和活跃联系人。</Text>
          </Pressable>
          <Pressable
            onPress={() => setActiveTab('ai')}
            style={({ pressed }) => [
              styles.quickCard,
              styles.quickCardBlue,
              pressed ? styles.quickCardPressed : null,
            ]}
          >
            <Text style={styles.quickEyebrow}>陪伴模式</Text>
            <Text style={styles.quickTitle}>AI 互动</Text>
            <Text style={styles.quickSub}>进入 AI 酒馆，继续角色聊天和灵感互动。</Text>
          </Pressable>
        </View>
        <ActionButton label="查看我的主页" onPress={() => setActiveTab('profile')} secondary compact />
      </Panel>

      <Panel
        title="动态流"
        right={
          <Pressable onPress={() => void loadPosts()} disabled={loading}>
            {({ pressed }) => (
              <Text style={[styles.refresh, pressed && !loading ? styles.linkPressed : null]}>
                {loading ? '刷新中...' : '刷新'}
              </Text>
            )}
          </Pressable>
        }
      >
        {error ? <StatusNotice title="加载提示" message={error} tone="error" /> : null}
        {loading && feedPosts.length === 0 ? (
          <StatusNotice title="正在整理首页内容" message="动态、推荐和入口卡片正在同步中，请稍等一下。" />
        ) : null}
        {!loading && feedPosts.length === 0 ? (
          <StatusNotice
            title="还没有动态"
            message="接口已经接通，下一步可以继续补故事条、发布入口和更完整的推荐节奏。"
          />
        ) : null}
        <View style={styles.feed}>
          {feedPosts.map((post) => (
            <View key={post.id} style={styles.postCard}>
              <View style={styles.postHeader}>
                <View style={styles.avatar}>
                  <Text style={styles.avatarText}>{(post.userName || '?').slice(0, 1).toUpperCase()}</Text>
                </View>
                <View style={styles.headerBody}>
                  <Text style={styles.userName}>{post.userName || '匿名用户'}</Text>
                  <Text style={styles.postMeta}>
                    {post.createdAt || '刚刚'}
                    {post.authorIsBot ? ' · AI' : ''}
                  </Text>
                </View>
                <View style={styles.postTypeBadge}>
                  <Text style={styles.postTypeText}>{post.hasHandDraw ? '手绘' : '日常'}</Text>
                </View>
              </View>
              <Text style={styles.content}>{post.content || '这条动态暂时还没有正文。'}</Text>
              {post.topicTags.length > 0 ? (
                <View style={styles.tags}>
                  {post.topicTags.map((tag) => (
                    <View key={tag.id || tag.name} style={styles.tag}>
                      <Text style={styles.tagText}>#{tag.name}</Text>
                    </View>
                  ))}
                </View>
              ) : null}
              <View style={styles.actions}>
                <Pressable
                  onPress={() => void handleLike(post.id)}
                  style={({ pressed }) => [
                    styles.action,
                    post.isLiked ? styles.actionLiked : null,
                    pressed ? styles.actionPressed : null,
                  ]}
                >
                  <Text style={[styles.actionText, post.isLiked ? styles.actionTextLiked : null]}>
                    {post.isLiked ? '已赞' : '点赞'} {post.likes}
                  </Text>
                </Pressable>
                <View style={styles.action}>
                  <Text style={styles.actionText}>评论 {post.comments}</Text>
                </View>
                <View style={styles.action}>
                  <Text style={styles.actionText}>{post.authorIsBot ? 'AI 发布' : '用户发布'}</Text>
                </View>
              </View>
            </View>
          ))}
        </View>
      </Panel>
    </Screen>
  );
}

function storyCardTone(tint: 'lilac' | 'blue' | 'mint' | 'amber') {
  switch (tint) {
    case 'blue':
      return { backgroundColor: colors.accentSoft };
    case 'mint':
      return { backgroundColor: colors.secondarySoft };
    case 'amber':
      return { backgroundColor: colors.warnSoft };
    default:
      return { backgroundColor: colors.primarySoft };
  }
}

const styles = StyleSheet.create({
  heroPanel: {
    backgroundColor: 'rgba(127,127,213,0.92)',
  },
  heroTop: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  heroBadge: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: 'rgba(255,255,255,0.24)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroBadgeText: {
    color: colors.white,
    fontSize: 26,
    fontWeight: '900',
  },
  heroBody: {
    flex: 1,
    gap: spacing.xxs,
  },
  heroTitle: {
    color: colors.white,
    fontSize: 24,
    fontWeight: '900',
  },
  heroCopy: {
    color: 'rgba(255,255,255,0.82)',
    fontSize: 13,
    lineHeight: 20,
  },
  metricRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  storyRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  storyCard: {
    flex: 1,
    minHeight: 92,
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: colors.line,
    padding: spacing.sm,
    justifyContent: 'space-between',
  },
  storyCardPressed: {
    transform: [{ scale: 0.985 }, { translateY: 1 }],
    opacity: 0.94,
  },
  storyOrb: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(255,255,255,0.68)',
  },
  storyTitle: {
    color: colors.text,
    fontSize: 13,
    fontWeight: '800',
  },
  trendWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  trendChip: {
    borderRadius: radii.pill,
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  trendText: {
    color: colors.primaryDeep,
    fontSize: 12,
    fontWeight: '700',
  },
  quickGrid: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  quickCard: {
    flex: 1,
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: colors.line,
    padding: spacing.md,
    gap: 6,
  },
  quickCardLilac: {
    backgroundColor: colors.primarySoft,
  },
  quickCardBlue: {
    backgroundColor: colors.accentSoft,
  },
  quickCardPressed: {
    transform: [{ scale: 0.985 }, { translateY: 1 }],
    opacity: 0.94,
  },
  quickEyebrow: {
    color: colors.textSoft,
    fontSize: 11,
    fontWeight: '800',
    textTransform: 'uppercase',
  },
  quickTitle: {
    color: colors.text,
    fontWeight: '800',
    fontSize: 16,
  },
  quickSub: {
    color: colors.textMuted,
    lineHeight: 20,
    fontSize: 13,
  },
  refresh: {
    color: colors.primaryDeep,
    fontSize: 12,
    fontWeight: '800',
  },
  linkPressed: {
    opacity: 0.72,
  },
  feed: {
    gap: spacing.sm,
  },
  postCard: {
    borderRadius: radii.lg,
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
    padding: spacing.md,
    gap: spacing.sm,
  },
  postHeader: {
    flexDirection: 'row',
    gap: spacing.sm,
    alignItems: 'center',
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.primarySoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: colors.text,
    fontWeight: '800',
  },
  headerBody: {
    flex: 1,
    gap: 2,
  },
  userName: {
    color: colors.text,
    fontWeight: '800',
  },
  postMeta: {
    color: colors.textMuted,
    fontSize: 12,
  },
  postTypeBadge: {
    borderRadius: radii.pill,
    backgroundColor: colors.panelSoft,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  postTypeText: {
    color: colors.textSoft,
    fontSize: 11,
    fontWeight: '700',
  },
  content: {
    color: colors.text,
    lineHeight: 22,
  },
  tags: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  tag: {
    borderRadius: radii.pill,
    backgroundColor: colors.primarySoft,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  tagText: {
    color: colors.primaryDeep,
    fontSize: 12,
    fontWeight: '700',
  },
  actions: {
    flexDirection: 'row',
    gap: spacing.sm,
    flexWrap: 'wrap',
  },
  action: {
    borderRadius: radii.pill,
    backgroundColor: colors.panelSoft,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  actionPressed: {
    opacity: 0.88,
    transform: [{ scale: 0.98 }],
  },
  actionLiked: {
    backgroundColor: colors.primarySoft,
  },
  actionText: {
    color: colors.textMuted,
    fontSize: 12,
    fontWeight: '700',
  },
  actionTextLiked: {
    color: colors.primaryDeep,
  },
});
