# 读屏回复参谋 — 市场与产品方案（2026-11-05）

> 路径 **B**：Android 侧载/内测实验通道；主包可继续走商店，读屏能力不绑 Play 上架。  
> 完整方案以本仓库文档为准：产品侧见本文，技术评估见 [docs/specs/reply-assist-tech-eval-2026-11-05.md](../specs/reply-assist-tech-eval-2026-11-05.md)。  
> 贴纸桌宠悬浮层 UX：[reply-assist-pet-overlay-ux-2026-11-05.md](./reply-assist-pet-overlay-ux-2026-11-05.md)；补丁技术评估：[../specs/reply-assist-overlay-pet-tech-eval-2026-11-05.md](../specs/reply-assist-overlay-pet-tech-eval-2026-11-05.md)。

## 问题

用户在外部聊天 App（典型：微信）卡壳时，需要「此刻屏幕上这句话该不该回、怎么回」，而不是回到 Moe 里长聊。Companion 解决 App 内陪伴；**回复参谋**解决 App 外救场。

## 定位

| 维度 | Companion | 回复参谋 |
|------|-----------|----------|
| 场景 | Moe 内陪聊 | 微信等外部聊天页 |
| 输入 | 用户主动对话 | 点按读屏 / 粘贴 / 截图 |
| 输出 | 陪伴回复 | 判断摘要 + 3 条草稿 |
| 发送 | 在 Moe 内 | **只复制，用户自行发送** |

气质对齐 **安心表达**（If-Reply / JevGuide），明确不做 Rizz/PUA/「恋爱军师」。

## 市场结论（有条件 Go）

- 截图类军师已有付费与规模；读屏类有 Wingyy 商业化与 JevGuide 开源验证。
- 差异化：**判断先行 + 三条可选姿态 + 隐私默认（点按才读、白名单、短 TTL）**，而非更多油腻话术。
- 当前产品规模为个人/小圈（2–3 人），适合路径 B 先验证采纳率。

## 路径 B 产品要点

1. **Android**：贴纸桌宠悬浮层 + 无障碍，包名白名单（MVP：微信 `com.tencent.mm`），用户点按小脸才读一次可见对话；当场出 3 条可复制气泡。
2. **iOS / 降级**：同一结果面板，粘贴或相册/相机截图；不承诺系统级读屏。
3. **输出**：意图/情绪/要不要回 + 稳妥·推进·轻松 三条；一键复制。
4. **硬禁**：代发、后台连续偷读、全机无白名单读屏、PUA 语料。

## MVP 验收（本 PR 骨架）

- Flutter：入口 + 结果面板 + 粘贴/图片输入链路。
- 后端：`POST /api/reply-assist/suggest`（独立 API，不写入 Companion 会话）。
- Android：只读 `ReplyAssistAccessibilityService` + **贴纸桌宠悬浮层**（可拖、点开/收回）；Manifest 已注册；**无** performTap/performType 发送路径。

## 相关文档

- 技术评估：[../specs/reply-assist-tech-eval-2026-11-05.md](../specs/reply-assist-tech-eval-2026-11-05.md)
- 桌宠 UX：[reply-assist-pet-overlay-ux-2026-11-05.md](./reply-assist-pet-overlay-ux-2026-11-05.md)
- 桌宠技术补丁：[../specs/reply-assist-overlay-pet-tech-eval-2026-11-05.md](../specs/reply-assist-overlay-pet-tech-eval-2026-11-05.md)
- 冗余 UX 收口（权限漏斗 / 旧社区浮标退役）：[redundant-ux-cleanup-design-2026-11-05.md](./redundant-ux-cleanup-design-2026-11-05.md)
- 产品索引：[README.md](./README.md)
