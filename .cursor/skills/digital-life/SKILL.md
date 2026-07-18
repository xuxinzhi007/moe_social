# Digital Life Skill

Use this skill when changing `lib/pages/life/`, `lib/widgets/life/`, `lib/providers/life_provider.dart`, `lib/services/life_*`, or backend `life` domain code.

## Product Direction

- Digital Life is the user's private personal world: autonomous entities, emergent events, light care actions, and observation.
- The main UX should answer three questions quickly: who needs attention, what should the user do now, and what changed recently.
- Keep the primary screen companion-first. World simulation is supporting context, not a dense management dashboard.
- Do not reintroduce game-hub positioning, combat loops, ranking, multiplayer, or heavy map controls without explicit product approval.

## Frontend Rules

- Preserve the current REST + WebSocket boundary: `LifeProvider` owns state, `LifeService` wraps REST, `LifeWsService` handles realtime updates.
- Prefer read-only UX improvements before protocol changes: care insight, world pulse, event grouping, resident selection, empty/offline states.
- Keep action buttons sparse and high intent: feed, companion/pet, detail, story. Avoid adding many low-value buttons.
- Offline mode must remain usable for reading cached state. Disable mutating actions while offline and explain the state clearly.
- Avoid rebuilding the whole page every tick. Use `Selector` data classes and coarse buckets for rapidly changing numeric values.

## Backend Rules

- Life engine changes must preserve tick safety, cache replacement, persistence writer behavior, and feature-flag rollback.
- WebSocket payloads should remain incremental. Add fields only when the frontend cannot derive the information locally.
- User actions must keep cooldown and clear error semantics. Treat cooldown as a soft UX state, not a fatal error.

## Next Useful Improvements

- Add grouped event summaries: care events, growth events, relationship events, risk events.
- Add care priority sorting for residents when there are many entities.
- Add optional item suggestions from inventory based on the selected entity's weakest stat.
- Add a read-only history view before building playback or speed controls.
