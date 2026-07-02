package gamebiz

import (
	"testing"

	"backend/model"
)

func TestParseCommandDialogueQuestion(t *testing.T) {
	flags := defaultWorldFlags()
	flags.LastTalkNPC = "老人"
	flags.InDialogue = true
	snap := &SessionSnapshot{Flags: flags, Scene: model.GameScene{Name: "迷雾小镇"}}
	cmd := parseCommand("你多大了", snap)
	if cmd.Kind != CmdTalkReply {
		t.Fatalf("expected CmdTalkReply, got %s", cmd.Kind)
	}
}

func TestParseCommandContinueAsk(t *testing.T) {
	flags := defaultWorldFlags()
	flags.LastTalkNPC = "老人"
	flags.InDialogue = true
	snap := &SessionSnapshot{Flags: flags, Scene: model.GameScene{Name: "迷雾小镇"}}
	cmd := parseCommand("继续追问", snap)
	if cmd.Kind != CmdTalkReply {
		t.Fatalf("expected CmdTalkReply, got %s", cmd.Kind)
	}
}

func TestParseCommandNotTravelOnQuestion(t *testing.T) {
	flags := defaultWorldFlags()
	flags.LastTalkNPC = "老人"
	snap := &SessionSnapshot{Flags: flags, Scene: model.GameScene{Name: "迷雾小镇"}}
	cmd := parseCommand("你多大了", snap)
	if cmd.Kind == CmdTravel {
		t.Fatal("question must not route to travel")
	}
}

func TestDialogueAgeResponse(t *testing.T) {
	out := dialogueReplyOutput("老人", "你多大了")
	if !contains(out.Prose, "七十三") {
		t.Fatalf("expected age response, got: %s", out.Prose)
	}
}
