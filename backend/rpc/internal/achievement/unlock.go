package achievement

// UnlockResult is returned when a badge is newly unlocked.
type UnlockResult struct {
	BadgeID    string
	Name       string
	ExpGranted int
	NewLevel   int
	LevelUp    bool
}
