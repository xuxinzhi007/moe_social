package gamebiz



import (

	"testing"



	"backend/model"

)



func TestAllInputRoutesToAgent(t *testing.T) {

	snap := &SessionSnapshot{Scene: model.GameScene{Name: "迷雾小镇"}}

	for _, action := range []string{"观察周围", "查看周围", "你是什么模型", "检查背包", "捡起石头"} {

		cmd := parseCommand(action, snap)

		if cmd.Kind != CmdAgent {

			t.Fatalf("action %q expected CmdAgent, got %s", action, cmd.Kind)

		}

	}

}



func TestOfflinePickupRouting(t *testing.T) {

	snap := &SessionSnapshot{Scene: model.GameScene{Name: "迷雾小镇"}}

	cmd := parseOfflineCommand("捡起石头放进背包", snap)

	if cmd.Kind != CmdPickup {

		t.Fatalf("expected CmdPickup, got %s", cmd.Kind)

	}

	if cmd.Target != "石头" {

		t.Fatalf("expected target 石头, got %q", cmd.Target)

	}

}



func TestOfflineEnvironmentCheck(t *testing.T) {

	snap := &SessionSnapshot{Scene: model.GameScene{Name: "迷雾小镇"}}

	cmd := parseOfflineCommand("检查环境", snap)

	if cmd.Kind != CmdInspectScene {

		t.Fatalf("expected CmdInspectScene, got %s", cmd.Kind)

	}

}



func TestObserveSurroundingsRoutesToInspect(t *testing.T) {
	snap := &SessionSnapshot{Scene: model.GameScene{Name: "迷雾小镇"}}
	cmd := parseOfflineCommand("观察周围", snap)
	if cmd.Kind != CmdInspectScene {
		t.Fatalf("expected CmdInspectScene, got %s", cmd.Kind)
	}
}


