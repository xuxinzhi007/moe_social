# 虚拟角色 MVP（Flutter + Rive）

当前已落地：

- 全局悬浮角色容器：`lib/widgets/floating_virtual_avatar_host.dart`
- 已接入应用根层：`lib/main.dart`（登录后显示）
- 支持能力：
  - 悬浮显示、拖拽、自动吸边
  - 长按菜单：本次会话隐藏 / 隐藏到今天结束 / 进入设置
  - 未读消息角标联动（来自 `NotificationProvider`）
  - 点击弹出助手面板（按用户自定义快捷功能展示）
  - 设置页主开关（默认关闭）与独立设置页面

## Rive 资源接入

当前组件会优先尝试加载：

- `assets/avatars/moe_assistant.riv`

如果该文件不存在，会自动降级为内置机器人图标，不影响功能。

### 一次性导入步骤（拿到资源后直接做）

1. 把资源文件放到：`assets/avatars/moe_assistant.riv`
2. 文件名保持一致（当前代码默认读取这个固定文件名）
3. `pubspec.yaml` 已包含 `assets/`，不需要额外再配子目录
4. 执行：
   - `flutter pub get`
   - 热重启（不是仅 Hot Reload）
5. 进入 App（登录后）查看右下悬浮角色是否替换成功

### 想换文件名怎么办

如果你拿到的文件名不是 `moe_assistant.riv`，有两种方式：

- 推荐：重命名为 `moe_assistant.riv`
- 或改代码常量：`lib/widgets/floating_virtual_avatar_host.dart` 里的 `_assetPath`

## 资源验收清单（导入前）

- 文件后缀必须是 `.riv`
- 资源在编辑器内可正常预览
- 默认动画可自动播放（不依赖外部触发）
- 角色主体在画布中居中，不要超出边界
- 导出后体积尽量控制（建议先小于 2~4 MB）

## 推荐制作规范（v1）

- 画板尺寸建议：`512x512`
- 默认循环动画：Idle（待机）
- 导出前确认首屏可直接播放（无需额外触发）
- 建议角色朝向和手势在小尺寸下也清晰（当前悬浮尺寸约 74x74）

## 常见问题排查

- 仍显示机器人占位图标：
  - 检查路径是否为 `assets/avatars/moe_assistant.riv`
  - 检查是否做了热重启
  - 检查文件是否损坏（在 Rive 编辑器能否打开）

- 导入后显示异常（拉伸/裁切）：
  - 优先在 Rive 里调整画布和角色边界
  - 当前 Flutter 端使用 `Fit.cover`，建议角色主体留出安全边距

## 下一步（v2 可选）

- 增加状态机输入（如 unread / speaking / greeting）
- 将不同业务事件映射到动作（签到成功、消息到达、升级）
- 支持多角色皮肤切换与远程配置
