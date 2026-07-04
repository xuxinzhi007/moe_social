package gamebiz

import (
	"context"
	"fmt"
	"hash/fnv"
	"time"

	"backend/internal/platform/moelog"
	"backend/model"
)

const defaultWorldTickInterval = 45 * time.Second

// StartWorldRunner 后台世界时钟：独立于玩家输入，为活跃会话写入 ambient 事件。
func StartWorldRunner(ctx context.Context, st Store, interval time.Duration) {
	if st == nil {
		return
	}
	if interval <= 0 {
		interval = defaultWorldTickInterval
	}
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				tickCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
				if n, err := RunBackgroundWorldTick(tickCtx, st); err != nil {
					moelog.Warnf("game: background world tick: %v", err)
				} else if n > 0 {
					moelog.Infof("game: background world tick emitted %d events", n)
				}
				cancel()
			}
		}
	}()
}

// RunBackgroundWorldTick 为活跃会话生成 ambient 事件并写入 game_world_events。
func RunBackgroundWorldTick(ctx context.Context, st Store) (int, error) {
	if st == nil {
		return 0, nil
	}
	sessions, err := st.ListActiveSessions(ctx, 64)
	if err != nil {
		return 0, err
	}
	emitted := 0
	for _, sess := range sessions {
		if ctx.Err() != nil {
			break
		}
		if ok, err := maybeEmitBackgroundEvent(ctx, st, sess); err != nil {
			moelog.Warnf("game: session %d ambient tick: %v", sess.ID, err)
		} else if ok {
			emitted++
		}
	}
	return emitted, nil
}

func maybeEmitBackgroundEvent(ctx context.Context, st Store, sess model.GameSession) (bool, error) {
	if time.Since(sess.UpdatedAt) > 48*time.Hour {
		return false, nil
	}
	scene, err := st.GetScene(ctx, sess.SceneID)
	if err != nil {
		return false, err
	}
	flags := decodeWorldFlags(sess.FlagsJSON)
	npcs, err := st.ListNpcsByScene(ctx, scene.ID)
	if err != nil {
		return false, err
	}
	// 约 35% 概率产生 ambient 事件，避免刷屏
	if backgroundTickRoll(sess.ID, flags.TurnCount)%100 >= 35 {
		return false, nil
	}
	summary := ambientWorldEvent(scene.Name, flags.WorldMood, npcs)
	if summary == "" {
		return false, nil
	}
	if err := persistWorldEvent(ctx, st, sess.ID, scene.Name, "ambient", summary); err != nil {
		return false, err
	}
	return true, nil
}

func backgroundTickRoll(sessionID uint, turnCount int) uint32 {
	h := fnv.New32a()
	_, _ = h.Write([]byte(time.Now().Format("2006-01-02T15:04")))
	_, _ = h.Write([]byte{byte(sessionID), byte(sessionID >> 8), byte(turnCount)})
	return h.Sum32()
}

func ambientWorldEvent(sceneName, mood string, npcs []model.GameNpc) string {
	_ = mood
	_ = sceneName
	if len(npcs) > 0 {
		return fmt.Sprintf("%s似乎注意到了什么异常", npcs[0].Name)
	}
	return "钟影在雾中微微晃动"
}
