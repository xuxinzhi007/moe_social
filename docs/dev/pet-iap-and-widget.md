# 养成 P4：内购与桌面小组件

> 日期：2026-08-01 · 状态：占位可体验 · 不阻塞 P0–P3 主线宣称

## 内购

| 项 | 现状 |
|----|------|
| 客户端 | `PetProvider.purchaseIapPlaceholder()`：软通货模拟「去广告礼包」 |
| 后端 | `POST /api/pet/iap/verify` 占位校验（见 protohttp/pet）；真钱收据待商店配置 |
| 依赖 | 封测前接入 `in_app_purchase` + 服务端验签 |

## 桌面小组件

| 平台 | 方案 | 现状 |
|------|------|------|
| Android / iOS | `home_widget` 或平台原生 Widget | **文档占位**：展示 `name / hunger / mood / scene` |
| 数据源 | SharedPreferences `pet_life_sim_profile_v1` 或短轮询 `/api/pet/state` | App 内已持久化 |

实现清单（后续迭代）：

1. 增加 `home_widget` 依赖与 Android/iOS 工程入口  
2. 照料/喂食后 `HomeWidget.saveWidgetData` 同步三条状态  
3. 点击小组件 deep link → `/pet/home`

回滚：关闭 Flag `petLifeSim`；IAP 路由可独立下线。
