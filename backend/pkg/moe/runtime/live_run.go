package runtime

import (
	"strings"
	"sync"
	"time"
)

// LiveRuns 进程内试跑进行中状态（供管理台 SSE / pipeline 查询）。
var LiveRuns liveRunRegistry

type liveRunRegistry struct {
	mu   sync.Mutex
	by   map[string]*liveRunSession
	subs map[string]map[int]chan struct{}
	seq  int
}

type liveRunSession struct {
	agentKey    string
	startedAt   time.Time
	mu          sync.RWMutex
	steps       []RunStep
	genAttempts []GenAttemptRecord
	activeKey   string
	activeLabel string
}

// LiveRunSnapshot 试跑进行中的流水线视图。
type LiveRunSnapshot struct {
	AgentKey         string
	StartedAt        time.Time
	Steps            []RunStep
	ActiveKey        string
	ActiveLabel      string
	CurrentPhase     string
	GenerateAttempts []GenAttemptRecord
}

func (r *liveRunRegistry) init() {
	if r.by == nil {
		r.by = make(map[string]*liveRunSession)
	}
	if r.subs == nil {
		r.subs = make(map[string]map[int]chan struct{})
	}
}

// TryBegin 登记一次试跑；若该 agent 已在试跑中则返回 false。
func (r *liveRunRegistry) TryBegin(agentKey string) (*liveRunSession, bool) {
	key := strings.TrimSpace(agentKey)
	if key == "" {
		return nil, false
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.init()
	if _, ok := r.by[key]; ok {
		return nil, false
	}
	s := &liveRunSession{agentKey: key, startedAt: time.Now()}
	r.by[key] = s
	r.notifyLocked(key)
	return s, true
}

// Get 返回进行中的试跑会话（无则 nil）。
func (r *liveRunRegistry) Get(agentKey string) *liveRunSession {
	key := strings.TrimSpace(agentKey)
	if key == "" {
		return nil
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.init()
	return r.by[key]
}

// End 结束试跑登记并通知订阅方（通常为最终 DB 快照）。
func (r *liveRunRegistry) End(agentKey string) {
	key := strings.TrimSpace(agentKey)
	if key == "" {
		return
	}
	r.mu.Lock()
	r.init()
	delete(r.by, key)
	r.mu.Unlock()
	r.notify(key)
}

// IsRunning 是否正在试跑。
func (r *liveRunRegistry) IsRunning(agentKey string) bool {
	return r.Get(agentKey) != nil
}

// Subscribe 订阅某 agent 的流水线变更（SSE）；返回通知 channel 与取消函数。
func (r *liveRunRegistry) Subscribe(agentKey string) (<-chan struct{}, func()) {
	key := strings.TrimSpace(agentKey)
	ch := make(chan struct{}, 16)
	r.mu.Lock()
	r.init()
	r.seq++
	id := r.seq
	if r.subs[key] == nil {
		r.subs[key] = make(map[int]chan struct{})
	}
	r.subs[key][id] = ch
	r.mu.Unlock()
	unsub := func() {
		r.mu.Lock()
		defer r.mu.Unlock()
		if m, ok := r.subs[key]; ok {
			delete(m, id)
			if len(m) == 0 {
				delete(r.subs, key)
			}
		}
		close(ch)
	}
	return ch, unsub
}

func (r *liveRunRegistry) notify(agentKey string) {
	key := strings.TrimSpace(agentKey)
	r.mu.Lock()
	m := r.subs[key]
	chans := make([]chan struct{}, 0, len(m))
	for _, ch := range m {
		chans = append(chans, ch)
	}
	r.mu.Unlock()
	for _, ch := range chans {
		select {
		case ch <- struct{}{}:
		default:
		}
	}
}

func (r *liveRunRegistry) notifyLocked(agentKey string) {
	key := strings.TrimSpace(agentKey)
	m := r.subs[key]
	for _, ch := range m {
		select {
		case ch <- struct{}{}:
		default:
		}
	}
}

// SnapshotForAgent 返回进行中的试跑视图（无进行中的试跑则 ok=false）。
func (r *liveRunRegistry) SnapshotForAgent(agentKey string) (LiveRunSnapshot, bool) {
	s := r.Get(agentKey)
	if s == nil {
		return LiveRunSnapshot{}, false
	}
	return s.Snapshot(), true
}

// PipelineStepsForAgent 返回展示用步骤（含 running 中的当前步）。
func (r *liveRunRegistry) PipelineStepsForAgent(agentKey string) []RunStep {
	s := r.Get(agentKey)
	if s == nil {
		return nil
	}
	return s.PipelineSteps()
}

func (s *liveRunSession) touch() {
	if s == nil {
		return
	}
	LiveRuns.notify(s.agentKey)
}

func (s *liveRunSession) SetActive(key, label string) {
	if s == nil {
		return
	}
	s.mu.Lock()
	s.activeKey = strings.TrimSpace(key)
	s.activeLabel = strings.TrimSpace(label)
	s.mu.Unlock()
	s.touch()
}

func (s *liveRunSession) SyncSteps(steps []RunStep) {
	if s == nil {
		return
	}
	s.mu.Lock()
	s.steps = cloneRunSteps(steps)
	if s.activeKey != "" {
		for _, st := range s.steps {
			if st.Key == s.activeKey {
				s.activeKey = ""
				s.activeLabel = ""
				break
			}
		}
	}
	s.mu.Unlock()
	s.touch()
}

func (s *liveRunSession) SyncGenAttempts(attempts []GenAttemptRecord) {
	if s == nil || len(attempts) == 0 {
		return
	}
	s.mu.Lock()
	s.genAttempts = append([]GenAttemptRecord(nil), attempts...)
	s.mu.Unlock()
	s.touch()
}

func (s *liveRunSession) Snapshot() LiveRunSnapshot {
	if s == nil {
		return LiveRunSnapshot{}
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := LiveRunSnapshot{
		AgentKey:    s.agentKey,
		StartedAt:   s.startedAt,
		Steps:       cloneRunSteps(s.steps),
		ActiveKey:   s.activeKey,
		ActiveLabel: s.activeLabel,
	}
	if len(s.genAttempts) > 0 {
		out.GenerateAttempts = append([]GenAttemptRecord(nil), s.genAttempts...)
	}
	out.CurrentPhase = PhaseIDFromStepKey(out.ActiveKey)
	if out.CurrentPhase == "" && len(out.Steps) > 0 {
		out.CurrentPhase = PhaseIDFromStepKey(out.Steps[len(out.Steps)-1].Key)
	}
	return out
}

// PipelineSteps 返回展示用步骤（含当前进行中一步）。
func (s *liveRunSession) PipelineSteps() []RunStep {
	snap := s.Snapshot()
	out := snap.Steps
	if snap.ActiveKey != "" {
		out = append(out, RunStep{
			Key:    snap.ActiveKey,
			Label:  snap.ActiveLabel,
			Status: "running",
			Detail: "进行中",
		})
	}
	return out
}

func cloneRunSteps(in []RunStep) []RunStep {
	if len(in) == 0 {
		return nil
	}
	out := make([]RunStep, len(in))
	copy(out, in)
	return out
}
