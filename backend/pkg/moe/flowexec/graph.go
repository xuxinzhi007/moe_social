package flowexec

// GraphNode 编排图节点（与 layout_json 对齐，避免 pkg 依赖 internal）。
type GraphNode struct {
	ID        string
	Type      string // core | step | tool
	Kind      string // load_runtime | gather_memory | llm_generate | ...
	StepKey   string
	ToolName  string
	Label     string
	Enabled   bool
	OnFail    string
	RetryMax  int
}

// GraphEdge 编排图边。
type GraphEdge struct {
	ID     string
	Source string
	Target string
	Kind   string // default | on_ok | on_fail
}

// Graph 可执行编排图输入。
type Graph struct {
	Version     int
	EntryNodeID string
	Nodes       []GraphNode
	Edges       []GraphEdge
}

// Plan 线性执行计划（E1）。
type Plan struct {
	Nodes    []GraphNode
	Warnings []string
}
