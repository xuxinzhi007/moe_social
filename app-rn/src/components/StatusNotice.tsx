import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { colors, radii, spacing } from '../theme/tokens';

export function StatusNotice({
  title,
  message,
  tone = 'neutral',
}: {
  title: string;
  message?: string;
  tone?: 'neutral' | 'error' | 'success';
}) {
  const toneStyle =
    tone === 'error' ? styles.error : tone === 'success' ? styles.success : styles.neutral;
  const titleStyle =
    tone === 'error'
      ? styles.titleError
      : tone === 'success'
        ? styles.titleSuccess
        : styles.titleNeutral;

  return (
    <View style={[styles.card, toneStyle]}>
      <Text style={[styles.title, titleStyle]}>{title}</Text>
      {message ? <Text style={styles.message}>{message}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: radii.lg,
    borderWidth: 1,
    padding: spacing.md,
    gap: spacing.xs,
  },
  neutral: {
    backgroundColor: colors.panelSoft,
    borderColor: colors.line,
  },
  error: {
    backgroundColor: colors.dangerSoft,
    borderColor: 'rgba(244,109,140,0.22)',
  },
  success: {
    backgroundColor: colors.successSoft,
    borderColor: 'rgba(74,192,142,0.20)',
  },
  title: {
    fontSize: 14,
    fontWeight: '800',
  },
  titleNeutral: {
    color: colors.text,
  },
  titleError: {
    color: colors.danger,
  },
  titleSuccess: {
    color: colors.success,
  },
  message: {
    color: colors.textMuted,
    fontSize: 13,
    lineHeight: 20,
  },
});
