package companionbiz

import (
	"strings"
	"testing"
	"time"
)

func TestRelationshipGuidanceTracksRelationshipLevel(t *testing.T) {
	tests := []struct {
		name   string
		level  int
		want   string
		unwant string
	}{
		{name: "new", level: 1, want: "初识阶段", unwant: "主动创造共同回忆"},
		{name: "familiar", level: 4, want: "逐渐熟悉", unwant: "初识阶段"},
		{name: "stable", level: 6, want: "稳定联系", unwant: "逐渐熟悉"},
		{name: "close", level: 8, want: "很习惯", unwant: "稳定联系"},
		{name: "intimate", level: 10, want: "关系亲近", unwant: "很习惯"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			prompt := buildSystemPrompt(&Profile{RelationshipLevel: tt.level}, nil, nil)
			if !strings.Contains(prompt, tt.want) {
				t.Fatalf("prompt does not contain %q: %s", tt.want, prompt)
			}
			if strings.Contains(prompt, tt.unwant) {
				t.Fatalf("prompt unexpectedly contains %q: %s", tt.unwant, prompt)
			}
		})
	}
}

func TestRelationshipGuidanceSetsHealthyBoundary(t *testing.T) {
	guidance := relationshipGuidance(&Profile{RelationshipLevel: 10})
	if !strings.Contains(guidance, "尊重") || !strings.Contains(guidance, "现实关系") {
		t.Fatalf("high-level guidance lacks boundaries: %s", guidance)
	}
}

func TestSceneGuidanceSupportsComfortAndRepair(t *testing.T) {
	guidance := sceneGuidance(
		time.Date(2026, time.December, 25, 23, 0, 0, 0, time.Local),
		&State{Mood: 30, Energy: 20},
	)
	for _, want := range []string{"情绪安抚", "承接用户的感受", "具体道歉", "圣诞节"} {
		if !strings.Contains(guidance, want) {
			t.Fatalf("scene guidance does not contain %q: %s", want, guidance)
		}
	}
}

func TestHolidayLabelOnlyUsesSupportedFixedDates(t *testing.T) {
	if got := holidayLabel(time.Date(2026, time.July, 7, 12, 0, 0, 0, time.Local)); got != "" {
		t.Fatalf("holidayLabel() = %q, want empty for unsupported date", got)
	}
	if got := holidayLabel(time.Date(2026, time.October, 1, 12, 0, 0, 0, time.Local)); got != "国庆节" {
		t.Fatalf("holidayLabel() = %q, want 国庆节", got)
	}
}

func TestSceneGuidanceMapsUserSceneIds(t *testing.T) {
	guidance := sceneGuidance(time.Date(2026, time.August, 3, 14, 0, 0, 0, time.Local), nil, "study")
	if !strings.Contains(guidance, "专注学习") || !strings.Contains(guidance, "小步骤") {
		t.Fatalf("scene guidance = %s", guidance)
	}
}
