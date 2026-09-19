package llmbiz

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"backend/pkg/llminference"
)

func (u *ManagedModels) Delete(ctx context.Context, owner uint, agent, requestID string) (ManagedModelView, error) {
	if err := u.writable(owner); err != nil {
		return ManagedModelView{}, err
	}
	if strings.TrimSpace(requestID) == "" || len(requestID) > 128 {
		return ManagedModelView{}, llmError(400, "删除必须携带 request_id")
	}
	release, err := u.acquire(owner, agent)
	if err != nil {
		return ManagedModelView{}, err
	}
	defer release()
	row, err := u.store.Get(ctx, owner, agent)
	if err != nil {
		return ManagedModelView{}, storeError(err)
	}
	if row.EndpointScope != u.scope {
		return ManagedModelView{}, llmError(409, "推理端点与原操作不同")
	}
	hash := digest("delete\n" + row.ManagedName)
	if err := rememberRequest(&row, requestID, "delete", hash); err != nil {
		if errors.Is(err, errReplay) {
			if row.State == "pending" || row.State == "deleting" {
				row.State = "unknown"
				row.Message = "上次写入未确认，请重查"
			}
			return u.view(row), nil
		}
		return ManagedModelView{}, err
	}
	if row.State == "pending" || row.State == "unknown" || row.State == "deleting" {
		return ManagedModelView{}, llmError(409, "未决操作必须先重查，不能删除")
	}
	if row.State == "deleted" {
		return u.view(row), nil
	}
	previous := row.RequestID
	row.RequestID = requestID
	row.Intent = "delete"
	row.IntentHash = hash
	row.State = "deleting"
	row.Message = "等待确认删除"
	if err := u.store.SaveIntent(ctx, &row, previous); err != nil {
		return ManagedModelView{}, storeError(err)
	}
	work, cancel := context.WithTimeout(ctx, time.Duration(u.limits.ModelSyncTimeoutSeconds)*time.Second)
	defer cancel()
	cfg := u.cfg
	cfg.Timeout = time.Duration(u.limits.ModelSyncTimeoutSeconds) * time.Second
	err = llminference.DeleteModel(work, cfg, row.ManagedName)
	if err != nil && !modelMissing(err) {
		return u.finishFailure(ctx, &row, err, true)
	}
	row.State = "deleted"
	row.Message = "模型已删除"
	row.BindingApplied = false
	return u.finish(ctx, &row, false)
}

func modelMissing(err error) bool {
	var upstream *llminference.UpstreamError
	return errors.As(err, &upstream) && upstream.StatusCode == 404
}

// Reconcile never resends a create/delete. Absence alone cannot disprove an unfinished create.
func (u *ManagedModels) Reconcile(ctx context.Context, owner uint, agent string) (ManagedModelView, error) {
	if err := u.writable(owner); err != nil {
		return ManagedModelView{}, err
	}
	release, err := u.acquire(owner, agent)
	if err != nil {
		return ManagedModelView{}, err
	}
	defer release()
	row, err := u.store.Get(ctx, owner, agent)
	if err != nil {
		return ManagedModelView{}, storeError(err)
	}
	if row.EndpointScope != u.scope {
		return ManagedModelView{}, llmError(409, "推理端点与原操作不同")
	}
	if row.State == "deleted" {
		return u.view(row), nil
	}
	work, cancel := context.WithTimeout(context.WithoutCancel(ctx), time.Duration(u.limits.ModelSyncTimeoutSeconds)*time.Second)
	defer cancel()
	cfg := u.cfg
	cfg.Timeout = time.Duration(u.limits.ModelSyncTimeoutSeconds) * time.Second
	info, showErr := llminference.ShowModel(work, cfg, row.ManagedName)
	confirmed := row.State == "ready"
	row.State = "unknown"
	row.Message = "尚无充分证据确认模型意图；请检查上游，勿重复写入"
	if row.Intent == "delete" {
		if modelMissing(showErr) {
			row.State = "deleted"
			row.Message = "已确认模型不存在"
			row.BindingApplied = false
		}
		return u.finish(ctx, &row, false)
	}
	if showErr != nil {
		if confirmed && modelMissing(showErr) {
			row.State = "failed"
			row.Message = "上游模型已不存在，可重新创建"
		}
		return u.finish(ctx, &row, false)
	}
	// A create that already returned success is trusted; re-checking its layers
	// could otherwise demote a healthy model when Ollama omits blob evidence.
	if confirmed {
		row.State = "ready"
		row.Message = "模型已就绪"
		return u.finish(ctx, &row, true)
	}
	var base llminference.ModelInfo
	if json.Unmarshal([]byte(row.BaseEvidence), &base) == nil && info.System == row.Prompt && matchingBase(base, info) {
		row.State = "ready"
		row.Message = "已核对上游意图"
		return u.finish(ctx, &row, true)
	}
	return u.finish(ctx, &row, false)
}

// A generated modelfile's content-addressed FROM/ADAPTER layers are evidence;
// a model name, details family, or a host filesystem path alone is not.
func layers(modelfile string) string {
	var result []string
	for _, line := range strings.Split(modelfile, "\n") {
		fields := strings.Fields(strings.TrimSpace(line))
		if len(fields) != 2 {
			continue
		}
		if fields[0] != "FROM" && fields[0] != "ADAPTER" {
			continue
		}
		ref := fields[1]
		idx := strings.LastIndex(ref, "sha256-")
		if idx < 0 {
			return ""
		}
		hash := ref[idx+7:]
		if len(hash) != 64 {
			return ""
		}
		for _, r := range hash {
			if !strings.ContainsRune("0123456789abcdef", r) {
				return ""
			}
		}
		result = append(result, fields[0]+" "+hash)
	}
	if len(result) == 0 || !strings.HasPrefix(result[0], "FROM ") {
		return ""
	}
	return strings.Join(result, "\n")
}
func matchingBase(base, derived llminference.ModelInfo) bool {
	baseLayers := layers(base.Modelfile)
	return baseLayers != "" && baseLayers == layers(derived.Modelfile) && base.Template != "" && base.Template == derived.Template && strings.TrimSpace(base.Parameters) == strings.TrimSpace(derived.Parameters)
}
