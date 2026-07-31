package lifebiz

import (
	"testing"

	"backend/model"
)

func TestClamp(t *testing.T) {
	tests := []struct {
		name     string
		v        float64
		min      float64
		max      float64
		expected float64
	}{
		{"正常值", 50, 0, 100, 50},
		{"下界", 0, 0, 100, 0},
		{"上界", 100, 0, 100, 100},
		{"负数截断", -5, 0, 100, 0},
		{"超上限截断", 150, 0, 100, 100},
		{"min等于max", 50, 30, 30, 30},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := clamp(tc.v, tc.min, tc.max)
			if got != tc.expected {
				t.Errorf("clamp(%v,%v,%v)=%v, want %v", tc.v, tc.min, tc.max, got, tc.expected)
			}
		})
	}
}

func TestDecayAttributes(t *testing.T) {
	// 基础衰减率：hunger=0.8, energy=0.45, mood=0.18
	// juvenile decay mult=0.5, adolescent=0.8, adult=1.0, elderly=1.5
	tests := []struct {
		name          string
		stage         string
		initHunger    float64
		initEnergy    float64
		initMood      float64
		wantHungerGt  float64 // decay后hunger应 > 此值
		wantHungerLt  float64 // decay后hunger应 < 此值
		wantEnergyGt  float64
		wantEnergyLt  float64
	}{
		{
			"juvenile衰减减半", StageJuvenile,
			50, 50, 50,
			// maxStat=60, hunger decay = 0.8*0.5=0.4 → 50-0.4=49.6
			49, 50,
			// energy decay = 0.45*0.5=0.225 → 50-0.225=49.775
			49, 50,
		},
		{
			"adult标准衰减", StageAdult,
			80, 80, 80,
			// hunger decay = 0.8*1.0=0.8 → 80-0.8=79.2
			79, 80,
			// energy decay = 0.45*1.0=0.45 → 80-0.45=79.55
			79, 80,
		},
		{
			"elderly加速衰减", StageElderly,
			80, 80, 80,
			// hunger decay = 0.8*1.5=1.2 → 80-1.2=78.8
			78, 79,
			// energy decay = 0.45*1.5=0.675 → 80-0.675=79.325
			79, 80,
		},
		{
			"adolescent衰减", StageAdolescent,
			80, 80, 80,
			// hunger decay = 0.8*0.8=0.64 → 80-0.64=79.36
			79, 80,
			79, 80,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			e := &model.LifeEntity{
				Hunger:      tc.initHunger,
				Energy:      tc.initEnergy,
				Mood:        tc.initMood,
				GrowthStage: tc.stage,
			}
			decayAttributes(e)
			if e.Hunger < tc.wantHungerGt || e.Hunger > tc.wantHungerLt {
				t.Errorf("stage=%s hunger=%.4f, want in (%.1f,%.1f)", tc.stage, e.Hunger, tc.wantHungerGt, tc.wantHungerLt)
			}
			if e.Energy < tc.wantEnergyGt || e.Energy > tc.wantEnergyLt {
				t.Errorf("stage=%s energy=%.4f, want in (%.1f,%.1f)", tc.stage, e.Energy, tc.wantEnergyGt, tc.wantEnergyLt)
			}
			// mood 应该减少（至少对已知阶段）
			if e.Mood >= tc.initMood {
				t.Errorf("stage=%s mood=%.4f, should be less than %.1f", tc.stage, e.Mood, tc.initMood)
			}
		})
	}
}

func TestShouldDie(t *testing.T) {
	tests := []struct {
		name   string
		entity *model.LifeEntity
		cell   *WorldCell
		want   bool
	}{
		{"hunger=0但energy高存活", &model.LifeEntity{Hunger: 0, Energy: 50}, nil, false},
		{"hunger=0且energy<=5死亡", &model.LifeEntity{Hunger: 0, Energy: 5}, nil, true},
		{"energy=0但hunger高存活", &model.LifeEntity{Hunger: 50, Energy: 0}, nil, false},
		{"energy=0且hunger<=5死亡", &model.LifeEntity{Hunger: 5, Energy: 0}, nil, true},
		{"hunger=0且energy=0死亡", &model.LifeEntity{Hunger: 0, Energy: 0}, nil, true},
		{"双高存活", &model.LifeEntity{Hunger: 50, Energy: 50}, nil, false},
		{"nil entity", nil, nil, false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := shouldDie(tc.entity, tc.cell)
			if got != tc.want {
				t.Errorf("shouldDie()=%v, want %v", got, tc.want)
			}
		})
	}
}

func TestDecideAction(t *testing.T) {
	// 用确定性输入测试非随机分支
	tests := []struct {
		name   string
		entity *model.LifeEntity
		want   LifeAction
	}{
		{"energy<15→sleeping", &model.LifeEntity{Energy: 14, Hunger: 50, Mood: 50}, ActionSleeping},
		{"energy=15且hunger<26→seeking_food", &model.LifeEntity{Energy: 19, Hunger: 25, Mood: 50}, ActionSeekingFood},
		{"mood<28→wandering", &model.LifeEntity{Energy: 50, Hunger: 50, Mood: 27}, ActionWandering},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := decideAction(tc.entity)
			if got != tc.want {
				t.Errorf("decideAction()=%v, want %v", got, tc.want)
			}
		})
	}

	// 测试高属性时返回 walking 或 idle（随机分支，多次执行至少覆盖两种）
	t.Run("高属性随机分支", func(t *testing.T) {
		e := &model.LifeEntity{Energy: 80, Hunger: 80, Mood: 80}
		actions := map[LifeAction]bool{}
		for i := 0; i < 200; i++ {
			a := decideAction(e)
			actions[a] = true
		}
		if !actions[ActionWalking] || !actions[ActionIdle] {
			t.Errorf("expected both walking and idle in 200 runs, got %v", actions)
		}
	})
}

