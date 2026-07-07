import { StatusBar } from 'expo-status-bar';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';

import { AuthScreen } from './src/features/auth/AuthScreen';
import { RootShell } from './src/navigation/RootShell';
import { AppStoreProvider, useAppStore } from './src/store/appStore';
import { colors } from './src/theme/tokens';

function AppContent() {
  const { bootstrapped, bootMessage, session } = useAppStore();

  if (!bootstrapped) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator color={colors.primary} size="large" />
        <Text style={styles.loadingText}>{bootMessage}</Text>
      </View>
    );
  }

  return session ? <RootShell /> : <AuthScreen />;
}

export default function App() {
  return (
    <AppStoreProvider>
      <StatusBar style="light" />
      <AppContent />
    </AppStoreProvider>
  );
}

const styles = StyleSheet.create({
  loading: {
    flex: 1,
    backgroundColor: colors.bg,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 14,
  },
  loadingText: {
    color: colors.textMuted,
    fontSize: 13,
    fontWeight: '700',
  },
});
