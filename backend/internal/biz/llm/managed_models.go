package llmbiz

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"sync"
	"time"

	"backend/model"
	"backend/pkg/conf"
	"backend/pkg/llminference"
	kerrors "github.com/go-kratos/kratos/v2/errors"
	"gorm.io/gorm"
)

const ManagedPrefix = "moe-user-"

// ManagedModelView intentionally omits owner IDs, prompt and internal evidence.
type ManagedModelView struct {
	AgentID, ModelName, BaseModel, State, RequestID, Message string
	BindingApplied                                           bool
	Retryable                                                bool
}

// ManagedStore is the transactional ownership ledger consumed by the usecase.
type ManagedStore interface {
	Get(context.Context, uint, string) (model.LLMManagedModel, error)
	List(context.Context, uint) ([]model.LLMManagedModel, error)
	ByName(context.Context, string) (model.LLMManagedModel, error)
	Reserve(context.Context, uint, string, func(*model.LLMManagedModel, map[string]any, int64, int64) error) (model.LLMManagedModel, error)
	Finish(context.Context, *model.LLMManagedModel, bool) error
	SaveIntent(context.Context, *model.LLMManagedModel, string) error
}

// ManagedModels coordinates single-process model writes. Every service shares the coordinator.
type ManagedModels struct {
	store  ManagedStore
	cfg    llminference.Config
	limits conf.ModelManagement
	scope  string
}

