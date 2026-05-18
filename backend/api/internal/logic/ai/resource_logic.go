package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ResourceLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewResourceLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ResourceLogic {
	return &ResourceLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ResourceLogic) list(userID uint, kind string) ([]map[string]interface{}, types.BaseResp) {
	req := &super.ListAiResourceReq{UserId: strconv.FormatUint(uint64(userID), 10)}
	var (
		resp *super.ListAiResourceResp
		err  error
	)

	switch kind {
	case "providers":
		resp, err = l.svcCtx.SuperRpcClient.ListAiProviders(l.ctx, req)
	case "agents":
		resp, err = l.svcCtx.SuperRpcClient.ListAiAgents(l.ctx, req)
	case "lorebooks":
		resp, err = l.svcCtx.SuperRpcClient.ListAiLorebooks(l.ctx, req)
	default:
		return []map[string]interface{}{}, common.HandleError(fmt.Errorf("unknown ai resource kind: %s", kind))
	}
	if err != nil {
		return []map[string]interface{}{}, common.HandleRPCError(err, "")
	}

	items := make([]map[string]interface{}, 0, len(resp.Items))
	for _, item := range resp.Items {
		items = append(items, decodeObject(item.GetPayloadJson()))
	}
	return items, common.HandleRPCError(nil, "操作成功")
}

func (l *ResourceLogic) upsert(userID uint, kind string, item map[string]interface{}) ([]map[string]interface{}, types.BaseResp) {
	id := stringify(item["id"])
	if id == "" {
		return []map[string]interface{}{}, common.HandleError(fmt.Errorf("missing resource id"))
	}
	raw, _ := json.Marshal(item)
	req := &super.UpsertAiResourceReq{
		UserId:      strconv.FormatUint(uint64(userID), 10),
		Id:          id,
		PayloadJson: string(raw),
	}

	var err error
	switch kind {
	case "providers":
		_, err = l.svcCtx.SuperRpcClient.UpsertAiProvider(l.ctx, req)
	case "agents":
		_, err = l.svcCtx.SuperRpcClient.UpsertAiAgent(l.ctx, req)
	case "lorebooks":
		_, err = l.svcCtx.SuperRpcClient.UpsertAiLorebook(l.ctx, req)
	default:
		return []map[string]interface{}{}, common.HandleError(fmt.Errorf("unknown ai resource kind: %s", kind))
	}
	if err != nil {
		return []map[string]interface{}{}, common.HandleRPCError(err, "")
	}

	return l.list(userID, kind)
}

func (l *ResourceLogic) delete(userID uint, kind, id string) ([]map[string]interface{}, types.BaseResp) {
	req := &super.DeleteAiResourceReq{
		UserId: strconv.FormatUint(uint64(userID), 10),
		Id:     id,
	}

	var err error
	switch kind {
	case "providers":
		_, err = l.svcCtx.SuperRpcClient.DeleteAiProvider(l.ctx, req)
	case "agents":
		_, err = l.svcCtx.SuperRpcClient.DeleteAiAgent(l.ctx, req)
	case "lorebooks":
		_, err = l.svcCtx.SuperRpcClient.DeleteAiLorebook(l.ctx, req)
	default:
		return []map[string]interface{}{}, common.HandleError(fmt.Errorf("unknown ai resource kind: %s", kind))
	}
	if err != nil {
		return []map[string]interface{}{}, common.HandleRPCError(err, "")
	}

	return l.list(userID, kind)
}

func decodeObject(raw string) map[string]interface{} {
	if raw == "" {
		return map[string]interface{}{}
	}
	var out map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return map[string]interface{}{}
	}
	return out
}

func stringify(v interface{}) string {
	if v == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(v))
}
