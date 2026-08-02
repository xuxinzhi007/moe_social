package companionbiz

func sanitizeCompanionEventPayload(sourceDomain, eventType string, payload map[string]interface{}) map[string]interface{} {
	if sourceDomain != "social" {
		return payload
	}

	allowed := map[string]map[string]struct{}{
		"post_created": {
			"topic_tag_count": {},
			"image_count":     {},
			"mood_tag":        {},
			"has_hand_draw":   {},
		},
		"post_liked": {
			"post_author_user_id": {},
			"like_count":          {},
		},
		"comment_created": {
			"post_id":   {},
			"parent_id": {},
		},
		"comment_liked": {
			"post_id":    {},
			"like_count": {},
		},
		"follow_created": {
			"following_user_id": {},
		},
		"follow_removed": {
			"following_user_id": {},
		},
		"friend_request_sent": {
			"target_user_id": {},
			"status":         {},
		},
		"friend_request_received": {
			"from_user_id": {},
			"status":       {},
		},
		"friend_request_accepted": {
			"from_user_id": {},
			"to_user_id":   {},
			"status":       {},
		},
		"friend_request_rejected": {
			"from_user_id": {},
			"to_user_id":   {},
			"status":       {},
		},
	}
	keys, exists := allowed[eventType]
	if !exists {
		return map[string]interface{}{}
	}

	filtered := make(map[string]interface{}, len(keys))
	for key := range keys {
		if value, ok := payload[key]; ok {
			filtered[key] = value
		}
	}
	return filtered
}

func companionEventSensitivity(sourceDomain, eventType string) string {
	switch sourceDomain {
	case "chat", "voice", "memory":
		return "sensitive"
	case "social", "life", "relationship", "proactive":
		return "normal"
	default:
		if eventType == "memory_conflict_detected" {
			return "sensitive"
		}
		return "normal"
	}
}
