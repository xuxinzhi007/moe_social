package utils

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/spf13/viper"
)

func TestBuildFeishuAgentEventCard(t *testing.T) {
	card := buildFeishuAgentEventCard(FeishuAgentEvent{
		Action: FeishuAgentCreated,
		UserName:        "测试用户",
		UserID:          "42",
		AgentID:         "agent_1",
		AgentName:       "猫娘助手",
		Description:     "描述含 *markdown* 与换行\n第二行",
		ModelName:       "llama3:8b",
		ProviderProfile: "openai_compatible",
		EventAt:         time.Date(2026, 5, 19, 12, 0, 0, 0, time.Local),
	})
	if card == nil {
		t.Fatal("card is nil")
	}
	header, ok := card["header"].(map[string]interface{})
	if !ok {
		t.Fatal("missing header")
	}
	title, ok := header["title"].(map[string]interface{})
	if !ok || title["content"] != "角色卡创建成功" {
		t.Fatalf("unexpected title: %#v", header["title"])
	}
}

func TestNormalizeFeishuEmail(t *testing.T) {
	got, err := NormalizeFeishuEmail("  User@Feishu.CN ")
	if err != nil {
		t.Fatal(err)
	}
	if got != "user@feishu.cn" {
		t.Fatalf("got %q", got)
	}
	if _, err := NormalizeFeishuEmail("not-an-email"); err == nil {
		t.Fatal("expected error for invalid email")
	}
}

// 集成测试：配置 backend/config/config.yaml 的 feishu 段后执行：
// FEISHU_INTEGRATION_TEST=1 FEISHU_TEST_EMAIL=you@feishu.cn go test ./utils -run TestSendFeishuTestCardIntegration -v
func TestSendFeishuTestCardIntegration(t *testing.T) {
	if os.Getenv("FEISHU_INTEGRATION_TEST") != "1" {
		t.Skip("set FEISHU_INTEGRATION_TEST=1 to run live Feishu IM test")
	}
	if err := InitConfig(); err != nil {
		t.Fatalf("init config: %v", err)
	}
	email := strings.TrimSpace(os.Getenv("FEISHU_TEST_EMAIL"))
	if email == "" {
		email = strings.TrimSpace(viper.GetString("feishu.receive_id"))
	}
	if email == "" {
		t.Fatal("set FEISHU_TEST_EMAIL or feishu.receive_id in config")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := SendFeishuTestCard(ctx, email); err != nil {
		t.Fatalf("send test card: %v", err)
	}
}
