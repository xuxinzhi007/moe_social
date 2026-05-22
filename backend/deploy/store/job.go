package store

import (
	"sync"
	"time"
)

// Status of a deploy job.
type Status string

const (
	StatusPending   Status = "pending"
	StatusRunning   Status = "running"
	StatusSucceeded Status = "succeeded"
	StatusFailed    Status = "failed"
	StatusCancelled Status = "cancelled"
)

// Job is one deploy operation with streamed logs.
type Job struct {
	ID        string            `json:"id"`
	Type      string            `json:"type"`
	Target    string            `json:"target,omitempty"`
	Status    Status            `json:"status"`
	CreatedAt time.Time         `json:"created_at"`
	StartedAt *time.Time        `json:"started_at,omitempty"`
	EndedAt   *time.Time        `json:"ended_at,omitempty"`
	Params    map[string]string `json:"params,omitempty"`
	Command   string            `json:"command"`
	ExitCode  int               `json:"exit_code"`
	Error     string            `json:"error,omitempty"`
	Log       string            `json:"log"`
}

// Store keeps recent jobs in memory.
type Store struct {
	mu   sync.RWMutex
	jobs map[string]*Job
	max  int
}

// NewStore creates a job store.
func NewStore(max int) *Store {
	if max <= 0 {
		max = 50
	}
	return &Store{jobs: make(map[string]*Job), max: max}
}

// Add registers a new job.
func (s *Store) Add(j *Job) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.jobs[j.ID] = j
	s.trimLocked()
}

func (s *Store) trimLocked() {
	if len(s.jobs) <= s.max {
		return
	}
	var oldest *Job
	for _, j := range s.jobs {
		if oldest == nil || j.CreatedAt.Before(oldest.CreatedAt) {
			oldest = j
		}
	}
	if oldest != nil {
		delete(s.jobs, oldest.ID)
	}
}

// Get returns a job by id.
func (s *Store) Get(id string) (*Job, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	j, ok := s.jobs[id]
	return j, ok
}

// Update applies fn to a job.
func (s *Store) Update(id string, fn func(*Job)) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	j, ok := s.jobs[id]
	if !ok {
		return false
	}
	fn(j)
	return true
}

// AppendLog adds text to job log.
func (s *Store) AppendLog(id, text string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	j, ok := s.jobs[id]
	if !ok {
		return
	}
	j.Log += text
}

// List returns jobs newest first.
func (s *Store) List() []*Job {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]*Job, 0, len(s.jobs))
	for _, j := range s.jobs {
		out = append(out, j)
	}
	for i := 0; i < len(out); i++ {
		for j := i + 1; j < len(out); j++ {
			if out[j].CreatedAt.After(out[i].CreatedAt) {
				out[i], out[j] = out[j], out[i]
			}
		}
	}
	return out
}
