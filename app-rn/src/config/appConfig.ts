import Constants from 'expo-constants';

export type ApiEnvironment = 'local' | 'tunnel' | 'online';

interface ExpoExtraConfig {
  apiEnv?: string;
  apiUrls?: Partial<Record<ApiEnvironment, string>>;
  wsPath?: string;
}

function normalizeUrl(value: string | undefined, fallback: string) {
  const next = (value ?? fallback).trim();
  return next.replace(/\/+$/, '');
}

function readExtraConfig(): ExpoExtraConfig {
  const extra = Constants.expoConfig?.extra;
  if (!extra || typeof extra !== 'object') {
    return {};
  }
  return extra as ExpoExtraConfig;
}

function readEnvironment(extra: ExpoExtraConfig): ApiEnvironment {
  const env = extra.apiEnv;
  if (env === 'local' || env === 'tunnel' || env === 'online') {
    return env;
  }
  return 'local';
}

const fallbackUrls: Record<ApiEnvironment, string> = {
  online: 'http://47.106.175.49:8888',
  local: 'http://127.0.0.1:8888',
  tunnel: 'http://47.106.175.49:8888',
};

const extraConfig = readExtraConfig();
const environment = readEnvironment(extraConfig);
const apiUrls = {
  online: normalizeUrl(extraConfig.apiUrls?.online, fallbackUrls.online),
  local: normalizeUrl(extraConfig.apiUrls?.local, fallbackUrls.local),
  tunnel: normalizeUrl(extraConfig.apiUrls?.tunnel, fallbackUrls.tunnel),
};
const wsPath = extraConfig.wsPath?.trim() || '/ws/life';

export class AppConfig {
  static readonly environment = environment;

  static readonly apiUrls = apiUrls;

  static readonly wsPath = wsPath;

  static get isProduction() {
    return AppConfig.environment === 'online';
  }

  static get baseUrl() {
    return AppConfig.apiUrls[AppConfig.environment];
  }

  static get apiUrl() {
    return AppConfig.baseUrl;
  }

  static buildWsUrl(token?: string) {
    const url = new URL(AppConfig.baseUrl);
    url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
    url.pathname = AppConfig.wsPath;
    url.search = '';

    if (token) {
      url.searchParams.set('token', token);
    }

    return url.toString();
  }
}

