# lib/memory — Flutter 记忆 SDK 骨架

与后端 `backend/pkg/memory` 对齐的客户端模块。现有实现仍在 `lib/services/memory_*.dart`，**逐步迁入本目录**，对外通过 `memory.dart` 统一导出。

## 结构

```
lib/memory/
  memory.dart              # barrel export
  core/memory_record.dart  # 与后端 Record 同形
  core/memory_store.dart   # 抽象 Store（HTTP / 本地 mock）
  client/memory_http_client.dart
```

## 使用（新代码推荐）

```dart
import 'package:moe_social/memory/memory.dart';

final store = MemoryHttpClient();
final items = await store.search(userId, query: '咖啡');
```

旧代码可继续使用 `MemoryService` / `AiMemoryOrchestrator`，行为不变。
