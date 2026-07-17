package lifebiz

import (
	"math"
	"math/rand"
	"time"

	"backend/model"
)

// WorldEventEngine 世界事件引擎
type WorldEventEngine struct {
	evaluationInterval int // 每 N tick 评估一次（默认 60 = 5 分钟）
	stormInterval      int // 灾害评估间隔（默认 120）
	activeEvents       []WorldEventState
	rng                *rand.Rand
	prevDiffs          []WorldEventDiff // 用于追踪新触发事件
}

// NewWorldEventEngine 创建世界事件引擎
func NewWorldEventEngine() *WorldEventEngine {
	return &WorldEventEngine{
		evaluationInterval: 60,
		stormInterval:      120,
		rng:                rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

// Step 每 tick 调用：处理活跃事件衰减 + 定期评估新事件
func (e *WorldEventEngine) Step(grid *WorldGrid, tickCount int, enqueueEvent func(*model.LifeEventLog)) []WorldEventDiff {
	e.prevDiffs = nil

	// 1. 衰减活跃事件
	e.decayEvents()

	// 2. 定期评估新事件
	if tickCount%e.evaluationInterval == 0 {
		e.evaluate(grid, tickCount, enqueueEvent)
	}

	// 3. 资源枯竭自动检测
	e.checkDepletion(grid, enqueueEvent)

	// 4. 应用效果到网格
	e.applyEffects(grid)

	// 5. 更新网格天气状态
	grid.Weather = e.currentWeather()

	// 6. 构建广播 diffs
	return e.buildDiffs()
}

// decayEvents 逐 tick 衰减活跃事件
func (e *WorldEventEngine) decayEvents() {
	remaining := e.activeEvents[:0]
	for i := range e.activeEvents {
		evt := &e.activeEvents[i]
		if !evt.Active {
			continue
		}
		evt.RemainingTicks--
		if evt.RemainingTicks <= 0 {
			evt.Active = false
			// 发送结束事件
			e.prevDiffs = append(e.prevDiffs, WorldEventDiff{
				Type:      string(evt.Type),
				Active:    false,
				Intensity: 0,
				Message:   e.endMessage(evt.Type),
			})
			continue
		}
		remaining = append(remaining, *evt)
	}
	e.activeEvents = remaining
}

// evaluate 定期评估是否触发新事件
func (e *WorldEventEngine) evaluate(grid *WorldGrid, tickCount int, enqueueEvent func(*model.LifeEventLog)) {
	// rain：30% 概率，持续 12 tick
	if !e.isEventActive(WorldEventRain) {
		if e.rng.Float64() < 0.30 {
			e.triggerEvent(WorldEventRain, 12, 0.6, grid, enqueueEvent)
		}
	}

	// drought：5% 概率，持续 60 tick
	if !e.isEventActive(WorldEventDrought) {
		if e.rng.Float64() < 0.05 {
			e.triggerEvent(WorldEventDrought, 60, 0.8, grid, enqueueEvent)
		}
	}

	// storm：每 120 tick 评估，3% 概率，持续 6 tick，影响随机 3×3 区域
	if tickCount%e.stormInterval == 0 && !e.isEventActive(WorldEventStorm) {
		if e.rng.Float64() < 0.03 {
			e.triggerStorm(grid, enqueueEvent)
		}
	}

	// 热浪：8% 概率，持续 20 tick
	if !e.isEventActive(WorldEventHeatwave) {
		if e.rng.Float64() < 0.08 {
			e.triggerEvent(WorldEventHeatwave, 20, 0.6, grid, enqueueEvent)
		}
	}

	// 大雾：12% 概率，持续 8 tick
	if !e.isEventActive(WorldEventFog) {
		if e.rng.Float64() < 0.12 {
			e.triggerEvent(WorldEventFog, 8, 0.5, grid, enqueueEvent)
		}
	}

	// 资源丰饶：5% 概率，持续 40 tick
	if !e.isEventActive(WorldEventAbundance) {
		if e.rng.Float64() < 0.05 {
			e.triggerEvent(WorldEventAbundance, 40, 0.7, grid, enqueueEvent)
		}
	}

	// 迁徙潮：3% 概率，持续 15 tick
	if !e.isEventActive(WorldEventMigration) {
		if e.rng.Float64() < 0.03 {
			e.triggerEvent(WorldEventMigration, 15, 0.5, grid, enqueueEvent)
		}
	}
}

// checkDepletion 检测资源枯竭：totalFood < 10% maxFood 时自动触发
func (e *WorldEventEngine) checkDepletion(grid *WorldGrid, enqueueEvent func(*model.LifeEventLog)) {
	if grid == nil {
		return
	}
	totalFood := 0.0
	maxFood := float64(grid.Width * grid.Height) * maxCellFood
	for y := 0; y < grid.Height; y++ {
		for x := 0; x < grid.Width; x++ {
			totalFood += grid.Cells[y][x].Food
		}
	}

	threshold := maxFood * 0.10
	if totalFood < threshold && !e.isEventActive(WorldEventDepletion) {
		e.triggerEvent(WorldEventDepletion, 30, 0.9, grid, enqueueEvent)
	}
}

// triggerEvent 触发一个世界事件
func (e *WorldEventEngine) triggerEvent(eventType WorldEventType, duration int, intensity float64, grid *WorldGrid, enqueueEvent func(*model.LifeEventLog)) {
	evt := WorldEventState{
		Type:           eventType,
		Active:         true,
		RemainingTicks: duration,
		Intensity:      intensity,
	}
	e.activeEvents = append(e.activeEvents, evt)

	msg := e.triggerMessage(eventType)
	e.prevDiffs = append(e.prevDiffs, WorldEventDiff{
		Type:      string(eventType),
		Active:    true,
		Intensity: intensity,
		Message:   msg,
	})

	// 记录到事件日志
	if enqueueEvent != nil {
		logEvt := &model.LifeEventLog{
			WorldID:     "",
			EventType:   "world_" + string(eventType),
			Description: msg,
			CreatedAt:   time.Now(),
		}
		enqueueEvent(logEvt)
	}
}

// triggerStorm 触发暴风雨，影响随机 3×3 区域
func (e *WorldEventEngine) triggerStorm(grid *WorldGrid, enqueueEvent func(*model.LifeEventLog)) {
	if grid == nil || grid.Width < 3 || grid.Height < 3 {
		return
	}
	// 随机选择中心点
	cx := e.rng.Intn(grid.Width-2) + 1
	cy := e.rng.Intn(grid.Height-2) + 1

	var affected []GridPos
	for dy := -1; dy <= 1; dy++ {
		for dx := -1; dx <= 1; dx++ {
			affected = append(affected, GridPos{X: cx + dx, Y: cy + dy})
		}
	}

	evt := WorldEventState{
		Type:           WorldEventStorm,
		Active:         true,
		RemainingTicks: 6,
		Intensity:      0.95,
		AffectedCells:  affected,
	}
	e.activeEvents = append(e.activeEvents, evt)

	msg := "暴风雨席卷了部分区域！"
	e.prevDiffs = append(e.prevDiffs, WorldEventDiff{
		Type:      string(WorldEventStorm),
		Active:    true,
		Intensity: 0.95,
		Message:   msg,
	})

	if enqueueEvent != nil {
		logEvt := &model.LifeEventLog{
			EventType:   "world_" + string(WorldEventStorm),
			Description: msg,
			CreatedAt:   time.Now(),
		}
		enqueueEvent(logEvt)
	}
}

// applyEffects 将活跃事件效果应用到网格
func (e *WorldEventEngine) applyEffects(grid *WorldGrid) {
	if grid == nil {
		return
	}
	for i := range e.activeEvents {
		evt := &e.activeEvents[i]
		if !evt.Active {
			continue
		}
		switch evt.Type {
		case WorldEventRain:
			// rain：moisture +2, food regen +50%（通过提高 moisture 间接影响）
			for y := 0; y < grid.Height; y++ {
				for x := 0; x < grid.Width; x++ {
					cell := &grid.Cells[y][x]
					cell.Moisture = clamp(cell.Moisture+2, 0, 100)
					if cell.Habitable {
						cell.Food = clamp(cell.Food+0.5, 0, maxCellFood)
					}
				}
			}
		case WorldEventDrought:
			// drought：moisture -3, food regen -80%
			for y := 0; y < grid.Height; y++ {
				for x := 0; x < grid.Width; x++ {
					cell := &grid.Cells[y][x]
					cell.Moisture = clamp(cell.Moisture-3, 0, 100)
					cell.Food = clamp(cell.Food-0.8, 0, maxCellFood)
				}
			}
		case WorldEventStorm:
			// storm：affected cells danger +5
			for _, pos := range evt.AffectedCells {
				if pos.Y >= 0 && pos.Y < grid.Height && pos.X >= 0 && pos.X < grid.Width {
					cell := &grid.Cells[pos.Y][pos.X]
					cell.Danger = clamp(cell.Danger+5, 0, 100)
					if cell.Danger >= 28 {
						cell.Habitable = false
						cell.Terrain = "hazard"
					}
				}
			}
		case WorldEventDepletion:
			// depletion：food regen -90%
			for y := 0; y < grid.Height; y++ {
				for x := 0; x < grid.Width; x++ {
					cell := &grid.Cells[y][x]
					cell.Food = clamp(cell.Food-0.9, 0, maxCellFood)
				}
			}
		case WorldEventHeatwave:
			// 热浪：水分-2, 食物衰减加速
			for y := 0; y < grid.Height; y++ {
				for x := 0; x < grid.Width; x++ {
					cell := &grid.Cells[y][x]
					cell.Moisture = math.Max(0, cell.Moisture-2*evt.Intensity)
					cell.Food = math.Max(0, cell.Food-0.3*evt.Intensity)
				}
			}
		case WorldEventFog:
			// 大雾：危险度+1（视线受阻）
			for y := 0; y < grid.Height; y++ {
				for x := 0; x < grid.Width; x++ {
					cell := &grid.Cells[y][x]
					cell.Danger = math.Min(100, cell.Danger+1*evt.Intensity)
				}
			}
		case WorldEventAbundance:
			// 资源丰饶：食物+3，仅 habitable cells
			for y := 0; y < grid.Height; y++ {
				for x := 0; x < grid.Width; x++ {
					cell := &grid.Cells[y][x]
					if cell.Habitable {
						cell.Food = math.Min(100, cell.Food+3*evt.Intensity)
					}
				}
			}
		case WorldEventMigration:
			// 迁徙潮：随机 2-3 个 cell food+5
			numCells := 2 + e.rng.Intn(2)
			for n := 0; n < numCells; n++ {
				rx := e.rng.Intn(grid.Width)
				ry := e.rng.Intn(grid.Height)
				cell := &grid.Cells[ry][rx]
				cell.Food = math.Min(100, cell.Food+5*evt.Intensity)
			}
		}
	}
}

// currentWeather 返回当前主导天气
// 优先级：storm > heatwave > drought > rain > fog > clear
func (e *WorldEventEngine) currentWeather() string {
	for i := range e.activeEvents {
		evt := &e.activeEvents[i]
		if !evt.Active {
			continue
		}
		switch evt.Type {
		case WorldEventStorm:
			return "storm"
		case WorldEventHeatwave:
			return "heatwave"
		case WorldEventDrought:
			return "drought"
		case WorldEventRain:
			return "rain"
		case WorldEventFog:
			return "fog"
		}
	}
	return "clear"
}

// buildDiffs 构建广播用的事件差异列表
func (e *WorldEventEngine) buildDiffs() []WorldEventDiff {
	return e.prevDiffs
}

// isEventActive 检查某类事件是否活跃
func (e *WorldEventEngine) isEventActive(t WorldEventType) bool {
	for i := range e.activeEvents {
		if e.activeEvents[i].Type == t && e.activeEvents[i].Active {
			return true
		}
	}
	return false
}

// ActiveEventDescriptions 返回当前活跃事件的描述列表
func (e *WorldEventEngine) ActiveEventDescriptions() []string {
	var descs []string
	for i := range e.activeEvents {
		evt := &e.activeEvents[i]
		if !evt.Active {
			continue
		}
		descs = append(descs, string(evt.Type))
	}
	return descs
}

func (e *WorldEventEngine) triggerMessage(t WorldEventType) string {
	switch t {
	case WorldEventRain:
		return "世界下起了雨，大地变得湿润..."
	case WorldEventDrought:
		return "干旱来袭，水源正在枯竭..."
	case WorldEventStorm:
		return "暴风雨席卷了部分区域！"
	case WorldEventDepletion:
		return "食物资源正在枯竭..."
	case WorldEventHeatwave:
		return "🔥 热浪来袭，水分加速蒸发"
	case WorldEventFog:
		return "🌫️ 大雾弥漫，视线受阻"
	case WorldEventAbundance:
		return "🌾 资源丰饶，食物充足"
	case WorldEventMigration:
		return "🦋 迁徙潮涌，远方带来了新的资源"
	default:
		return "世界发生了变化..."
	}
}

func (e *WorldEventEngine) endMessage(t WorldEventType) string {
	switch t {
	case WorldEventRain:
		return "雨停了，世界恢复了平静。"
	case WorldEventDrought:
		return "干旱结束了，水源开始恢复。"
	case WorldEventStorm:
		return "暴风雨过去了。"
	case WorldEventDepletion:
		return "资源开始恢复了。"
	case WorldEventHeatwave:
		return "☀️ 热浪消退，温度恢复正常"
	case WorldEventFog:
		return "🌤️ 大雾散去，视线恢复清晰"
	case WorldEventAbundance:
		return "🍂 丰饶期结束，资源回归正常"
	case WorldEventMigration:
		return "🦅 迁徙潮退去，世界恢复平静"
	default:
		return "世界事件结束了。"
	}
}
