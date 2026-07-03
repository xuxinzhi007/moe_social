package gamebiz

import (
	"context"
	"encoding/json"
	"log/slog"

	"backend/model"
)

// DialogueRule NPC 对话规则：当玩家输入包含任一 keyword 时，返回对应 response。
type DialogueRule struct {
	Keywords []string `json:"keywords"`
	Response string   `json:"response"`
}

// FallbackResponses NPC 兜底对话模板。
// Default: 无规则命中时的回复，可用占位符 {action}、{npc}。
// Opening: 开场白模板，可用占位符 {target}、{npc}。
type FallbackResponses struct {
	Default string `json:"default"`
	Opening string `json:"opening"`
}

// seedNpcTemplates 首次运行时写入 DB 的种子 NPC 模板数据。
var seedNpcTemplates = []model.GameNpcTemplate{
	{
		NpcKey:           "old_man",
		DisplayName:      "老人",
		Persona:          "坐在广场长椅上的老者，知晓小镇往事，说话时会压低声音。",
		BaseFavorability: 55,
		SceneAffinity:    "迷雾小镇",
		DialogueRulesJSON: mustMarshalJSON([]DialogueRule{
			{
				Keywords: []string{"追问", "继续"},
				Response: "老人把烟斗在指间转了一圈，目光再次落在你身上：「你想知道什么？钟的事，还是雾的事？问吧。」",
			},
			{
				Keywords: []string{"多大", "几岁", "年龄"},
				Response: "老人愣了一下，随即笑出声来，笑声在晨雾里有些发闷：「老了……七十三啦。这镇子的事，我比钟楼还清楚。」",
			},
			{
				Keywords: []string{"没有", "不"},
				Response: "老人把烟斗在膝上轻敲两下：「没有？……那你站在这里，是在等雾散，还是在等钟响？」",
			},
			{
				Keywords: []string{"钟"},
				Response: "老人眼神一暗，声音几乎只剩气音：「那座钟……午夜会响十三下。多出来的那一响，是给谁听的，从来没人说清。」",
			},
		}),
		FallbackResponsesJSON: mustMarshalJSON(FallbackResponses{
			Default: "老人听着你说「{action}」，沉默片刻后缓缓开口：「……嗯。还有什么想问的？」",
			Opening: "你走向{target}，对方从手头的事里抬起头。空气里有一瞬的停顿，随后{target}开口了：「……你找我有事？」",
		}),
		IsActive: true,
	},
	{
		NpcKey:           "tavern_owner",
		DisplayName:      "酒馆老板",
		Persona:          "旅人酒馆的老板，热情但警惕，对闹事者毫不客气。",
		BaseFavorability: 50,
		SceneAffinity:    "迷雾小镇",
		DialogueRulesJSON: mustMarshalJSON([]DialogueRule{
			{
				Keywords: []string{"追问", "继续"},
				Response: "老板放下杯子，身子微微前倾：「还想打听？先坐下。这镇子的事，不是三两句能说完的。」",
			},
			{
				Keywords: []string{"多大", "几岁"},
				Response: "老板哼了一声：「问年龄？干我们这行的，年龄写在脸上，也写在酒里。你更该问这镇子最近不太平。」",
			},
		}),
		FallbackResponsesJSON: mustMarshalJSON(FallbackResponses{
			Default: "老板看了你一眼：「{action}？……行，先坐下说。」",
			Opening: "你走向{target}，对方从手头的事里抬起头。空气里有一瞬的停顿，随后{target}开口了：「……你找我有事？」",
		}),
		IsActive: true,
	},
	{
		NpcKey:           "beggar",
		DisplayName:      "乞丐",
		Persona:          "蜷缩在角落的乞丐，观察力敏锐，记住每个对他好或坏的人。",
		BaseFavorability: 45,
		SceneAffinity:    "迷雾小镇",
		DialogueRulesJSON: mustMarshalJSON([]DialogueRule{
			{
				Keywords: []string{"追问", "继续"},
				Response: "乞丐抬起头，浑浊的眼里闪过一丝精光：「你还想听？……哼，说吧，你想问什么。」",
			},
		}),
		FallbackResponsesJSON: mustMarshalJSON(FallbackResponses{
			Default: "乞丐缩了缩脖子，嘟囔道：「{action}……你倒是比其他人有意思。」",
			Opening: "你走向{target}，对方从手头的事里抬起头。空气里有一瞬的停顿，随后{target}开口了：「……你找我有事？」",
		}),
		IsActive: true,
	},
}

