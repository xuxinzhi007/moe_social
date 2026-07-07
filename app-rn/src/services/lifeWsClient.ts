import { AppConfig } from '../config/appConfig';
import type { LifeWorldSnapshot } from '../types/life';

export type LifeWsStatus =
  | 'idle'
  | 'connecting'
  | 'connected'
  | 'disconnected'
  | 'error'
  | 'parse_error';

interface LifeWsClientOptions {
  getToken?: () => string | null;
  onSnapshot?: (snapshot: LifeWorldSnapshot) => void;
  onStatusChange?: (status: LifeWsStatus) => void;
  autoReconnect?: boolean;
}

function numberValue(value: unknown, fallback = 0) {
  return typeof value === 'number' ? value : fallback;
}

export class LifeWsClient {
  private socket: WebSocket | null = null;

  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;

  private readonly getToken?: () => string | null;

  private readonly onSnapshot?: (snapshot: LifeWorldSnapshot) => void;

  private readonly onStatusChange?: (status: LifeWsStatus) => void;

  private readonly autoReconnect: boolean;

  private manuallyDisconnected = false;

  constructor(options: LifeWsClientOptions = {}) {
    this.getToken = options.getToken;
    this.onSnapshot = options.onSnapshot;
    this.onStatusChange = options.onStatusChange;
    this.autoReconnect = options.autoReconnect ?? true;
  }

  connect() {
    if (this.socket) {
      return;
    }

    this.manuallyDisconnected = false;
    const token = this.getToken?.() ?? undefined;
    this.onStatusChange?.('connecting');
    this.socket = new WebSocket(AppConfig.buildWsUrl(token));

    this.socket.onopen = () => {
      this.onStatusChange?.('connected');
      this.socket?.send(JSON.stringify({ type: 'subscribe', world: 'default' }));
    };

    this.socket.onmessage = (event) => {
      this.handleMessage(String(event.data));
    };

    this.socket.onerror = () => {
      this.onStatusChange?.('error');
    };

    this.socket.onclose = () => {
      this.socket = null;
      this.onStatusChange?.('disconnected');
      this.scheduleReconnect();
    };
  }

  disconnect() {
    this.manuallyDisconnected = true;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    this.socket?.close();
    this.socket = null;
    this.onStatusChange?.('idle');
  }

  private scheduleReconnect() {
    if (this.reconnectTimer || this.manuallyDisconnected || !this.autoReconnect) {
      return;
    }

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect();
    }, 3000);
  }

  private handleMessage(raw: string) {
    try {
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      if (
        parsed.type !== 'state_snapshot' &&
        parsed.type !== 'life_state'
      ) {
        return;
      }

      const entities = Array.isArray(parsed.entities) ? parsed.entities : [];
      const summary = (parsed.summary ?? {}) as Record<string, unknown>;

      this.onSnapshot?.({
        worldId: String(parsed.world_id ?? 'default'),
        tick: numberValue(parsed.tick),
        summary: {
          totalEntities: numberValue(summary.total_entities),
          births: numberValue(summary.births),
          deaths: numberValue(summary.deaths),
          tribes: numberValue(summary.tribes),
          relationships: numberValue(summary.relationships),
          tick: numberValue(parsed.tick),
        },
        entities: entities.map((item, index) => {
          const entity = item as Record<string, unknown>;
          return {
            id: String(entity.id ?? index),
            name: String(entity.name ?? `Life ${index + 1}`),
            x: numberValue(entity.x),
            y: numberValue(entity.y),
            energy: numberValue(entity.energy),
            age: numberValue(entity.age),
            state: entity.state ? String(entity.state) : undefined,
            tribe: entity.tribe ? String(entity.tribe) : undefined,
          };
        }),
        events: Array.isArray(parsed.events)
          ? parsed.events.map((item) => String(item))
          : [],
      });
    } catch {
      this.onStatusChange?.('parse_error');
    }
  }
}
