# Moe Flutter · Product reference

## Add / modify / delete

### Add

| Add | When |
|-----|------|
| `*_viewmodel.dart` | New screen or extracting state from a god-page |
| Domain method on existing `*Service` | Page needs API/upload/LLM that isn't wrapped yet |
| New `*Service` | New backend domain with ≥3 call sites; else extend closest service |
| Widget under `widgets/` or `pages/<domain>/widgets/` | Reused UI or page file getting fat |
| `FeatureFlags` + gate | Experimental / P2 surface |
| Focused unit test | Parsing, VM pagination, error mapping |

### Modify

| Modify | How |
|--------|-----|
| Giant `StatefulWidget` | Slice out VM for the touched flow; leave unrelated `setState` for later |
| Magic colors on main path | Replace with `MoeTokens` when touching the file |
| Ad-hoc empty/error | Swap to `MoeEmptyState` / `MoeErrorState` |
| Direct `ApiClient` in page | Move to domain service |
| Nav to experimental | Hide behind flag or remove |

### Delete or isolate

| Target | Action |
|--------|--------|
| `lib/pages/_archived/**` | Out of routes; do not revive without ask |
| Debug/test pages in release nav | Remove or `kDebugMode` only |
| Gacha / game when flags false | No UI affordance |
| AutoGLM | Only `FeatureFlags.showAutoGlm` |
| Duplicate empty-state widgets | Prefer shared moe_* |

**Do not delete** without ask: Companion core, Life (when `showLifeEngine`), cloud gallery (P1), Provider stack, deferred routing.

---

## Layering

```text
Page (UI + nav)
  → ViewModel / Provider
    → Domain *Service
      → ApiClient / ApiService
```

---

## Surfaces

**P0:** login/register, home feed, create/edit post, comments, message center, conversations, direct chat, profile basics, settings entry.

**P1:** companion hub, life world, gallery, check-in, achievements, community, commerce.

**Experimental:** AutoGLM, gacha, game features, local model settings.

**Ship vs architecture:** Architecture OK on a path ≠ ship-ready. 现阶段：API 基址用 `isProduction` 手动切；第三方密钥用 `AppConfig` 安全存储，不上仓。上线前再切生产 URL/HTTPS。God pages on P1 are debt — slice only when touching.

**P0 loop checklist (success-app bar):**
- Feed: skeleton + retry
- Create post: `MoeErrorCopy` on upload/publish + SharedPreferences draft
- Comments: optimistic insert + rollback toast
- DM: unread + WS reconnect + visible send/disconnect failure
- Auth: `MoeErrorCopy` for transport errors; no keys in repo
- Flags: route guards when flag false
- Observability: `CrashReportBuffer` for uncaught errors


---

## ViewModel checklist

- `ChangeNotifier` + `_disposed` on async
- Getters + methods; prefer no `BuildContext`
- Errors for UI → `MoeErrorCopy`
- Pagination: `loadMore` / `hasMore` / in-flight guards

---

## Anti-patterns

- New bottom tab for non-P0 idea
- Silent `catch (_) {}` on main path
- Copy-paste 800-line page scaffold
- Second design token file
- Growing `ApiService` with page one-offs instead of domain methods
- External placeholder avatars (`picsum` etc.) — use `''` and local UI placeholder
- Extracting a ViewModel for a form with only 1–2 fields and no async list state
