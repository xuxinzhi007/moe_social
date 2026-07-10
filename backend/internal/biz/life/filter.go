package lifebiz

// eventImportance 返回事件的重要性级别。
// 0 = 普通（7天TTL），1 = 重要（30天TTL）。
func eventImportance(eventType string) int8 {
	switch eventType {
	case "growth", "death", "birth",
		"mate_formed", "friend_made", "rival_formed", "relation_dissolved",
		"user_feed", "user_pet", "user_move",
		"world_weather_rain", "world_weather_drought",
		"world_disaster_storm", "world_resource_depletion":
		return 1
	default:
		return 0
	}
}
