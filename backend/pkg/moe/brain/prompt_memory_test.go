package brain

import (
	"strings"
	"testing"

	"backend/model"
)

func TestFormatEpisodesForPromptDoesNotExposeContent(t *testing.T) {
	const content = "这是不应被模型直接复刻的历史帖子正文"
	out := formatEpisodesForPrompt([]model.MoeBotEpisode{
		{Content: content, TagsJSON: `["topic:日常"]`, QualityScore: 88},
	})
	if strings.Contains(out, content) {
		t.Fatalf("prompt memory exposed episode content: %s", out)
	}
	if !strings.Contains(out, "topic:日常") || !strings.Contains(out, "质量=88") {
		t.Fatalf("prompt memory lost metadata: %s", out)
	}
}
