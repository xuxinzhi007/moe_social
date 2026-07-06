package lifebiz

import (
	"math"
	"math/rand"

	"backend/model"
)

const (
	worldWidth  = 1280.0
	worldHeight = 720.0
	maxCellFood = 100.0
)

func newWorldGrid(cfg LifeConfig) *WorldGrid {
	width := cfg.GridWidth
	if width <= 0 {
		width = 32
	}
	height := cfg.GridHeight
	if height <= 0 {
		height = 18
	}

	cells := make([][]WorldCell, height)
	for y := 0; y < height; y++ {
		row := make([]WorldCell, width)
		for x := 0; x < width; x++ {
			foodBias := rand.Float64() * 100
			moisture := 20 + rand.Float64()*80
			danger := rand.Float64() * 35
			terrain := "grass"
			habitable := true

			if moisture < 28 {
				terrain = "dry"
			}
			if moisture > 78 {
				terrain = "wetland"
			}
			if danger > 26 {
				terrain = "hazard"
				habitable = false
			}

			row[x] = WorldCell{
				Terrain:   terrain,
				Food:      foodBias,
				Moisture:  moisture,
				Danger:    danger,
				Habitable: habitable,
			}
		}
		cells[y] = row
	}

	return &WorldGrid{
		Width:  width,
		Height: height,
		Cells:  cells,
	}
}

func worldCellForEntity(grid *WorldGrid, entity *model.LifeEntity) (int, int) {
	if grid == nil || grid.Width <= 0 || grid.Height <= 0 {
		return 0, 0
	}
	x := int(math.Floor((entity.PositionX / worldWidth) * float64(grid.Width)))
	y := int(math.Floor((entity.PositionY / worldHeight) * float64(grid.Height)))
	if x < 0 {
		x = 0
	}
	if y < 0 {
		y = 0
	}
	if x >= grid.Width {
		x = grid.Width - 1
	}
	if y >= grid.Height {
		y = grid.Height - 1
	}
	return x, y
}

func updateWorldEcology(grid *WorldGrid) {
	if grid == nil {
		return
	}
	for y := 0; y < grid.Height; y++ {
		for x := 0; x < grid.Width; x++ {
			cell := &grid.Cells[y][x]
			regen := 0.25 + (cell.Moisture / 100.0 * 0.45)
			if cell.Habitable {
				cell.Food = clamp(cell.Food+regen, 0, maxCellFood)
			} else {
				cell.Food = clamp(cell.Food-0.2, 0, maxCellFood)
			}

			if rand.Float64() < 0.05 {
				cell.Danger = clamp(cell.Danger+(rand.Float64()-0.5)*4, 0, 100)
				cell.Habitable = cell.Danger < 28
				if !cell.Habitable {
					cell.Terrain = "hazard"
				} else if cell.Moisture > 78 {
					cell.Terrain = "wetland"
				} else if cell.Moisture < 28 {
					cell.Terrain = "dry"
				} else {
					cell.Terrain = "grass"
				}
			}
		}
	}
}

func computeWorldSummary(grid *WorldGrid, entities map[uint]*model.LifeEntity, birthCount, deathCount int) WorldSummary {
	summary := WorldSummary{
		EntityCount: len(entities),
		BirthCount:  birthCount,
		DeathCount:  deathCount,
	}
	if grid != nil {
		for y := 0; y < grid.Height; y++ {
			for x := 0; x < grid.Width; x++ {
				cell := grid.Cells[y][x]
				summary.TotalFood += cell.Food
				if cell.Habitable {
					summary.HabitableCells++
				}
				if cell.Danger >= 28 {
					summary.DangerCells++
				}
			}
		}
	}

	if len(entities) == 0 {
		return summary
	}

	for _, entity := range entities {
		if entity == nil {
			continue
		}
		summary.AliveCount++
		summary.AvgHunger += entity.Hunger
		summary.AvgEnergy += entity.Energy
		summary.AvgMood += entity.Mood
	}

	denominator := float64(summary.AliveCount)
	if denominator > 0 {
		summary.AvgHunger /= denominator
		summary.AvgEnergy /= denominator
		summary.AvgMood /= denominator
	}
	return summary
}

func maybeSpawnOffspring(worldID string, entities map[uint]*model.LifeEntity, parent *model.LifeEntity, nextID uint) *model.LifeEntity {
	if parent == nil {
		return nil
	}
	if len(entities) >= 50 {
		return nil
	}
	if parent.Energy < 72 || parent.Hunger < 68 || parent.Mood < 74 {
		return nil
	}
	if rand.Float64() > 0.025 {
		return nil
	}

	parent.Energy = clamp(parent.Energy-18, 0, 100)
	parent.Hunger = clamp(parent.Hunger-14, 0, 100)
	parent.Mood = clamp(parent.Mood+4, 0, 100)
	parent.CurrentAction = string(ActionReproducing)

	return &model.LifeEntity{
		ID:            nextID,
		WorldID:       worldID,
		Name:          parent.Name + "·芽",
		Emoji:         parent.Emoji,
		Hunger:        clamp(parent.Hunger-6, 35, 85),
		Energy:        clamp(parent.Energy-4, 38, 88),
		Mood:          clamp(parent.Mood, 40, 90),
		CurrentAction: string(ActionIdle),
		PositionX:     clamp(parent.PositionX+(rand.Float64()-0.5)*60, 0, worldWidth),
		PositionY:     clamp(parent.PositionY+(rand.Float64()-0.5)*60, 0, worldHeight),
		LastActionAt:  parent.LastActionAt,
		UpdatedAt:     parent.UpdatedAt,
		CreatedAt:     parent.CreatedAt,
	}
}
