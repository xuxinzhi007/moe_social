package gamebiz

import (
	"testing"

	"backend/model"
)

func TestPickupNotInventoryCheck(t *testing.T) {
	snap := &SessionSnapshot{Scene: model.GameScene{Name: "迷雾小镇"}}
	cmd := parseOfflineCommand("捡起石头放进背包", snap)
	if cmd.Kind != CmdPickup {
		t.Fatalf("expected CmdPickup, got %s", cmd.Kind)
	}
	if cmd.Target != "石头" {
		t.Fatalf("expected target 石头, got %q", cmd.Target)
	}
}

func TestInventoryCheckStillWorks(t *testing.T) {
	snap := &SessionSnapshot{Scene: model.GameScene{Name: "迷雾小镇"}}
	cmd := parseOfflineCommand("检查背包", snap)
	if cmd.Kind != CmdInspectInventory {
		t.Fatalf("expected CmdInspectInventory, got %s", cmd.Kind)
	}
}

func TestExtractPickupItemName(t *testing.T) {
	if got := extractPickupItemName("捡起石头放进背包"); got != "石头" {
		t.Fatalf("got %q", got)
	}
	if got := extractPickupItemName("把钥匙收入背包"); got != "钥匙" {
		t.Fatalf("got %q", got)
	}
}

func TestPickupNarrateOutput(t *testing.T) {
	out := pickupNarrateOutput("石头", model.GameWorldItem{Name: "石头", InInventory: true}, true)
	if !contains(out.Prose, "石头") || contains(out.Prose, "空空如也") {
		t.Fatalf("unexpected pickup prose: %s", out.Prose)
	}
}
