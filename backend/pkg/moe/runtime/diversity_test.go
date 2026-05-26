package runtime

import (
	"testing"

	"backend/model"
)

func TestHasBannedOpening(t *testing.T) {
	cases := []struct {
		content string
		want    bool
	}{
		{"周三的深夜，Moe社区的星光依然温柔", true},
		{"刚画完线稿，手酸，周末你们干嘛", false},
		{"今天排队买咖啡等了20分钟", false},
	}
	for _, c := range cases {
		if got := hasBannedOpening(c.content); got != c.want {
			t.Errorf("hasBannedOpening(%q) = %v, want %v", c.content, got, c.want)
		}
	}
}

func TestMeaningTooSimilar(t *testing.T) {
	recent := []model.Post{
		{Content: "周三的深夜，Moe社区的星光温柔，刚画完一幅想象作品"},
	}
	episodes := []model.MoeBotEpisode{
		{Content: "周三的夜晚，Moe社区夜空璀璨，线稿终于收尾"},
	}
	newPost := "周三的深夜，Moe社区里的灯光依旧温暖，指尖还留着颜料味"
	if !meaningTooSimilar(newPost, recent, episodes) {
		t.Fatal("expected meaningTooSimilar=true for template cluster")
	}
	different := "画材店又涨价了，马克笔三支一百二，心在滴血"
	if meaningTooSimilar(different, recent, episodes) {
		t.Fatal("expected meaningTooSimilar=false for unrelated post")
	}
}
