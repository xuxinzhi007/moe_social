package runtime

import (
	"strings"
	"testing"

	"backend/model"
)

func TestFormatPostRulesBlockUsesDBRules(t *testing.T) {
	rt := model.MoeAgentRuntime{
		PostRules: "必须用第一人称\n# 注释行\n禁止官方腔",
	}
	block := formatPostRulesBlock(rt)
	if !strings.Contains(block, "必须用第一人称") {
		t.Fatal(block)
	}
	if strings.Contains(block, "注释行") {
		t.Fatal("comment should be skipped")
	}
}

func TestFormatPostRulesBlockDefault(t *testing.T) {
	block := formatPostRulesBlock(model.MoeAgentRuntime{})
	if !strings.Contains(block, "硬性规则") {
		t.Fatal(block)
	}
}
