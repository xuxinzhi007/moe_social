package commentbiz

import (
	"testing"

	"backend/model"
)

func TestMentionUsernames(t *testing.T) {
	got := mentionUsernames("你好 @Alice 再看 @bob，邮箱 a@b.com @Alice @很长的名字")
	if len(got) != 3 || got[0] != "Alice" || got[1] != "bob" || got[2] != "很长的名字" {
		t.Fatalf("mentions = %#v", got)
	}

	many := "@a @b @c @d @e @f"
	capped := mentionUsernames(many)
	if len(capped) != maxCommentMentions {
		t.Fatalf("cap = %d, want %d", len(capped), maxCommentMentions)
	}
}

func TestMentionNotifyIDsSkipsSelfAndAlreadyNotified(t *testing.T) {
	already := map[uint]struct{}{1: {}, 2: {}}
	friends := []model.User{{ID: 1}, {ID: 2}, {ID: 3}, {ID: 3}, {ID: 0}}
	got := mentionNotifyIDs(1, already, friends)
	if len(got) != 1 || got[0] != 3 {
		t.Fatalf("ids = %#v", got)
	}
}
