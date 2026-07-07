export interface LifeWorldSummary {
  totalEntities: number;
  births: number;
  deaths: number;
  tribes: number;
  relationships: number;
  tick: number;
}

export interface LifeEntity {
  id: string;
  name: string;
  x: number;
  y: number;
  energy?: number;
  age?: number;
  state?: string;
  tribe?: string;
}

export interface LifeWorldSnapshot {
  worldId: string;
  tick: number;
  summary: LifeWorldSummary;
  entities: LifeEntity[];
  events: string[];
}