var writes = struct {
	sync.Mutex
	active map[string]bool
	count  int
}{active: make(map[string]bool)}
var validBase = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,255}$`)
var errReplay = errors.New("idempotent replay")

func NewManagedModels(store ManagedStore, cfg llminference.Config, limits conf.ModelManagement) *ManagedModels {
	scope := digest(strings.TrimRight(cfg.BaseURL, "/") + "\n" + string(cfg.APIStyle))
	return &ManagedModels{store: store, cfg: cfg, limits: conf.NormalizeModelManagement(limits, cfg.DefaultModel), scope: scope}
}
func digest(v string) string                  { s := sha256.Sum256([]byte(v)); return hex.EncodeToString(s[:]) }
func llmError(code int, message string) error { return kerrors.New(code, "LLM_MODEL", message) }
func storeError(err error) error {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return llmError(404, "角色卡或受管模型不存在")
	}
	var ke *kerrors.Error
	if errors.As(err, &ke) {
		return err
	}
	return llmError(503, "模型状态存储不可用")
}
func (u *ManagedModels) key(owner uint, agent string) string {
	return fmt.Sprintf("%s/%d/%s", u.scope, owner, agent)
}
func (u *ManagedModels) acquire(owner uint, agent string) (func(), error) {
	writes.Lock()
	defer writes.Unlock()
	key := u.key(owner, agent)
	if writes.active[key] {
		return nil, llmError(409, "该角色有正在执行的模型操作")
	}
	if writes.count >= u.limits.WriteConcurrency {
		return nil, llmError(429, "模型写入繁忙，请稍后重试")
	}
	writes.active[key] = true
	writes.count++
	return func() { writes.Lock(); delete(writes.active, key); writes.count--; writes.Unlock() }, nil
}
func (u *ManagedModels) active(row model.LLMManagedModel) bool {
	writes.Lock()
	defer writes.Unlock()
	return writes.active[u.key(row.OwnerID, row.AgentID)]
}
func (u *ManagedModels) view(row model.LLMManagedModel) ManagedModelView {
	state := row.State
	msg := row.Message
	if (state == "pending" || state == "deleting") && !u.active(row) {
		state = "unknown"
		msg = "上次写入结果未确认，请重查；不要重新提交创建"
	}
	if row.EndpointScope != u.scope {
		state = "unknown"
		msg = "推理端点已变更，须恢复原端点后处理"
	}
	return ManagedModelView{AgentID: row.AgentID, ModelName: row.ManagedName, BaseModel: row.BaseModel, State: state, RequestID: row.RequestID, Message: msg, BindingApplied: row.BindingApplied, Retryable: state == "failed"}
}
func (u *ManagedModels) available(owner uint) error {
	if owner == 0 {
		return llmError(401, "请先登录")
	}
	if u == nil || u.store == nil {
		return llmError(503, "模型所有权存储不可用")
	}
	return nil
}
func (u *ManagedModels) writable(owner uint) error {
	if err := u.available(owner); err != nil {
		return err
	}
	if !u.cfg.Ready() {
		return llmError(503, "推理未配置")
	}
	if string(u.cfg.APIStyle) != "ollama" {
		return llmError(400, "当前协议不支持模型管理")
	}
	return nil
}
func (u *ManagedModels) AllowedBase(name string) bool {
	if !validBase.MatchString(name) || strings.HasPrefix(strings.ToLower(name), ManagedPrefix) || strings.Contains(name, "..") || strings.Contains(name, "sha256") || strings.HasPrefix(name, "/") || strings.Contains(name, "://") {
		return false
	}
	for _, base := range u.limits.AllowedBaseModels {
		if name == strings.TrimSpace(base) {
			return true
		}
	}
	return false
}

func (u *ManagedModels) Upsert(ctx context.Context, owner uint, in CreateAgentInput) (ManagedModelView, error) {
	if err := u.writable(owner); err != nil {
		return ManagedModelView{}, err
	}
	in.AgentID = strings.TrimSpace(in.AgentID)
	in.RequestID = strings.TrimSpace(in.RequestID)
	in.BaseModel = strings.TrimSpace(in.BaseModel)
	if in.AgentID == "" || len(in.AgentID) > 128 || in.RequestID == "" || len(in.RequestID) > 128 || len(in.SystemPrompt) > 65536 {
		return ManagedModelView{}, llmError(400, "需要有效的 agent_id、request_id 和受限提示词")
	}
	if !u.AllowedBase(in.BaseModel) {
		return ManagedModelView{}, llmError(403, "不允许使用此基座")
	}
	release, err := u.acquire(owner, in.AgentID)
	if err != nil {
		return ManagedModelView{}, err
	}
	defer release()
	intentBytes, _ := json.Marshal([]string{in.AgentID, in.BaseModel, in.SystemPrompt, u.scope})
	hash := digest(string(intentBytes))
	row, err := u.store.Reserve(ctx, owner, in.AgentID, func(row *model.LLMManagedModel, card map[string]any, users, global int64) error {
		if row.ID != 0 {
			if row.EndpointScope != u.scope {
				return llmError(409, "受管模型属于其他推理端点")
			}
			if err := rememberRequest(row, in.RequestID, "create", hash); err != nil {
				return err
			}
			if row.State == "pending" || row.State == "unknown" || row.State == "deleting" {
				return llmError(409, "未决操作必须先重查")
			}
		}
		if row.ID == 0 || row.State == "deleted" {
			if users >= int64(u.limits.UserQuota) || global >= int64(u.limits.GlobalQuota) {
				return llmError(429, "受管模型配额已满")
			}
		}
		if row.ID == 0 {
			if err := rememberRequest(row, in.RequestID, "create", hash); err != nil {
				return err
			}
			b := make([]byte, 20)
			if _, err := rand.Read(b); err != nil {
				return err
			}
			row.ManagedName = ManagedPrefix + hex.EncodeToString(b) + ":latest"
		}
		snapshot, err := json.Marshal(card)
		if err != nil {
			return err
		}
		row.OwnerID = owner
		row.AgentID = in.AgentID
		row.EndpointScope = u.scope
		row.BaseModel = in.BaseModel
		row.Prompt = in.SystemPrompt
		row.CardSnapshot = string(snapshot)
		row.RequestID = in.RequestID
		row.IntentHash = hash
		row.Intent = "create"
		row.State = "pending"
		row.Message = ""
		row.BindingApplied = false
		row.BaseEvidence = ""
		return nil
	})
	if errors.Is(err, errReplay) {
		if row.State == "pending" || row.State == "deleting" {
			row.State = "unknown"
			row.Message = "上次写入未确认，请重查"
		}
		return u.view(row), nil
	}
	if err != nil {
		return ManagedModelView{}, storeError(err)
	}
	work, cancel := context.WithTimeout(ctx, time.Duration(u.limits.ModelSyncTimeoutSeconds)*time.Second)
	defer cancel()
	cfg := u.cfg
	cfg.Timeout = time.Duration(u.limits.ModelSyncTimeoutSeconds) * time.Second
	base, err := llminference.ShowModel(work, cfg, row.BaseModel)
	if err != nil {
		return u.finishFailure(ctx, &row, err, false)
	}
	evidence, err := json.Marshal(base)
	if err != nil {
		return u.finishFailure(ctx, &row, err, false)
	}
	row.BaseEvidence = string(evidence)
	if err = u.store.Finish(work, &row, false); err != nil {
		return ManagedModelView{}, storeError(err)
	}
	err = llminference.CreateModel(work, cfg, row.ManagedName, row.BaseModel, row.Prompt)
	if err != nil {
		return u.finishFailure(ctx, &row, err, true)
	}
	row.State = "ready"
	row.Message = "模型已就绪"
	return u.finish(ctx, &row, true)
}

// Persist outcomes even when the client canceled, with a bounded independent DB context.
func (u *ManagedModels) finish(ctx context.Context, row *model.LLMManagedModel, bind bool) (ManagedModelView, error) {
	persist, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
	defer cancel()
	if err := u.store.Finish(persist, row, bind); err != nil {
		return ManagedModelView{}, storeError(err)
	}
	if bind && !row.BindingApplied {
		row.Message = "模型已就绪，但角色已变更，未覆盖绑定"
	}
	return u.view(*row), nil
}
func (u *ManagedModels) finishFailure(ctx context.Context, row *model.LLMManagedModel, cause error, sent bool) (ManagedModelView, error) {
	row.State = "failed"
	row.Message = "上游拒绝操作；可使用新的请求 ID 重试"
	var upstream *llminference.UpstreamError
	uncertain := sent
	if errors.As(cause, &upstream) {
		uncertain = sent && upstream.Uncertain
	}
	if uncertain {
		row.State = "unknown"
		row.Message = "上游结果未知，请重查，不要重复创建"
	}
	view, err := u.finish(ctx, row, false)
	if err != nil {
		return view, err
	}
	if uncertain {
		return view, nil
	}
	return view, UpstreamStatusError(cause)
}

// UpstreamStatusError maps dependency failures to real non-2xx transport errors.
func UpstreamStatusError(err error) error {
	if errors.Is(err, context.DeadlineExceeded) {
		return llmError(504, "推理服务超时")
	}
	var upstream *llminference.UpstreamError
	if errors.As(err, &upstream) {
		switch upstream.StatusCode {
		case 404:
			return llmError(404, "上游模型不存在")
		case 400:
			return llmError(400, "上游拒绝模型请求")
		case 429:
			return llmError(429, "上游繁忙")
		case 504:
			return llmError(504, "推理服务超时")
		}
	}
	return llmError(503, "推理服务不可用")
}
func (u *ManagedModels) List(ctx context.Context, owner uint) ([]ManagedModelView, error) {
	if err := u.available(owner); err != nil {
		return nil, err
	}
	rows, err := u.store.List(ctx, owner)
	if err != nil {
		return nil, storeError(err)
	}
	views := make([]ManagedModelView, 0, len(rows))
	for _, r := range rows {
		views = append(views, u.view(r))
	}
	return views, nil
}
func (u *ManagedModels) Get(ctx context.Context, owner uint, agent string) (ManagedModelView, error) {
	if err := u.available(owner); err != nil {
		return ManagedModelView{}, err
	}
	r, err := u.store.Get(ctx, owner, agent)
	if err != nil {
		return ManagedModelView{}, storeError(err)
	}
	return u.view(r), nil
}

// Authorize protects every inference entrypoint, including anonymous reads.
func (u *ManagedModels) Authorize(ctx context.Context, owner uint, name string) error {
	if u.AllowedBase(name) {
		return nil
	}
	if owner == 0 {
		return llmError(403, "模型不可访问")
	}
	if u.store == nil {
		return llmError(503, "模型所有权存储不可用")
	}
	row, err := u.store.ByName(ctx, name)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return llmError(403, "模型不可访问")
		}
		return storeError(err)
	}
	if row.OwnerID != owner || row.EndpointScope != u.scope || row.State != "ready" {
		return llmError(403, "模型不可访问或未就绪")
	}
	return nil
}
func (u *ManagedModels) ListModels(ctx context.Context, owner uint) ([]string, error) {
	names, err := llminference.ListModels(ctx, u.cfg)
	if err != nil {
		return nil, UpstreamStatusError(err)
	}
	allowed := make(map[string]bool)
	if owner != 0 && u.store != nil {
		rows, err := u.store.List(ctx, owner)
		if err != nil {
			return nil, storeError(err)
		}
		for _, row := range rows {
			if row.State == "ready" && row.EndpointScope == u.scope {
				allowed[row.ManagedName] = true
			}
		}
	}
	result := []string{}
	for _, name := range names {
		if u.AllowedBase(name) || allowed[name] {
			result = append(result, name)
		}
	}
	return result, nil
}
