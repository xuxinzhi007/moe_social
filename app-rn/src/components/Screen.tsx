import React from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { colors, radii, spacing } from '../theme/tokens';

export function Screen({
  title,
  subtitle,
  children,
  centered = false,
  eyebrow,
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  centered?: boolean;
  eyebrow?: string;
}) {
  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      style={styles.root}
    >
      <View style={[styles.blob, styles.blobTop]} />
      <View style={[styles.blob, styles.blobRight]} />
      <View style={[styles.blob, styles.blobBottom]} />
      <ScrollView
        contentContainerStyle={[styles.content, centered ? styles.centered : null]}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.hero}>
          {eyebrow ? (
            <View style={styles.eyebrowChip}>
              <Text style={styles.eyebrow}>{eyebrow}</Text>
            </View>
          ) : null}
          <Text style={styles.title}>{title}</Text>
          {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
        </View>
        {children}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.bg,
  },
  blob: {
    position: 'absolute',
    borderRadius: radii.pill,
  },
  blobTop: {
    top: -80,
    left: -60,
    width: 260,
    height: 260,
    backgroundColor: 'rgba(127,127,213,0.22)',
  },
  blobRight: {
    top: 180,
    right: -70,
    width: 220,
    height: 220,
    backgroundColor: 'rgba(134,168,231,0.18)',
  },
  blobBottom: {
    bottom: -90,
    left: -50,
    width: 280,
    height: 280,
    backgroundColor: 'rgba(145,234,228,0.14)',
  },
  content: {
    paddingHorizontal: spacing.lg,
    paddingTop: 52,
    paddingBottom: 132,
    gap: spacing.lg,
  },
  centered: {
    flexGrow: 1,
    justifyContent: 'center',
  },
  hero: {
    gap: spacing.sm,
    marginBottom: spacing.xs,
    padding: spacing.lg,
    borderRadius: radii.xl,
    backgroundColor: 'rgba(255,255,255,0.72)',
    borderWidth: 1,
    borderColor: colors.line,
    shadowColor: '#A7A5DD',
    shadowOpacity: 0.18,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 8 },
  },
  eyebrowChip: {
    alignSelf: 'flex-start',
    borderRadius: radii.pill,
    backgroundColor: colors.primarySoft,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xxs,
  },
  eyebrow: {
    color: colors.primaryDeep,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.8,
    textTransform: 'uppercase',
  },
  title: {
    color: colors.text,
    fontSize: 32,
    lineHeight: 38,
    fontWeight: '900',
  },
  subtitle: {
    color: colors.textMuted,
    fontSize: 14,
    lineHeight: 22,
  },
});
