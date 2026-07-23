package companionbiz

import "errors"

var (
	// ErrLifeEntityNotFound indicates that the selected Life entity is unavailable.
	ErrLifeEntityNotFound = errors.New("companion life entity not found")
)
