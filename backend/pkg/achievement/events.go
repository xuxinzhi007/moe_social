package achievement

// EventType identifies achievement trigger sources.
type EventType string

const (
	EventUserInitialized EventType = "user_initialized"
	EventCheckIn         EventType = "check_in"
	EventPostCreated     EventType = "post_created"
	EventCommentCreated  EventType = "comment_created"
	EventPostLiked       EventType = "post_liked"
	EventGiftSent        EventType = "gift_sent"
	EventVipActivated    EventType = "vip_activated"
	EventNewFollower     EventType = "new_follower"
)

// Event is passed to ApplyEvent.
type Event struct {
	Type EventType
	// PostCreated
	ImageCount       int
	HasTopic         bool
	ContentLen       int
	MoodTag          string
	HasHandDraw      bool
	HandDrawApproved bool
	Hour             int
	// PostLiked
	PostLikeCount int
	// GiftSent
	GiftCount int
	GiftValue float64
}
