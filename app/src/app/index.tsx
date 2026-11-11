import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { config } from '@/lib/config';

type HealthResponse = {
  status: string;
  version: string;
  cache: string;
  db: string;
  env: string;
};

type HealthState =
  | { kind: 'loading' }
  | { kind: 'ok'; message: string; data: HealthResponse }
  | { kind: 'error'; message: string };

export default function HomeScreen() {
  const [state, setState] = useState<HealthState>({ kind: 'loading' });

  const checkHealth = useCallback(async () => {
    setState({ kind: 'loading' });
    try {
      const response = await fetch(`${config.apiUrl}/health`, {
        headers: { Accept: 'application/json' },
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const data = (await response.json()) as HealthResponse;
      if (data.status !== 'ok') {
        throw new Error(`Unexpected status: ${data.status}`);
      }
      setState({
        kind: 'ok',
        message: `API ok (cache: ${data.cache}, db: ${data.db})`,
        data,
      });
    } catch (err) {
      const detail = err instanceof Error ? err.message : 'Unable to reach API';
      setState({
        kind: 'error',
        message: `Health check failed: ${detail}`,
      });
    }
  }, []);

  useEffect(() => {
    void checkHealth();
  }, [checkHealth]);

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.card}>
        <Text style={styles.title}>{config.appName}</Text>
        <Text style={styles.subtitle}>{config.apiUrl}/health</Text>

        {state.kind === 'loading' && (
          <View style={styles.statusRow}>
            <ActivityIndicator size="small" color="#2563eb" />
            <Text style={styles.statusText}>Checking API...</Text>
          </View>
        )}

        {state.kind === 'ok' && (
          <View style={styles.statusBoxOk}>
            <Text style={styles.statusTextOk}>{state.message}</Text>
            <Pressable style={styles.retryButton} onPress={checkHealth}>
              <Text style={styles.retryButtonText}>Refresh</Text>
            </Pressable>
          </View>
        )}

        {state.kind === 'error' && (
          <View style={styles.statusBoxErr}>
            <Text style={styles.statusTextErr}>{state.message}</Text>
            <Pressable style={styles.retryButton} onPress={checkHealth}>
              <Text style={styles.retryButtonText}>Retry</Text>
            </Pressable>
          </View>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0b0b0f',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  card: {
    width: '100%',
    maxWidth: 420,
    backgroundColor: '#16161d',
    borderRadius: 16,
    padding: 24,
    borderWidth: 1,
    borderColor: '#272733',
    gap: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    color: '#f4f4f6',
  },
  subtitle: {
    fontSize: 13,
    color: '#9ca3af',
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingVertical: 8,
  },
  statusText: {
    fontSize: 15,
    color: '#d1d5db',
  },
  statusBoxOk: {
    gap: 12,
  },
  statusTextOk: {
    fontSize: 15,
    fontWeight: '600',
    color: '#4ade80',
  },
  statusBoxErr: {
    gap: 12,
  },
  statusTextErr: {
    fontSize: 15,
    color: '#f87171',
  },
  retryButton: {
    alignSelf: 'flex-start',
    backgroundColor: '#2563eb',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#ffffff',
    fontWeight: '600',
    fontSize: 14,
  },
});
