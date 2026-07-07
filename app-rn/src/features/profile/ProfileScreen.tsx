import React, { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { ActionButton } from '../../components/ActionButton';
import { MetricCard } from '../../components/MetricCard';
import { Panel } from '../../components/Panel';
import { Screen } from '../../components/Screen';
import { getUserProfile, updateUserProfile } from '../../services/profileService';
import { useAppStore } from '../../store/appStore';
import { colors, radii, spacing } from '../../theme/tokens';

export function ProfileScreen() {
  const { apiClient, session, profile, setProfile, logout } = useAppStore();
  const [editing, setEditing] = useState(false);
  const [username, setUsername] = useState('');
  const [signature, setSignature] = useState('');
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!session?.userId) {
      return;
    }

    setLoading(true);
    setError('');
    void getUserProfile(apiClient, session.userId)
      .then((result) => {
        setProfile(result);
        setUsername(result.username);
        setSignature(result.signature);
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : '加载个人资料失败');
      })
      .finally(() => {
        setLoading(false);
      });
  }, [apiClient, session?.userId, setProfile]);

  const handleSave = async () => {
    if (!profile) {
      return;
    }

    setSaving(true);
    setError('');
    try {
      const next = await updateUserProfile(apiClient, {
        id: profile.id,
        username,
        signature,
        gender: profile.gender,
        birthday: profile.birthday,
        avatar: profile.avatar,
        email: profile.email,
      });
      setProfile(next);
      setEditing(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : '保存资料失败');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Screen
      title="我的"
      subtitle="先把 Flutter 个人页的层次感和编辑入口迁过来，让资料区更像完整成品。"
      eyebrow="Profile"
    >
      <Panel style={styles.headerPanel}>
        {loading ? <Text style={styles.muted}>加载中...</Text> : null}
        {!loading && profile ? (
          <>
            <View style={styles.profileHead}>
              <View style={styles.avatar}>
                <Text style={styles.avatarText}>
                  {(profile.username || session?.nickname || '?').slice(0, 1).toUpperCase()}
                </Text>
              </View>
              <View style={styles.profileMeta}>
                <Text style={styles.name}>{profile.username}</Text>
                <Text style={styles.sub}>Moe 号 {profile.moeNo || profile.displayUserId || profile.id}</Text>
                <Text style={styles.sub}>{profile.email || '未设置邮箱'}</Text>
              </View>
            </View>
            <Text style={styles.signature}>{profile.signature || '这个人还没有留下签名。'}</Text>
            <View style={styles.metrics}>
              <MetricCard label="会员状态" value={profile.isVip ? 'VIP' : '普通'} tone="soft" />
              <MetricCard label="余额" value={profile.balance.toFixed(2)} tone="accent" />
              <MetricCard label="魅力值" value={profile.giftCharm} tone="primary" />
            </View>
          </>
        ) : null}
        {error ? <Text style={styles.error}>{error}</Text> : null}
      </Panel>

      <Panel
        title="编辑资料"
        right={
          <Pressable onPress={() => setEditing((current) => !current)}>
            <Text style={styles.link}>{editing ? '收起' : '编辑'}</Text>
          </Pressable>
        }
      >
        <TextInput
          value={username}
          onChangeText={setUsername}
          editable={editing && !saving}
          placeholder="昵称"
          placeholderTextColor={colors.textMuted}
          style={[styles.input, !editing ? styles.inputDisabled : null]}
        />
        <TextInput
          value={signature}
          onChangeText={setSignature}
          editable={editing && !saving}
          placeholder="签名"
          placeholderTextColor={colors.textMuted}
          style={[styles.input, styles.textarea, !editing ? styles.inputDisabled : null]}
          multiline
        />
        {editing ? (
          <ActionButton label={saving ? '保存中...' : '保存资料'} onPress={() => void handleSave()} />
        ) : (
          <Text style={styles.muted}>点右上角编辑后，可以直接修改昵称和签名。</Text>
        )}
      </Panel>

      <Panel title="后续入口">
        <View style={styles.entryList}>
          <View style={[styles.entry, styles.entryAmber]}>
            <Text style={styles.entryTitle}>钱包 / VIP / 订单</Text>
            <Text style={styles.entrySub}>接口已经在后端，下一轮可以直接补页面。</Text>
          </View>
          <View style={[styles.entry, styles.entryBlue]}>
            <Text style={styles.entryTitle}>好友 / 关注 / 成就</Text>
            <Text style={styles.entrySub}>和 Flutter 端的数据契约可以继续复用。</Text>
          </View>
          <View style={[styles.entry, styles.entryMint]}>
            <Text style={styles.entryTitle}>设置 / 安全 / 设备管理</Text>
            <Text style={styles.entrySub}>后面把管理入口和细页逐个接回来。</Text>
          </View>
        </View>
      </Panel>

      <ActionButton label="退出登录" onPress={() => void logout()} secondary />
    </Screen>
  );
}

const styles = StyleSheet.create({
  muted: {
    color: colors.textMuted,
    lineHeight: 20,
  },
  error: {
    color: colors.danger,
  },
  headerPanel: {
    backgroundColor: 'rgba(127,127,213,0.92)',
  },
  profileHead: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  avatar: {
    width: 76,
    height: 76,
    borderRadius: 38,
    backgroundColor: 'rgba(255,255,255,0.26)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: colors.white,
    fontSize: 28,
    fontWeight: '800',
  },
  profileMeta: {
    flex: 1,
    gap: 4,
  },
  name: {
    color: colors.white,
    fontSize: 24,
    fontWeight: '900',
  },
  sub: {
    color: 'rgba(255,255,255,0.82)',
    fontSize: 13,
  },
  metrics: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  signature: {
    color: 'rgba(255,255,255,0.92)',
    lineHeight: 22,
  },
  link: {
    color: colors.primaryDeep,
    fontWeight: '700',
    fontSize: 12,
  },
  input: {
    minHeight: 48,
    borderRadius: radii.lg,
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.line,
    paddingHorizontal: spacing.md,
    color: colors.text,
  },
  textarea: {
    minHeight: 92,
    paddingVertical: spacing.sm,
    textAlignVertical: 'top',
  },
  inputDisabled: {
    opacity: 0.7,
  },
  entryList: {
    gap: spacing.sm,
  },
  entry: {
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: colors.line,
    padding: spacing.md,
    gap: 4,
  },
  entryAmber: {
    backgroundColor: colors.warnSoft,
  },
  entryBlue: {
    backgroundColor: colors.accentSoft,
  },
  entryMint: {
    backgroundColor: colors.secondarySoft,
  },
  entryTitle: {
    color: colors.text,
    fontWeight: '800',
  },
  entrySub: {
    color: colors.textMuted,
    lineHeight: 20,
    fontSize: 13,
  },
});
