package lifebiz

import (
	"testing"

	"backend/model"
)

func TestNewWorldGrid(t *testing.T) {
	cfg := DefaultConfig()
	grid := newWorldGrid(cfg)

	if grid.Width != 32 {
		t.Errorf("grid width=%d, want 32", grid.Width)
	}
	if grid.Height != 18 {
		t.Errorf("grid height=%d, want 18", grid.Height)
	}
	if len(grid.Cells) != 18 {
		t.Fatalf("cells rows=%d, want 18", len(grid.Cells))
	}
	if len(grid.Cells[0]) != 32 {
		t.Fatalf("cells cols=%d, want 32", len(grid.Cells[0]))
	}

	// 检查所有单元格值在合理范围
	for y := 0; y < grid.Height; y++ {
		for x := 0; x < grid.Width; x++ {
			cell := grid.Cells[y][x]
			if cell.Food < 0 || cell.Food > maxCellFood {
				t.Errorf("cell[%d][%d] food=%.2f out of range", y, x, cell.Food)
			}
			if cell.Moisture < 20 || cell.Moisture > 100 {
				t.Errorf("cell[%d][%d] moisture=%.2f out of range", y, x, cell.Moisture)
			}
			if cell.Danger < 0 || cell.Danger > 100 {
				t.Errorf("cell[%d][%d] danger=%.2f out of range", y, x, cell.Danger)
			}
		}
	}
}

func TestWorldCellForEntity(t *testing.T) {
	grid := &WorldGrid{
		Width:  32,
		Height: 18,
		Cells:  make([][]WorldCell, 18),
	}
	for y := 0; y < 18; y++ {
		grid.Cells[y] = make([]WorldCell, 32)
	}

	tests := []struct {
		name    string
		posX    float64
		posY    float64
		wantX   int
		wantY   int
	}{
		{"原点", 0, 0, 0, 0},
		{"最大值", 1280, 720, 31, 17},
		{"中间", 640, 360, 16, 9},
		{"超出上界", 2000, 2000, 31, 17},
		{"负数坐标", -100, -100, 0, 0},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			e := &model.LifeEntity{PositionX: tc.posX, PositionY: tc.posY}
			x, y := worldCellForEntity(grid, e)
			if x != tc.wantX || y != tc.wantY {
				t.Errorf("worldCellForEntity(%.0f,%.0f)=(%d,%d), want (%d,%d)",
					tc.posX, tc.posY, x, y, tc.wantX, tc.wantY)
			}
		})
	}

	// nil grid
	t.Run("nil grid", func(t *testing.T) {
		e := &model.LifeEntity{PositionX: 100, PositionY: 100}
		x, y := worldCellForEntity(nil, e)
		if x != 0 || y != 0 {
			t.Errorf("nil grid should return (0,0), got (%d,%d)", x, y)
		}
	})
}

