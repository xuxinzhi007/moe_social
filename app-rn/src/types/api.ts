export interface ApiEnvelope<T = Record<string, unknown>> {
  success?: boolean;
  message?: string;
  code?: number;
  token?: string;
  user?: Record<string, unknown>;
  data?: T | Record<string, unknown>;
}
