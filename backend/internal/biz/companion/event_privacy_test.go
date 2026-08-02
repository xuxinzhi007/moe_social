package companionbiz

import "testing"

func TestSanitizeCompanionEventPayloadFiltersSocialContent(t *testing.T) {
	filtered := sanitizeCompanionEventPayload("social", "post_created", map[string]interface{}{
		"topic_tag_count": 2,
		"content":         "private post body",
	})
	if filtered["topic_tag_count"] != 2 {
		t.Fatalf("filtered metadata = %#v", filtered)
	}
	if _, ok := filtered["content"]; ok {
		t.Fatalf("social content must not enter companion event: %#v", filtered)
	}
}

func TestCompanionEventSensitivity(t *testing.T) {
	if got := companionEventSensitivity("voice", "voice_turn_completed"); got != "sensitive" {
		t.Fatalf("voice sensitivity = %q", got)
	}
	if got := companionEventSensitivity("social", "post_liked"); got != "normal" {
		t.Fatalf("social sensitivity = %q", got)
	}
}

func TestSanitizeCompanionEventPayloadKeepsRelationMetadata(t *testing.T) {
	filtered := sanitizeCompanionEventPayload("social", "friend_request_accepted", map[string]interface{}{
		"from_user_id": 7,
		"to_user_id":   8,
		"status":       "accepted",
		"content":      "must not be copied",
	})
	if len(filtered) != 3 || filtered["status"] != "accepted" {
		t.Fatalf("filtered relation metadata = %#v", filtered)
	}
	if _, ok := filtered["content"]; ok {
		t.Fatalf("relation content must not enter companion event: %#v", filtered)
	}
}
