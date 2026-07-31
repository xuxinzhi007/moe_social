# Gift Lottie templates

按 `GiftLevel` 分档，**不按 SKU**。设计师可用正式 JSON **同名覆盖**，代码零改。

| 文件 | 档位 | 目标时长 |
|------|------|----------|
| `gift_burst_basic.json` | basic | ~1.5s |
| `gift_burst_medium.json` | medium | ~2.0s |
| `gift_burst_advanced.json` | advanced | ~2.5s |
| `gift_burst_luxury.json` | luxury | ~3.5s |

- 画布 400×400，中心约 160×160 留白（业务文案由 Flutter 叠）
- 粒子偏中性金/白，运行时 `ColorFiltered` 染 `gift.color`
- 单文件建议 ≤200KB；重新生成：`dart run scripts/gen_gift_lottie.dart`
- SSOT：`docs/dev/lottie-achievement-gift-design.md`
