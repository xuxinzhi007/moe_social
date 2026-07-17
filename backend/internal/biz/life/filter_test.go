package lifebiz

import "testing"

func TestEventImportance(t *testing.T) {
	tests := []struct {
		name  string
		event string
		want  int8
	}{
		{"birth重要", "birth", 1},
		{"death重要", "death", 1},
		{"growth重要", "growth", 1},
		{"mate_formed重要", "mate_formed", 1},
		{"friend_made重要", "friend_made", 1},
		{"rival_formed重要", "rival_formed", 1},
		{"relation_dissolved重要", "relation_dissolved", 1},
		{"user_feed重要", "user_feed", 1},
		{"user_pet重要", "user_pet", 1},
		{"user_move重要", "user_move", 1},
		{"world_weather_rain重要", "world_weather_rain", 1},
		{"world_weather_drought重要", "world_weather_drought", 1},
		{"world_disaster_storm重要", "world_disaster_storm", 1},
		{"world_resource_depletion重要", "world_resource_depletion", 1},
		{"talking普通", "talking", 0},
		{"walking普通", "walking", 0},
		{"eating普通", "eating", 0},
		{"idle普通", "idle", 0},
		{"未知事件", "some_unknown_event", 0},
		{"空字符串", "", 0},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := eventImportance(tc.event)
			if got != tc.want {
				t.Errorf("eventImportance(%q)=%d, want %d", tc.event, got, tc.want)
			}
		})
	}
}
