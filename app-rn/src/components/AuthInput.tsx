import React from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';

import { colors, radii, spacing } from '../theme/tokens';

export function AuthInput({
  label,
  placeholder,
  value,
  onChangeText,
  secureTextEntry,
  keyboardType,
  autoCapitalize = 'none',
  error,
  returnKeyType,
  compact = false,
}: {
  label: string;
  placeholder: string;
  value: string;
  onChangeText: (value: string) => void;
  secureTextEntry?: boolean;
  keyboardType?: 'default' | 'email-address' | 'number-pad';
  autoCapitalize?: 'none' | 'sentences' | 'words' | 'characters';
  error?: string;
  returnKeyType?: 'done' | 'next' | 'send' | 'go';
  compact?: boolean;
}) {
  return (
    <View style={[styles.wrap, compact ? styles.wrapCompact : null]}>
      <Text style={[styles.label, compact ? styles.labelCompact : null]}>{label}</Text>
      <TextInput
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor="#9BA8C1"
        secureTextEntry={secureTextEntry}
        keyboardType={keyboardType}
        autoCapitalize={autoCapitalize}
        returnKeyType={returnKeyType}
        style={[
          styles.input,
          compact ? styles.inputCompact : null,
          value.trim().length > 0 ? styles.inputFilled : null,
          error ? styles.inputError : null,
        ]}
      />
      {error ? <Text style={[styles.error, compact ? styles.errorCompact : null]}>{error}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    gap: 8,
  },
  wrapCompact: {
    gap: 6,
  },
  label: {
    color: colors.textMuted,
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 0.2,
  },
  labelCompact: {
    fontSize: 12,
  },
  input: {
    minHeight: 54,
    borderRadius: radii.lg,
    borderWidth: 1,
    borderColor: colors.line,
    backgroundColor: colors.white,
    paddingHorizontal: spacing.md,
    color: colors.text,
    fontSize: 16,
    fontWeight: '600',
    shadowColor: '#D8E2FB',
    shadowOpacity: 0.24,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 4 },
  },
  inputCompact: {
    minHeight: 50,
    fontSize: 15,
  },
  inputFilled: {
    backgroundColor: colors.panelSoft,
  },
  inputError: {
    borderColor: colors.danger,
    backgroundColor: colors.dangerSoft,
    shadowOpacity: 0.12,
  },
  error: {
    color: colors.danger,
    fontSize: 12,
    fontWeight: '500',
  },
  errorCompact: {
    fontSize: 11,
  },
});
