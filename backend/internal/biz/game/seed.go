package gamebiz

import (
	"context"
	"encoding/json"

	"backend/model"
)

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

	npcs := []model.GameNpc{
		{
			SceneID:          scene.ID,
			Name:             "老人",
			Persona:          "坐在广场长椅上的老者，知晓小镇往事，说话时会压低声音。",
			BaseFavorability: 55,
		},
		{
			SceneID:          scene.ID,
			Name:             "酒馆老板",
			Persona:          "旅人酒馆的老板，热情但警惕，对闹事者毫不客气。",
			BaseFavorability: 50,
		},
		{
			SceneID:          scene.ID,
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
