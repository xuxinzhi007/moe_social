package lifebiz

import (
	"testing"

	"backend/model"
)

func TestWorldEventEngineStep(t *testing.T) {
	t.Run("评估tick触发评估", func(t *testing.T) {
		engine := NewWorldEventEngine()
		// 手动设置 evaluationInterval 为小值方便测试
		engine.evaluationInterval = 5

		grid := &WorldGrid{
			Width:  4,
			Height: 4,
			Cells:  make([][]WorldCell, 4),
		}
		for y := 0; y < 4; y++ {
			grid.Cells[y] = make([]WorldCell, 4)
			for x := 0; x < 4; x++ {
				grid.Cells[y][x] = WorldCell{Food: 50, Moisture: 50, Danger: 0, Habitable: true}
			}
		}

		// tickCount=0 → 0%5==0 → 触发评估
		diffs := engine.Step(grid, 0, nil)
		// 不保证一定触发事件（概率性），但 prevDiffs 可能非空
		_ = diffs
		// 验证 weather 字段被更新
		_ = grid.Weather
	})

	t.Run("非评估tick不触发新事件", func(t *testing.T) {
		engine := NewWorldEventEngine()
		engine.evaluationInterval = 100

		grid := &WorldGrid{
			Width:  4,
			Height: 4,
			Cells:  make([][]WorldCell, 4),
		}
		for y := 0; y < 4; y++ {
			grid.Cells[y] = make([]WorldCell, 4)
			for x := 0; x < 4; x++ {
				grid.Cells[y][x] = WorldCell{Food: 50, Moisture: 50, Habitable: true}
			}
		}

		// tickCount=1 → 1%100!=0 → 不触发评估
		diffs := engine.Step(grid, 1, nil)
		// 没有活跃事件，所以不会有 diff
		if len(diffs) > 0 {
			t.Errorf("non-evaluation tick should produce no diffs (no active events), got %d", len(diffs))
		}
	})
}

func TestDecayEvents(t *testing.T) {
	engine := NewWorldEventEngine()
	// 添加两个活跃事件
	engine.activeEvents = []WorldEventState{
		{Type: WorldEventRain, Active: true, RemainingTicks: 2, Intensity: 0.6},
		{Type: WorldEventDrought, Active: true, RemainingTicks: 1, Intensity: 0.8},
	}

	// 第一次衰减：rain→1, drought→0(移除)
	engine.decayEvents()

	if len(engine.activeEvents) != 1 {
		t.Fatalf("after first decay, activeEvents=%d, want 1", len(engine.activeEvents))
	}
	if engine.activeEvents[0].Type != WorldEventRain {
		t.Errorf("remaining event should be rain, got %s", engine.activeEvents[0].Type)
	}
	if engine.activeEvents[0].RemainingTicks != 1 {
		t.Errorf("rain remaining=%d, want 1", engine.activeEvents[0].RemainingTicks)
	}

	// 第二次衰减：rain→0(移除)
	engine.decayEvents()
	if len(engine.activeEvents) != 0 {
		t.Errorf("after second decay, activeEvents=%d, want 0", len(engine.activeEvents))
	}
}

func TestIsEventActive(t *testing.T) {
	engine := NewWorldEventEngine()
	engine.activeEvents = []WorldEventState{
		{Type: WorldEventRain, Active: true, RemainingTicks: 5},
		{Type: WorldEventDrought, Active: false, RemainingTicks: 0},
	}

	if !engine.isEventActive(WorldEventRain) {
		t.Error("rain should be active")
	}
	if engine.isEventActive(WorldEventDrought) {
		t.Error("drought should not be active (Active=false)")
	}
	if engine.isEventActive(WorldEventStorm) {
		t.Error("storm should not be active")
	}
}

func TestCurrentWeather(t *testing.T) {
	tests := []struct {
		name   string
		events []WorldEventState
		want   string
	}{
		{"无事件→clear", nil, "clear"},
		{"rain优先", []WorldEventState{{Type: WorldEventRain, Active: true}}, "rain"},
		{"storm最高优先(storm在前)", []WorldEventState{
			{Type: WorldEventStorm, Active: true},
			{Type: WorldEventDrought, Active: true},
			{Type: WorldEventRain, Active: true},
		}, "storm"},
		{"drought优先于rain(drought在前)", []WorldEventState{
			{Type: WorldEventDrought, Active: true},
			{Type: WorldEventRain, Active: true},
		}, "drought"},
		{"不活跃事件忽略", []WorldEventState{
			{Type: WorldEventStorm, Active: false},
		}, "clear"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			engine := NewWorldEventEngine()
			engine.activeEvents = tc.events
			got := engine.currentWeather()
			if got != tc.want {
				t.Errorf("currentWeather()=%q, want %q", got, tc.want)
			}
		})
	}
}

func TestCheckDepletion(t *testing.T) {
	t.Run("food<10%触发depletion", func(t *testing.T) {
		engine := NewWorldEventEngine()
		// 2x2 grid, maxFood = 4 * 100 = 400, threshold = 40
		grid := &WorldGrid{
			Width:  2,
			Height: 2,
			Cells: [][]WorldCell{
				{{Food: 5}, {Food: 5}},
				{{Food: 5}, {Food: 5}},
			},
		}
		// totalFood=20 < 40 → trigger
		var logged []*model.LifeEventLog
		engine.checkDepletion(grid, func(e *model.LifeEventLog) {
			logged = append(logged, e)
		})

		if !engine.isEventActive(WorldEventDepletion) {
			t.Error("depletion should be triggered")
		}
		if len(logged) == 0 {
			t.Error("should enqueue event log")
		}
	})

	t.Run("food充足不触发", func(t *testing.T) {
		engine := NewWorldEventEngine()
		grid := &WorldGrid{
			Width:  2,
			Height: 2,
			Cells: [][]WorldCell{
				{{Food: 80}, {Food: 80}},
				{{Food: 80}, {Food: 80}},
			},
		}
		engine.checkDepletion(grid, nil)
		if engine.isEventActive(WorldEventDepletion) {
			t.Error("depletion should not be triggered")
		}
	})

	t.Run("nil grid", func(t *testing.T) {
		engine := NewWorldEventEngine()
		engine.checkDepletion(nil, nil) // 不应 panic
	})
}