func TestComputeWorldSummary(t *testing.T) {
	t.Run("空实体列表", func(t *testing.T) {
		grid := &WorldGrid{
			Width:  2,
			Height: 2,
			Cells: [][]WorldCell{
				{{Food: 10, Habitable: true, Danger: 0}, {Food: 20, Habitable: true, Danger: 0}},
				{{Food: 30, Habitable: false, Danger: 30}, {Food: 40, Habitable: true, Danger: 5}},
			},
		}
		entities := map[uint]*model.LifeEntity{}
		s := computeWorldSummary(grid, entities, 0, 0)
		if s.EntityCount != 0 {
			t.Errorf("entity_count=%d, want 0", s.EntityCount)
		}
		if s.TotalFood != 100 {
			t.Errorf("total_food=%.1f, want 100", s.TotalFood)
		}
		if s.HabitableCells != 3 {
			t.Errorf("habitable_cells=%d, want 3", s.HabitableCells)
		}
		if s.DangerCells != 1 {
			t.Errorf("danger_cells=%d, want 1", s.DangerCells)
		}
	})

	t.Run("多实体", func(t *testing.T) {
		grid := &WorldGrid{Width: 1, Height: 1, Cells: [][]WorldCell{{{Food: 50, Habitable: true}}}}
		entities := map[uint]*model.LifeEntity{
			1: {Hunger: 60, Energy: 70, Mood: 80},
			2: {Hunger: 40, Energy: 50, Mood: 60},
		}
		s := computeWorldSummary(grid, entities, 2, 1)
		if s.EntityCount != 2 {
			t.Errorf("entity_count=%d, want 2", s.EntityCount)
		}
		if s.AliveCount != 2 {
			t.Errorf("alive_count=%d, want 2", s.AliveCount)
		}
		if s.AvgHunger != 50 {
			t.Errorf("avg_hunger=%.1f, want 50", s.AvgHunger)
		}
		if s.AvgEnergy != 60 {
			t.Errorf("avg_energy=%.1f, want 60", s.AvgEnergy)
		}
		if s.BirthCount != 2 || s.DeathCount != 1 {
			t.Errorf("birth=%d death=%d", s.BirthCount, s.DeathCount)
		}
	})

	t.Run("nil网格", func(t *testing.T) {
		entities := map[uint]*model.LifeEntity{1: {Hunger: 50, Energy: 50, Mood: 50}}
		s := computeWorldSummary(nil, entities, 0, 0)
		if s.TotalFood != 0 {
			t.Errorf("nil grid total_food=%.1f, want 0", s.TotalFood)
		}
		if s.AliveCount != 1 {
			t.Errorf("alive_count=%d, want 1", s.AliveCount)
		}
	})
}

func TestMaybeSpawnOffspring(t *testing.T) {
	t.Run("阶段不对→不繁殖", func(t *testing.T) {
		parent := &model.LifeEntity{
			GrowthStage: StageJuvenile, Energy: 90, Hunger: 90, Mood: 90,
		}
		entities := map[uint]*model.LifeEntity{1: parent}
		got := maybeSpawnOffspring("w", entities, parent, 2, nil)
		if got != nil {
			t.Errorf("juvenile should not spawn, got non-nil")
		}
	})

	t.Run("能量不足→不繁殖", func(t *testing.T) {
		parent := &model.LifeEntity{
			GrowthStage: StageAdult, Energy: 50, Hunger: 90, Mood: 90,
		}
		entities := map[uint]*model.LifeEntity{1: parent}
		got := maybeSpawnOffspring("w", entities, parent, 2, nil)
		if got != nil {
			t.Errorf("low energy should not spawn, got non-nil")
		}
	})

	t.Run("达到上限→不繁殖", func(t *testing.T) {
		parent := &model.LifeEntity{
			GrowthStage: StageAdult, Energy: 90, Hunger: 90, Mood: 90,
		}
		entities := make(map[uint]*model.LifeEntity)
		for i := uint(0); i < 50; i++ {
			entities[i] = &model.LifeEntity{ID: i}
		}
		got := maybeSpawnOffspring("w", entities, parent, 100, nil)
		if got != nil {
			t.Errorf("at capacity should not spawn, got non-nil")
		}
	})

	t.Run("nil parent", func(t *testing.T) {
		got := maybeSpawnOffspring("w", nil, nil, 2, nil)
		if got != nil {
			t.Errorf("nil parent should return nil")
		}
	})

	t.Run("有mate→繁殖概率提高", func(t *testing.T) {
		// 基础概率 0.025，有 mate 翻倍 0.05
		// 多次运行验证：有 mate 时至少能成功几次
		spawnCount := 0
		for i := 0; i < 500; i++ {
			parent := &model.LifeEntity{
				ID: 1, GrowthStage: StageAdult, Energy: 90, Hunger: 90, Mood: 90,
			}
			entities := map[uint]*model.LifeEntity{1: parent}
			rels := []*model.LifeRelationship{
				{EntityID: 1, TargetID: 2, RelationType: RelMate},
			}
			got := maybeSpawnOffspring("w", entities, parent, 2, rels)
			if got != nil {
				spawnCount++
			}
		}
		// 期望约 25 次（500*0.05），至少要 > 5
		if spawnCount < 5 {
			t.Errorf("with mate expected >5 spawns in 500 runs, got %d", spawnCount)
		}
	})
}
