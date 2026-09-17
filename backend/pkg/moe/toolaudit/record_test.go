package toolaudit

import (
	"testing"

	"backend/pkg/moe/core"
	"backend/pkg/moe/tools"
)

// TestBuildSchemaItemsCoversAllTools 固化两件事：管理台看到的工具清单必须与注册表逐项对齐，
// 且展示用的 AllowedTiers 必须与真正放行用的 AllowsTool 同源同结果。
//
// 判别力：把 BuildSchemaItems 里那个 `if fn == nil { continue }` 改成无条件跳过首项、
// 或把 AllowedTiers 写成固定档位而不查 AllowsTool，本用例都会失败。
//
// 旧实现写死 `len(items) < 6`，而注册表在 memory_search / memory_get / memory_save 被摘掉后
// 只剩 5 个工具，于是这条用例长期红着。写死的数量阈值注定会随注册表增减而烂掉，改成从
// tools.OpenAISchemaList() 推导。旧实现第 18-20 行那个空 if 块和第 22 行那个丢弃返回值的
// `_ = core.TierS2.AllowsTool(...)` 看起来在断言，实际什么都没断言 —— 一并换成真断言。
func TestBuildSchemaItemsCoversAllTools(t *testing.T) {
	registry := tools.OpenAISchemaList()
	if len(registry) == 0 {
		t.Fatal("前置条件不成立：注册表为空，本用例无从判断覆盖面")
	}
	items := BuildSchemaItems()
	if len(items) != len(registry) {
		t.Fatalf("工具数与注册表不一致：BuildSchemaItems 返回 %d 项，注册表有 %d 项", len(items), len(registry))
	}

	byName := make(map[string]SchemaItem, len(items))
	for _, it := range items {
		if it.Name == "" {
			t.Fatal("存在空工具名，管理台会渲染出一行没有名字的工具")
		}
		if _, dup := byName[it.Name]; dup {
			t.Fatalf("工具名重复出现: %s", it.Name)
		}
		byName[it.Name] = it
	}

	tiers := []core.CapabilityTier{core.TierS0, core.TierS1, core.TierS2, core.TierS3}
	for name, it := range byName {
		if len(it.AllowedTiers) == 0 {
			t.Errorf("工具 %s 没有任何可用档位，管理台会显示成永远不可用", name)
		}
		// s0 的语义就是「什么都不许」，任何工具出现在这一档都意味着档位模型被改坏了。
		if core.TierS0.AllowsTool(name) {
			t.Errorf("s0 应当不允许任何工具，却放行了 %s", name)
		}
		for _, s := range it.AllowedTiers {
			if s == string(core.TierS0) {
				t.Errorf("工具 %s 的 AllowedTiers 含 s0", name)
			}
		}
		// AllowedTiers 是展示层，AllowsTool 是执行层；两者由同一个函数算出来才不会各说各话。
		for _, tier := range tiers {
			want := tier.AllowsTool(name)
			got := false
			for _, s := range it.AllowedTiers {
				if s == string(tier) {
					got = true
					break
				}
			}
			if got != want {
				t.Errorf("%s 在 %s 档不一致：AllowedTiers=%v，AllowsTool=%v", name, tier, got, want)
			}
		}
	}

	// 发帖是写操作，s0/s1 只读档位放行它等于让最低权限的 bot 能发内容。
	// 这条是策略断言而非一致性断言：改档位策略时必须同时改这里，是有意的。
	for _, tier := range []core.CapabilityTier{core.TierS0, core.TierS1} {
		if tier.AllowsTool("post_create") {
			t.Errorf("%s 不得放行 post_create", tier)
		}
	}
	for _, tier := range []core.CapabilityTier{core.TierS2, core.TierS3} {
		if !tier.AllowsTool("post_create") {
			t.Errorf("%s 应当放行 post_create", tier)
		}
	}
}

// TestAllowsToolNeverPermitsUnregisteredTool 钉住「档位放行集合 ⊆ 注册表」这条不变量。
//
// 反向的那一半（注册表里的工具至少有一个档位放行）由上一条用例的
// `len(it.AllowedTiers) == 0` 覆盖；这一半覆盖不到，因为 AllowsTool 是对任意字符串的
// 谓词，没法枚举「它放行了哪些名字」。所以这里显式探测真正发生过分叉的那三个名字：
// 它们曾长期留在 tier.go 的 S1/S2 分支里，而注册表早已摘掉，导致请求先过档位闸、
// 再在 Execute 的 default 分支以「未知工具」失败。
//
// 判别力：把 memory_search 加回 tier.go 的 S1 或 S2 分支，本用例即变红。
// s3 是 `return true`，对任何字符串都放行，属既定语义，不在断言范围内。
func TestAllowsToolNeverPermitsUnregisteredTool(t *testing.T) {
	registered := make(map[string]bool)
	for _, item := range tools.OpenAISchemaList() {
		fn, _ := item["function"].(map[string]any)
		if fn == nil {
			continue
		}
		if name, _ := fn["name"].(string); name != "" {
			registered[name] = true
		}
	}
	if len(registered) == 0 {
		t.Fatal("前置条件不成立：注册表为空，本用例无从判断")
	}

	for _, dead := range []string{"memory_search", "memory_get", "memory_save"} {
		if registered[dead] {
			t.Fatalf("前置条件已变化：%s 重新出现在注册表里，本用例的探测名单需要重挑", dead)
		}
		for _, tier := range []core.CapabilityTier{core.TierS0, core.TierS1, core.TierS2} {
			if tier.AllowsTool(dead) {
				t.Errorf("%s 放行了注册表里不存在的工具 %s", tier, dead)
			}
		}
	}
}