func mustMarshalJSON(v interface{}) string {
	b, err := json.Marshal(v)
	if err != nil {
		return "[]"
	}
	return string(b)
}

// EnsureSeedWorld 确保种子世界存在。优先从 DB 模板初始化 NPC，
// 若 DB 无模板数据则将硬编码种子写入 DB（首次运行自动初始化）。
func EnsureSeedWorld(ctx context.Context, st Store) error {
	if st == nil {
		return nil
	}
	st = st.WithContext(ctx)
	n, err := st.CountSeedScenes(ctx)
	if err != nil {
		return err
	}
	if n > 0 {
		return nil
	}

	exits, _ := json.Marshal([]string{"东边：旅人酒馆", "南边：古老教堂", "西边：森林小路", "北边：早市"})
	scene := &model.GameScene{
		Name:        seedSceneName,
		Description: "晨雾中的小镇广场，中央有一座古老钟楼。镇民稀少，却似乎藏着秘密。",
		ExitsJSON:   string(exits),
		IsSeed:      true,
	}
	if err := st.CreateScene(ctx, scene); err != nil {
		return err
	}

	// 尝试从 DB 加载 NPC 模板
	templates, tplErr := st.ListNpcTemplates(ctx, true)
	if tplErr != nil {
		slog.Warn("[seed] 查询 NPC 模板失败，回退硬编码种子", "err", tplErr)
	}

	if len(templates) == 0 {
		// DB 无模板：将硬编码种子写入 DB，再用硬编码创建 NPC
		if tplErr == nil {
			for i := range seedNpcTemplates {
				if err := st.UpsertNpcTemplate(ctx, &seedNpcTemplates[i]); err != nil {
					slog.Warn("[seed] 写入 NPC 模板失败", "npc_key", seedNpcTemplates[i].NpcKey, "err", err)
				}
			}
		}
		return createSeedNpcsFromHardcode(ctx, st, scene.ID)
	}

	// 使用 DB 模板创建 NPC
	for _, tpl := range templates {
		npc := model.GameNpc{
			SceneID:          scene.ID,
			Name:             tpl.DisplayName,
			Persona:          tpl.Persona,
			BaseFavorability: tpl.BaseFavorability,
		}
		if err := st.CreateNpc(ctx, &npc); err != nil {
			return err
		}
	}
	return nil
}

// createSeedNpcsFromHardcode 硬编码兜底：直接用固定数据创建种子 NPC。
func createSeedNpcsFromHardcode(ctx context.Context, st Store, sceneID uint) error {
	npcs := []model.GameNpc{
		{
			SceneID:          sceneID,
			Name:             "老人",
			Persona:          "坐在广场长椅上的老者，知晓小镇往事，说话时会压低声音。",
			BaseFavorability: 55,
		},
		{
			SceneID:          sceneID,
			Name:             "酒馆老板",
			Persona:          "旅人酒馆的老板，热情但警惕，对闹事者毫不客气。",
			BaseFavorability: 50,
		},
		{
			SceneID:          sceneID,
			Name:             "乞丐",
			Persona:          "蜷缩在角落的乞丐，观察力敏锐，记住每个对他好或坏的人。",
			BaseFavorability: 45,
		},
	}
	for i := range npcs {
		if err := st.CreateNpc(ctx, &npcs[i]); err != nil {
			return err
		}
	}
	return nil
}