func TestDecideActionWithRelations(t *testing.T) {
	// 基础需求优先：energy<15 → sleeping
	t.Run("energy低优先sleeping", func(t *testing.T) {
		e := &model.LifeEntity{ID: 1, Energy: 10, Hunger: 50, Mood: 50}
		entities := map[uint]*model.LifeEntity{1: e}
		got := decideActionWithRelations(e, entities, nil)
		if got != ActionSleeping {
			t.Errorf("got %v, want sleeping", got)
		}
	})

	// 有朋友在场（距离 40-200）→ talking
	t.Run("朋友在场→talking", func(t *testing.T) {
		e := &model.LifeEntity{ID: 1, Energy: 80, Hunger: 80, Mood: 80, PositionX: 100, PositionY: 100}
		friend := &model.LifeEntity{ID: 2, Energy: 80, Hunger: 80, Mood: 80, PositionX: 200, PositionY: 100} // dist=100
		entities := map[uint]*model.LifeEntity{1: e, 2: friend}
		rels := []*model.LifeRelationship{
			{EntityID: 1, TargetID: 2, RelationType: RelFriend},
		}
		got := decideActionWithRelations(e, entities, rels)
		if got != ActionTalking {
			t.Errorf("got %v, want talking", got)
		}
	})

	// 有对手在场（距离<120）→ walking（远离）
	t.Run("对手在场→walking", func(t *testing.T) {
		e := &model.LifeEntity{ID: 1, Energy: 80, Hunger: 80, Mood: 80, PositionX: 100, PositionY: 100}
		rival := &model.LifeEntity{ID: 2, Energy: 80, Hunger: 80, Mood: 80, PositionX: 150, PositionY: 100} // dist=50
		entities := map[uint]*model.LifeEntity{1: e, 2: rival}
		rels := []*model.LifeRelationship{
			{EntityID: 1, TargetID: 2, RelationType: RelRival},
		}
		got := decideActionWithRelations(e, entities, rels)
		if got != ActionWalking {
			t.Errorf("got %v, want walking", got)
		}
	})
}

func TestApplyAction(t *testing.T) {
	tests := []struct {
		name       string
		action     LifeAction
		initHunger float64
		initEnergy float64
		initMood   float64
		cell       *WorldCell
		checkFn    func(t *testing.T, e *model.LifeEntity)
	}{
		{
			"sleeping恢复energy", ActionSleeping, 50, 50, 50, nil,
			func(t *testing.T, e *model.LifeEntity) {
				if e.Energy <= 50 {
					t.Errorf("sleeping should increase energy, got %.4f", e.Energy)
				}
			},
		},
		{
			"wandering提升mood", ActionWandering, 50, 50, 50, nil,
			func(t *testing.T, e *model.LifeEntity) {
				if e.Mood <= 50 {
					t.Errorf("wandering should increase mood, got %.4f", e.Mood)
				}
			},
		},
		{
			"walking消耗energy", ActionWalking, 50, 50, 50, nil,
			func(t *testing.T, e *model.LifeEntity) {
				if e.Energy >= 50 {
					t.Errorf("walking should decrease energy, got %.4f", e.Energy)
				}
			},
		},
		{
			"eating提升hunger", ActionEating, 50, 50, 50, nil,
			func(t *testing.T, e *model.LifeEntity) {
				if e.Hunger <= 50 {
					t.Errorf("eating should increase hunger, got %.4f", e.Hunger)
				}
			},
		},
		{
			"talking提升mood", ActionTalking, 50, 50, 50, nil,
			func(t *testing.T, e *model.LifeEntity) {
				if e.Mood <= 50 {
					t.Errorf("talking should increase mood, got %.4f", e.Mood)
				}
			},
		},
		{
			"idle小幅恢复全属性", ActionIdle, 50, 50, 50, nil,
			func(t *testing.T, e *model.LifeEntity) {
				if e.Hunger <= 50 || e.Energy <= 50 || e.Mood <= 50 {
					t.Errorf("idle should increase all stats: h=%.4f e=%.4f m=%.4f", e.Hunger, e.Energy, e.Mood)
				}
			},
		},
		{
			"seeking_food有食物→eating", ActionSeekingFood, 50, 50, 50, &WorldCell{Food: 50, Habitable: true},
			func(t *testing.T, e *model.LifeEntity) {
				if e.CurrentAction != string(ActionEating) {
					t.Errorf("seeking_food with food cell should become eating, got %s", e.CurrentAction)
				}
				if e.Hunger <= 50 {
					t.Errorf("eating should increase hunger, got %.4f", e.Hunger)
				}
			},
		},
		{
			"seeking_food无食物→移动", ActionSeekingFood, 50, 50, 50, &WorldCell{Food: 2, Habitable: true},
			func(t *testing.T, e *model.LifeEntity) {
				// energy 消耗
				if e.Energy >= 50 {
					t.Errorf("seeking_food without food should cost energy, got %.4f", e.Energy)
				}
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			e := &model.LifeEntity{
				Hunger: tc.initHunger,
				Energy: tc.initEnergy,
				Mood:   tc.initMood,
			}
			applyAction(e, tc.action, tc.cell)
			tc.checkFn(t, e)
		})
	}
}
