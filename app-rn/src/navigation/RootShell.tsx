import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { AiScreen } from '../features/ai/AiScreen';
import { ChatScreen } from '../features/chat/ChatScreen';
import { HomeScreen } from '../features/home/HomeScreen';
import { ProfileScreen } from '../features/profile/ProfileScreen';
import { useAppStore } from '../store/appStore';
import { colors, radii, spacing } from '../theme/tokens';

const tabs = [
  { key: 'home', label: '首页' },
  { key: 'chat', label: '聊天' },
  { key: 'ai', label: 'AI' },
  { key: 'profile', label: '我的' },
] as const;

function TabGlyph({ tabKey, active }: { tabKey: (typeof tabs)[number]['key']; active: boolean }) {
  const tone = active ? colors.primaryDeep : colors.textSoft;

  if (tabKey === 'home') {
    return (
      <View style={styles.glyphBox}>
        <View style={[styles.homeRoof, { borderBottomColor: tone }]} />
        <View style={[styles.homeBase, { borderColor: tone }]} />
      </View>
    );
  }

  if (tabKey === 'chat') {
    return (
      <View style={styles.glyphBox}>
        <View style={[styles.chatBubble, { borderColor: tone }]}>
          <View style={[styles.chatDot, { backgroundColor: tone }]} />
          <View style={[styles.chatDot, { backgroundColor: tone }]} />
          <View style={[styles.chatDot, { backgroundColor: tone }]} />
        </View>
      </View>
    );
  }

  if (tabKey === 'ai') {
    return (
      <View style={styles.glyphBox}>
        <View style={[styles.aiCore, { borderColor: tone }]}>
          <View style={[styles.aiNode, styles.aiNodeTop, { backgroundColor: tone }]} />
          <View style={[styles.aiNode, styles.aiNodeLeft, { backgroundColor: tone }]} />
          <View style={[styles.aiNode, styles.aiNodeRight, { backgroundColor: tone }]} />
        </View>
      </View>
    );
  }

  return (
    <View style={styles.glyphBox}>
      <View style={[styles.profileHead, { borderColor: tone }]} />
      <View style={[styles.profileBody, { borderColor: tone }]} />
    </View>
  );
}

export function RootShell() {
  const { activeTab, setActiveTab } = useAppStore();

  return (
    <View style={styles.root}>
      <View style={styles.content}>
        {activeTab === 'home' ? <HomeScreen /> : null}
        {activeTab === 'chat' ? <ChatScreen /> : null}
        {activeTab === 'ai' ? <AiScreen /> : null}
        {activeTab === 'profile' ? <ProfileScreen /> : null}
      </View>

      <View style={styles.navWrap}>
        <View style={styles.navGlow} />
        <View style={styles.nav}>
          {tabs.map((tab) => {
            const active = tab.key === activeTab;

            return (
              <Pressable
                key={tab.key}
                onPress={() => setActiveTab(tab.key)}
                style={({ pressed }) => [
                  styles.tab,
                  active ? styles.tabActive : null,
                  pressed ? styles.tabPressed : null,
                ]}
              >
                <TabGlyph tabKey={tab.key} active={active} />
                <Text style={[styles.tabLabel, active ? styles.tabLabelActive : null]}>{tab.label}</Text>
                {active ? <View style={styles.activePill} /> : null}
              </Pressable>
            );
          })}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.bg,
  },
  content: {
    flex: 1,
  },
  navWrap: {
    position: 'absolute',
    left: 16,
    right: 16,
    bottom: 18,
  },
  navGlow: {
    position: 'absolute',
    top: -8,
    left: 60,
    right: 60,
    height: 40,
    borderRadius: radii.pill,
    backgroundColor: 'rgba(127,127,213,0.14)',
  },
  nav: {
    flexDirection: 'row',
    gap: spacing.xs,
    padding: 8,
    borderRadius: radii.xl,
    backgroundColor: 'rgba(255,255,255,0.95)',
    borderWidth: 1,
    borderColor: colors.line,
    shadowColor: '#A09DD8',
    shadowOpacity: 0.22,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 8 },
  },
  tab: {
    flex: 1,
    minHeight: 62,
    borderRadius: radii.lg,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    position: 'relative',
  },
  tabActive: {
    backgroundColor: colors.primarySoft,
  },
  tabPressed: {
    opacity: 0.92,
  },
  glyphBox: {
    width: 24,
    height: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  homeRoof: {
    width: 0,
    height: 0,
    borderLeftWidth: 8,
    borderRightWidth: 8,
    borderBottomWidth: 8,
    borderLeftColor: 'transparent',
    borderRightColor: 'transparent',
    marginBottom: -1,
  },
  homeBase: {
    width: 14,
    height: 10,
    borderWidth: 2,
    borderRadius: 3,
    backgroundColor: 'transparent',
  },
  chatBubble: {
    width: 18,
    height: 14,
    borderWidth: 2,
    borderRadius: 6,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
  },
  chatDot: {
    width: 2,
    height: 2,
    borderRadius: 1,
  },
  aiCore: {
    width: 16,
    height: 16,
    borderWidth: 2,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  aiNode: {
    position: 'absolute',
    width: 4,
    height: 4,
    borderRadius: 2,
  },
  aiNodeTop: {
    top: -2,
  },
  aiNodeLeft: {
    left: -2,
  },
  aiNodeRight: {
    right: -2,
  },
  profileHead: {
    width: 8,
    height: 8,
    borderWidth: 2,
    borderRadius: 4,
    marginBottom: 1,
  },
  profileBody: {
    width: 14,
    height: 9,
    borderWidth: 2,
    borderTopLeftRadius: 7,
    borderTopRightRadius: 7,
    borderBottomLeftRadius: 4,
    borderBottomRightRadius: 4,
  },
  tabLabel: {
    color: colors.textSoft,
    fontSize: 11,
    fontWeight: '700',
  },
  tabLabelActive: {
    color: colors.primaryDeep,
  },
  activePill: {
    position: 'absolute',
    bottom: 6,
    width: 18,
    height: 3,
    borderRadius: 2,
    backgroundColor: colors.primaryDeep,
  },
});
