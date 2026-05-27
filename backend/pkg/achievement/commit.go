package achievement

import "gorm.io/gorm"

// ApplyEventAfterCommit runs achievement logic after the business transaction commits.
// Use this instead of ApplyEvent inside payment/post/comment transactions so
// achievement DB issues never prolong locks or interact with rollbacks.
func ApplyEventAfterCommit(db *gorm.DB, userID uint, ev Event) ([]UnlockResult, error) {
	if db == nil || userID == 0 {
		return nil, nil
	}
	return NewEngine(db).ApplyEvent(db, userID, ev)
}
