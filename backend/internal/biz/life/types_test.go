package lifebiz

import (
	"testing"
)

func TestSerializeDeserializeGrid(t *testing.T) {
	t.Run("正常网格往返", func(t *testing.T) {
		grid := &WorldGrid{
			Width:  2,
			Height: 2,
			Cells: [][]WorldCell{
				{{Terrain: "grass", Food: 50, Moisture: 60, Danger: 10, Habitable: true}, {Terrain: "dry", Food: 20, Moisture: 25, Danger: 5, Habitable: true}},
				{{Terrain: "wetland", Food: 80, Moisture: 85, Danger: 3, Habitable: true}, {Terrain: "hazard", Food: 0, Moisture: 40, Danger: 50, Habitable: false}},
			},
			Weather: "clear",
		}
		data, err := SerializeGrid(grid)
		if err != nil {
			t.Fatalf("SerializeGrid error: %v", err)
		}
		if data == "" {
			t.Fatal("SerializeGrid returned empty string")
		}

		got, err := DeserializeGrid(data)
		if err != nil {
			t.Fatalf("DeserializeGrid error: %v", err)
		}
		if got.Width != 2 || got.Height != 2 {
			t.Errorf("grid size=%dx%d, want 2x2", got.Width, got.Height)
		}
		if got.Cells[0][0].Terrain != "grass" {
			t.Errorf("cell[0][0].Terrain=%q, want grass", got.Cells[0][0].Terrain)
		}
		if got.Cells[1][1].Habitable {
			t.Errorf("cell[1][1].Habitable=true, want false")
		}
		if got.Weather != "clear" {
			t.Errorf("weather=%q, want clear", got.Weather)
		}
	})

	t.Run("nil网格", func(t *testing.T) {
		data, err := SerializeGrid(nil)
		if err != nil {
			t.Fatalf("SerializeGrid(nil) error: %v", err)
		}
		if data != "" {
			t.Errorf("SerializeGrid(nil)=%q, want empty", data)
		}
	})

	t.Run("空字符串", func(t *testing.T) {
		got, err := DeserializeGrid("")
		if err != nil {
			t.Fatalf("DeserializeGrid empty error: %v", err)
		}
		if got != nil {
			t.Errorf("DeserializeGrid('')=%v, want nil", got)
		}
	})
}

func TestSerializeDeserializeActiveEffects(t *testing.T) {
	t.Run("空切片", func(t *testing.T) {
		data, err := SerializeActiveEffects(nil)
		if err != nil {
			t.Fatalf("SerializeActiveEffects(nil) error: %v", err)
		}
		if data != "" {
			t.Errorf("SerializeActiveEffects(nil)=%q, want empty", data)
		}

		got, err := DeserializeActiveEffects("")
		if err != nil {
			t.Fatalf("DeserializeActiveEffects('') error: %v", err)
		}
		if got != nil {
			t.Errorf("DeserializeActiveEffects('')=%v, want nil", got)
		}
	})

	t.Run("多效果往返", func(t *testing.T) {
		effects := []ActiveEffect{
			{ItemID: 1, EffectKey: "hunger", EffectValue: 5.0, RemainingTicks: 10},
			{ItemID: 2, EffectKey: "mood", EffectValue: 3.5, RemainingTicks: 20},
		}
		data, err := SerializeActiveEffects(effects)
		if err != nil {
			t.Fatalf("SerializeActiveEffects error: %v", err)
		}
		got, err := DeserializeActiveEffects(data)
		if err != nil {
			t.Fatalf("DeserializeActiveEffects error: %v", err)
		}
		if len(got) != 2 {
			t.Fatalf("len=%d, want 2", len(got))
		}
		if got[0].ItemID != 1 || got[0].EffectKey != "hunger" || got[0].EffectValue != 5.0 || got[0].RemainingTicks != 10 {
			t.Errorf("effect[0]=%+v mismatch", got[0])
		}
		if got[1].ItemID != 2 || got[1].EffectKey != "mood" || got[1].EffectValue != 3.5 || got[1].RemainingTicks != 20 {
			t.Errorf("effect[1]=%+v mismatch", got[1])
		}
	})
}
