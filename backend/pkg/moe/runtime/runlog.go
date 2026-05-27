package runtime

import (
	"encoding/json"
	"strings"
	"time"

	"backend/model"

	"gorm.io/gorm"
)

// RunStep 管理台展示的单步状态。
type RunStep struct {
	Key    string `json:"key"`
	Label  string `json:"label"`
	Status string `json:"status"` // ok | fail | skip | running
	Detail string `json:"detail,omitempty"`
	MS     int64  `json:"ms,omitempty"`
}

// RunLogBundle 持久化到 StepsJSON（兼容旧版纯数组格式）。
type RunLogBundle struct {
	Steps            []RunStep          `json:"steps"`
	TotalMs          int64              `json:"total_ms"`
	Metrics          HostMetrics        `json:"metrics,omitempty"`
	GenerateAttempts []GenAttemptRecord `json:"generate_attempts,omitempty"`
}

// StepRecorder 记录 Bot 发帖流水线步骤与耗时。
type StepRecorder struct {
	steps    []RunStep
	clock    func() time.Time
	runStart time.Time
}

func NewStepRecorder() *StepRecorder {
	now := time.Now()
	return &StepRecorder{
		clock:    time.Now,
		runStart: now,
	}
}

// Add 追加一步并记录距上一步的耗时（首步为距 RunOnce 开始的耗时）。
func (r *StepRecorder) Add(key, label, status, detail string, stepDur time.Duration) {
	if r == nil {
		return
	}
	ms := stepDur.Milliseconds()
	if ms < 0 {
		ms = 0
	}
	r.steps = append(r.steps, RunStep{
		Key:    strings.TrimSpace(key),
		Label:  strings.TrimSpace(label),
		Status: strings.TrimSpace(status),
		Detail: strings.TrimSpace(detail),
		MS:     ms,
	})
}

func (r *StepRecorder) Steps() []RunStep {
	if r == nil {
		return nil
	}
	out := make([]RunStep, len(r.steps))
	copy(out, r.steps)
	return out
}

func (r *StepRecorder) TotalMs() int64 {
	if r == nil {
		return 0
	}
	return time.Since(r.runStart).Milliseconds()
}

func (r *StepRecorder) Bundle(metrics HostMetrics) RunLogBundle {
	return RunLogBundle{
		Steps:   r.Steps(),
		TotalMs: r.TotalMs(),
		Metrics: metrics,
	}
}

// SaveAgentRunLog 持久化最近一次试跑步骤与环境指标。
func SaveAgentRunLog(db *gorm.DB, agentKey string, ok bool, detail, postID string, bundle RunLogBundle) error {
	if db == nil || strings.TrimSpace(agentKey) == "" {
		return nil
	}
	if bundle.TotalMs <= 0 && len(bundle.Steps) > 0 {
		var sum int64
		for _, s := range bundle.Steps {
			sum += s.MS
		}
		bundle.TotalMs = sum
	}
	raw, err := json.Marshal(bundle)
	if err != nil {
		raw = []byte("[]")
	}
	row := model.MoeAgentRunLog{
		AgentKey:  strings.TrimSpace(agentKey),
		OK:        ok,
		Detail:    strings.TrimSpace(detail),
		PostID:    strings.TrimSpace(postID),
		StepsJSON: string(raw),
		CreatedAt: time.Now(),
	}
	return db.Create(&row).Error
}

// LatestAgentRunLog 读取某 Bot 最近一次运行日志。
func LatestAgentRunLog(db *gorm.DB, agentKey string) (*model.MoeAgentRunLog, error) {
	if db == nil {
		return nil, gorm.ErrRecordNotFound
	}
	var row model.MoeAgentRunLog
	err := db.Where("agent_key = ?", strings.TrimSpace(agentKey)).
		Order("created_at desc").
		First(&row).Error
	if err != nil {
		return nil, err
	}
	return &row, nil
}

// ParseRunLog 解析 StepsJSON（支持 bundle 或历史 steps 数组）。
func ParseRunLog(raw string) RunLogBundle {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return RunLogBundle{}
	}
	if strings.HasPrefix(raw, "{") {
		var bundle RunLogBundle
		if err := json.Unmarshal([]byte(raw), &bundle); err == nil {
			return bundle
		}
	}
	var steps []RunStep
	if err := json.Unmarshal([]byte(raw), &steps); err == nil {
		var sum int64
		for _, s := range steps {
			sum += s.MS
		}
		return RunLogBundle{Steps: steps, TotalMs: sum}
	}
	return RunLogBundle{}
}

// ParseRunSteps 兼容旧调用方。
func ParseRunSteps(raw string) []RunStep {
	return ParseRunLog(raw).Steps
}
