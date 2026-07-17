package lifebiz

import "testing"

func TestShouldGrow(t *testing.T) {
	tests := []struct {
		name       string
		stage      string
		experience float64
		wantNext   string
		wantGrow   bool
	}{
		{"juvenile经验不足", StageJuvenile, 50, "", false},
		{"juvenile经验恰好", StageJuvenile, 100, StageAdolescent, true},
		{"juvenile经验超出", StageJuvenile, 200, StageAdolescent, true},
		{"adolescent经验不足", StageAdolescent, 100, "", false},
		{"adolescent经验恰好", StageAdolescent, 300, StageAdult, true},
		{"adult经验不足", StageAdult, 500, "", false},
		{"adult经验恰好", StageAdult, 800, StageElderly, true},
		{"elderly不再成长", StageElderly, 9999, "", false},
		{"未知阶段不成长", "unknown", 9999, "", false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			next, ok := ShouldGrow(tc.stage, tc.experience)
			if ok != tc.wantGrow {
				t.Errorf("ShouldGrow(%s,%.0f) grow=%v, want %v", tc.stage, tc.experience, ok, tc.wantGrow)
			}
			if next != tc.wantNext {
				t.Errorf("ShouldGrow(%s,%.0f) next=%q, want %q", tc.stage, tc.experience, next, tc.wantNext)
			}
		})
	}
}

func TestGetNextStage(t *testing.T) {
	tests := []struct {
		name    string
		current string
		want    string
	}{
		{"juvenile→adolescent", StageJuvenile, StageAdolescent},
		{"adolescent→adult", StageAdolescent, StageAdult},
		{"adult→elderly", StageAdult, StageElderly},
		{"elderly→空", StageElderly, ""},
		{"未知→空", "unknown", ""},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := GetNextStage(tc.current)
			if got != tc.want {
				t.Errorf("GetNextStage(%s)=%q, want %q", tc.current, got, tc.want)
			}
		})
	}
}

func TestApplyGrowthDecayMultiplier(t *testing.T) {
	baseDecay := 1.0
	tests := []struct {
		name  string
		stage string
		want  float64
	}{
		{"juvenile衰减系数0.5", StageJuvenile, 0.5},
		{"adolescent衰减系数0.8", StageAdolescent, 0.8},
		{"adult衰减系数1.0", StageAdult, 1.0},
		{"elderly衰减系数1.5", StageElderly, 1.5},
		{"未知阶段返回原始值", "unknown", 1.0},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := ApplyGrowthDecayMultiplier(tc.stage, baseDecay)
			if got != tc.want {
				t.Errorf("ApplyGrowthDecayMultiplier(%s,%.1f)=%.2f, want %.2f", tc.stage, baseDecay, got, tc.want)
			}
		})
	}
}

func TestGetMaxStat(t *testing.T) {
	tests := []struct {
		name  string
		stage string
		want  float64
	}{
		{"juvenile上限60", StageJuvenile, 60},
		{"adolescent上限80", StageAdolescent, 80},
		{"adult上限100", StageAdult, 100},
		{"elderly上限80", StageElderly, 80},
		{"未知阶段默认100", "unknown", 100},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := GetMaxStat(tc.stage)
			if got != tc.want {
				t.Errorf("GetMaxStat(%s)=%.1f, want %.1f", tc.stage, got, tc.want)
			}
		})
	}
}

func TestStageForAge(t *testing.T) {
	tests := []struct {
		name string
		age  int
		want string
	}{
		{"0→juvenile", 0, StageJuvenile},
		{"99→juvenile", 99, StageJuvenile},
		{"100→adolescent", 100, StageAdolescent},
		{"299→adolescent", 299, StageAdolescent},
		{"300→adult", 300, StageAdult},
		{"799→adult", 799, StageAdult},
		{"800→elderly", 800, StageElderly},
		{"1000→elderly", 1000, StageElderly},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := stageForAge(tc.age)
			if got != tc.want {
				t.Errorf("stageForAge(%d)=%q, want %q", tc.age, got, tc.want)
			}
		})
	}
}
