# Spine 角色资源（C 方案）

见 `docs/dev/pet-spine-avatar.md`。

放置导出物（示例名）：

- `moe_pet.atlas`
- `moe_pet.skel`（或 `.json`）
- 对应 `.png` 图集页

未放入有效骨骼前，`FeatureFlags.petSpineAvatar` 即使为 true 也会回退 PNG。
