package moebiz

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"backend/model"
	"backend/pkg/moe/flowexec"

	"gorm.io/gorm"
)

const (
	maxFlowNodes = 80
	maxFlowEdges = 120
)

// FlowNode 画布节点。
type FlowNode struct {
	ID        string  `json:"id"`
	Type      string  `json:"type"`
	Kind      string  `json:"kind,omitempty"`
	Label     string  `json:"label"`
	Subtitle  string  `json:"subtitle,omitempty"`
	StepKey   string  `json:"step_key,omitempty"`
	ToolName  string  `json:"tool_name,omitempty"`
	PositionX float64 `json:"position_x"`
	PositionY float64 `json:"position_y"`
	Enabled   bool    `json:"enabled"`
	OnFail    string  `json:"on_fail,omitempty"`
	RetryMax  int     `json:"retry_max,omitempty"`
}

// FlowEdge 画布连线。
type FlowEdge struct {
	ID     string `json:"id"`
	Source string `json:"source"`
	Target string `json:"target"`
	Kind   string `json:"kind,omitempty"`
	Label  string `json:"label,omitempty"`
}

// FlowConfig 某 Bot 的完整画布配置。
type FlowConfig struct {
	AgentKey         string
	Version          int
	EntryNodeID      string
	Nodes            []FlowNode
	Edges            []FlowEdge
	ViewportZoom     float64
	ViewportX        float64
	ViewportY        float64
	UpdatedAt        time.Time
	IsDefault        bool
	CompileWarnings  []string
}

type flowLayoutPayload struct {
	Version     int        `json:"version"`
	EntryNodeID string     `json:"entry_node_id"`
	Nodes       []FlowNode `json:"nodes"`
	Edges       []FlowEdge `json:"edges"`
	Viewport    struct {
		Zoom float64 `json:"zoom"`
		X    float64 `json:"x"`
		Y    float64 `json:"y"`
	} `json:"viewport"`
}

// DefaultFlowConfig 默认能力 hub：中心 Bot，工具由管理台接入。
func DefaultFlowConfig(agentKey string) FlowConfig {
	_ = agentKey
	return FlowConfig{
		Version:      2,
		EntryNodeID:  "core",
		ViewportZoom: 1,
		IsDefault:    true,
		Nodes: []FlowNode{
			{ID: "core", Type: "core", Label: "Moe Bot", Subtitle: "主体 · 从左侧添加工具并连线接入", PositionX: 420, PositionY: 220, Enabled: true},
		},
		Edges: nil,
	}
}

// GetFlowConfig 读取画布；无记录时返回默认模板。
func GetFlowConfig(ctx context.Context, db *gorm.DB, agentKey string) (FlowConfig, error) {
	agentKey = strings.TrimSpace(agentKey)
	if agentKey == "" {
		return FlowConfig{}, errors.New("agent_key 不能为空")
	}
	var row model.MoeAgentFlowConfig
	err := db.WithContext(ctx).Where("agent_key = ?", agentKey).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		out := DefaultFlowConfig(agentKey)
		out.AgentKey = agentKey
		return out, nil
	}
	if err != nil {
		return FlowConfig{}, err
	}
	cfg, err := decodeFlowLayout(row.LayoutJSON)
	if err != nil {
		return FlowConfig{}, err
	}
	cfg.AgentKey = agentKey
	cfg.UpdatedAt = row.UpdatedAt
	cfg.IsDefault = false
	return cfg, nil
}

// UpsertFlowConfig 保存画布布局。
func UpsertFlowConfig(ctx context.Context, db *gorm.DB, agentKey string, in FlowConfig) (FlowConfig, error) {
	agentKey = strings.TrimSpace(agentKey)
	if agentKey == "" {
		return FlowConfig{}, errors.New("agent_key 不能为空")
	}
	if err := validateFlowConfig(in); err != nil {
		return FlowConfig{}, err
	}
	if isHubCapabilityLayout(in) {
		in.CompileWarnings = append(in.CompileWarnings, "能力图已保存；发帖试跑仍走内置流水线")
	} else {
		plan, compileErr := flowexec.Compile(FlowConfigToGraph(in))
		if compileErr != nil {
			return FlowConfig{}, compileErr
		}
		in.CompileWarnings = append(in.CompileWarnings, plan.Warnings...)
	}
	raw, err := encodeFlowLayout(in)
	if err != nil {
		return FlowConfig{}, err
	}
	var row model.MoeAgentFlowConfig
	err = db.WithContext(ctx).Where("agent_key = ?", agentKey).First(&row).Error
	switch {
	case errors.Is(err, gorm.ErrRecordNotFound):
		row = model.MoeAgentFlowConfig{AgentKey: agentKey, LayoutJSON: raw}
		if err := db.WithContext(ctx).Create(&row).Error; err != nil {
			return FlowConfig{}, err
		}
	case err != nil:
		return FlowConfig{}, err
	default:
		row.LayoutJSON = raw
		if err := db.WithContext(ctx).Save(&row).Error; err != nil {
			return FlowConfig{}, err
		}
	}
	out, err := decodeFlowLayout(row.LayoutJSON)
	if err != nil {
		return FlowConfig{}, err
	}
	out.AgentKey = agentKey
	out.UpdatedAt = row.UpdatedAt
	out.IsDefault = false
	return out, nil
}

