# Moe Flutter App Skill

Use this skill when changing the Flutter client in `lib/`, especially user-facing flows, shared widgets, navigation, AI chat, feed, messaging, profile, settings, commerce, and digital life.

## Product Boundary

- Moe Social is a moe-themed mood social app. The primary paths are posting mood/content, browsing/interacting with feed, messaging/friends, AI interaction, and profile/settings.
- AI features should enhance social companionship. Do not turn the app into a generic AI toolbox.
- Game, gacha, and AutoGLM code paths are not primary product surfaces. Keep them behind feature flags unless explicitly requested.
- Digital Life is a private personal world/companion feature, not a game hub, pet battler, or multiplayer social feature.

## Flutter Change Rules

- Prefer existing project patterns: `Provider`, `MaterialApp` routes, domain folders under `lib/pages/<domain>/`, shared components under `lib/widgets/`, services under `lib/services/`.
- Keep edits small and domain-local. Do not migrate state management, routing, or theming globally unless the task explicitly requires it.
- Use `MoeTokens`, existing Moe widgets, and motion components before adding new visual systems.
- For large pages, extract pure display widgets first. Keep page files responsible for orchestration, navigation, and side effects.
- Avoid adding new packages when Flutter SDK or existing dependencies already cover the need.
- When adding a package, verify `pubspec.yaml`, run `flutter pub get`, then run analysis or targeted tests.

## Quality Bar

- For UI changes, check mobile layout first. Text must not overflow fixed controls.
- For risky flows, add focused tests around parsing, services, or pure widgets instead of broad brittle tests.
- Before finishing Flutter changes, run `flutter analyze --no-fatal-infos` when feasible. Run targeted `flutter test` for changed logic.
- Do not hide errors with blanket catches. Surface user-readable errors through existing toast/snackbar patterns.

## High-Leverage Open Source References

- SillyTavern/TavernAI: copy data-format ideas for character cards, lorebooks, persona, and group chat. Do not copy desktop-first UI.
- Mem0/OpenClaw: use as memory behavior references, especially memory confidence, edit/delete UX, and injection budget.
- flyerhq/flutter_chat_ui: use as a reference for chat component boundaries and message-list UX.
- Immich/Ente Photos: use as references for gallery, upload queue, media preview, and failure retry patterns.
- Sentry/Patrol/golden_toolkit: prefer these for stability, E2E smoke paths, and UI regression checks.
