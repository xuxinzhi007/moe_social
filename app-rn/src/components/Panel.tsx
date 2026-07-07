import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { colors, radii, spacing } from '../theme/tokens';

export function Panel({
  title,
  children,
  right,
  style,
  subtle = false,
}: {
  title?: string;
  children: React.ReactNode;
  right?: React.ReactNode;
  style?: object;
  subtle?: boolean;
}) {
  return (
    <View style={[styles.panel, subtle ? styles.panelSubtle : null, style]}>
      <View style={styles.glow} />
      {title ? (
        <View style={styles.header}>
          <Text style={styles.title}>{title}</Text>
          {right}
        </View>
      ) : null}
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  panel: {
    backgroundColor: colors.panel,
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: radii.xl,
    padding: spacing.md,
    gap: spacing.sm,
    shadowColor: '#AAA6DE',
    shadowOpacity: 0.12,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
    overflow: 'hidden',
  },
  panelSubtle: {
    backgroundColor: 'rgba(255,255,255,0.60)',
  },
  glow: {
    position: 'absolute',
    top: -38,
    right: -20,
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: 'rgba(255,255,255,0.24)',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: spacing.sm,
  },
  title: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '800',
  },
});
