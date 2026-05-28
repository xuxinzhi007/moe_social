package presence

import "sync"

// State tracks user online presence at app-level.
// One user can have multiple active connections.
type State struct {
	mu     sync.RWMutex
	online map[string]int
}

// NewState constructs an empty presence tracker.
func NewState() *State {
	return &State{online: make(map[string]int)}
}

// DefaultState is the process-wide presence tracker for /ws/presence.
var DefaultState = NewState()

// Add increments online connection count. Returns true if user became online.
func (s *State) Add(userID string) bool {
	if userID == "" {
		return false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	prev := s.online[userID]
	s.online[userID] = prev + 1
	return prev == 0
}

// Remove decrements online connection count. Returns true if user became offline.
func (s *State) Remove(userID string) bool {
	if userID == "" {
		return false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	prev := s.online[userID]
	if prev <= 1 {
		delete(s.online, userID)
		return prev > 0
	}
	s.online[userID] = prev - 1
	return false
}

// IsOnline reports whether the user has at least one active connection.
func (s *State) IsOnline(userID string) bool {
	if userID == "" {
		return false
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.online[userID] > 0
}

// OnlineUserIDs returns ids with a positive connection count.
func (s *State) OnlineUserIDs() []string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	ids := make([]string, 0, len(s.online))
	for id, n := range s.online {
		if n <= 0 {
			continue
		}
		ids = append(ids, id)
	}
	return ids
}
