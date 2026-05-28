package presence

import pkgpresence "backend/internal/pkg/presence"

// DefaultState re-exports the process-wide presence tracker (moved to internal/pkg/presence).
var DefaultState = pkgpresence.DefaultState

// State re-exports presence tracker type.
type State = pkgpresence.State

// NewState constructs an empty presence tracker.
func NewState() *State {
	return pkgpresence.NewState()
}
