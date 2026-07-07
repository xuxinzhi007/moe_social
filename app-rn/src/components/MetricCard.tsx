import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { colors, radii, spacing } from '../theme/tokens';

export function MetricCard({
  label,
  value,
  tone = 'primary',
}: {
  label: string;
  value: string | number;
  tone?: 'primary' | 'accent' | 'soft';
}) {
  const toneStyle =
    tone === 'accent' ? styles.cardAccent : tone === 'soft' ? styles.cardSoft : styles.cardPrimary;

  return (
    <View style={[styles.card, toneStyle]}>
      <View style={styles.highlight} />
      <Text style={styles.label}>{label}</Text>
      <Text style={styles.value}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flex: 1,
    minWidth: 100,
    borderRadius: radii.lg,
    padding: spacing.md,
    borderWidth: 1,
    borderColor: colors.line,
    gap: spacing.xs,
    overflow: 'hidden',
  },
  cardPrimary: {
    backgroundColor: colors.primarySoft,
  },
  cardAccent: {
    backgroundColor: colors.accentSoft,
  },
  cardSoft: {
    backgroundColor: colors.white,
  },
  label: {
    color: colors.textMuted,
    fontSize: 12,
    fontWeight: '700',
  },
  highlight: {
    position: 'absolute',
    top: -24,
    right: -12,
    width: 68,
    height: 68,
    borderRadius: 34,
    backgroundColor: 'rgba(255,255,255,0.32)',
  },
  value: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '900',
  },
});