// DeleteFlowConfig 删除已保存画布，后续 GET 回落默认模板。
func DeleteFlowConfig(ctx context.Context, db *gorm.DB, agentKey string) (FlowConfig, error) {
	agentKey = strings.TrimSpace(agentKey)
	if agentKey == "" {
		return FlowConfig{}, errors.New("agent_key 不能为空")
	}
	if err := db.WithContext(ctx).Where("agent_key = ?", agentKey).Delete(&model.MoeAgentFlowConfig{}).Error; err != nil {
		return FlowConfig{}, err
	}
	out := DefaultFlowConfig(agentKey)
	out.AgentKey = agentKey
	return out, nil
}

func isHubCapabilityLayout(in FlowConfig) bool {
	hasCore := false
	for _, n := range in.Nodes {
		if n.Type == "core" {
			hasCore = true
		}
		if n.Type == "step" {
			return false
		}
	}
	return hasCore
}

func validateFlowConfig(in FlowConfig) error {
	if len(in.Nodes) == 0 {
		return errors.New("nodes 不能为空")
	}
	if len(in.Nodes) > maxFlowNodes {
		return fmt.Errorf("nodes 超过上限 %d", maxFlowNodes)
	}
	if len(in.Edges) > maxFlowEdges {
		return fmt.Errorf("edges 超过上限 %d", maxFlowEdges)
	}
	ids := make(map[string]struct{}, len(in.Nodes))
	for _, n := range in.Nodes {
		id := strings.TrimSpace(n.ID)
		if id == "" {
			return errors.New("节点 id 不能为空")
		}
		if _, dup := ids[id]; dup {
			return fmt.Errorf("重复节点 id: %s", id)
		}
		ids[id] = struct{}{}
		t := strings.TrimSpace(n.Type)
		if t != "core" && t != "step" && t != "tool" {
			return fmt.Errorf("非法节点类型: %s", n.Type)
		}
		if t == "tool" && strings.TrimSpace(n.ToolName) == "" {
			return fmt.Errorf("工具节点 %s 缺少 tool_name", n.ID)
		}
	}
	for _, e := range in.Edges {
		if strings.TrimSpace(e.Source) == "" || strings.TrimSpace(e.Target) == "" {
			return errors.New("连线 source/target 不能为空")
		}
		if _, ok := ids[e.Source]; !ok {
			return fmt.Errorf("连线 source 不存在: %s", e.Source)
		}
		if _, ok := ids[e.Target]; !ok {
			return fmt.Errorf("连线 target 不存在: %s", e.Target)
		}
	}
	return nil
}

func encodeFlowLayout(in FlowConfig) (string, error) {
	var p flowLayoutPayload
	p.Version = in.Version
	if p.Version == 0 {
		p.Version = 2
	}
	p.EntryNodeID = in.EntryNodeID
	if p.EntryNodeID == "" {
		p.EntryNodeID = "core"
	}
	p.Nodes = in.Nodes
	p.Edges = in.Edges
	p.Viewport.Zoom = in.ViewportZoom
	p.Viewport.X = in.ViewportX
	p.Viewport.Y = in.ViewportY
	b, err := json.Marshal(p)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

func decodeFlowLayout(raw string) (FlowConfig, error) {
	var p flowLayoutPayload
	if err := json.Unmarshal([]byte(raw), &p); err != nil {
		return FlowConfig{}, err
	}
	if len(p.Nodes) == 0 {
		return FlowConfig{}, errors.New("layout_json 无节点")
	}
	for i := range p.Nodes {
		if p.Nodes[i].Type != "tool" {
			p.Nodes[i].Enabled = true
		}
	}
	return FlowConfig{
		Version:      p.Version,
		EntryNodeID:  p.EntryNodeID,
		Nodes:        p.Nodes,
		Edges:        p.Edges,
		ViewportZoom: p.Viewport.Zoom,
		ViewportX:    p.Viewport.X,
		ViewportY:    p.Viewport.Y,
	}, nil
}

