import React from 'react';
import { Pressable, StyleSheet, Text } from 'react-native';

import { colors, radii, spacing } from '../theme/tokens';

export function ActionButton({
  label,
  onPress,
  secondary = false,
  compact = false,
  disabled = false,
}: {
  label: string;
  onPress?: () => void;
  secondary?: boolean;
  compact?: boolean;
  disabled?: boolean;
}) {
  return (
    <Pressable
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        compact ? styles.compact : null,
        secondary ? styles.secondary : styles.primary,
        disabled ? styles.disabled : null,
        pressed && !disabled ? styles.pressed : null,
      ]}
    >
      <Text style={[styles.label, secondary ? styles.secondaryLabel : null, disabled ? styles.disabledLabel : null]}>
        {label}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    minHeight: 52,
    borderRadius: radii.pill,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.lg,
    borderWidth: 1,
    borderColor: 'transparent',
  },
  compact: {
    minHeight: 44,
    paddingHorizontal: spacing.md,
  },
  primary: {
    backgroundColor: colors.primary,
    shadowColor: colors.primary,
    shadowOpacity: 0.26,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
  },
  secondary: {
    backgroundColor: colors.white,
    borderColor: colors.line,
    shadowColor: '#C9C6E8',
    shadowOpacity: 0.14,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 5 },
  },
  pressed: {
    opacity: 0.92,
    transform: [{ scale: 0.985 }, { translateY: 1 }],
  },
  disabled: {
    opacity: 0.58,
    shadowOpacity: 0,
  },
  label: {
    color: colors.white,
    fontSize: 15,
    fontWeight: '800',
  },
  secondaryLabel: {
    color: colors.text,
  },
  disabledLabel: {
    color: colors.textMuted,
  },
});
