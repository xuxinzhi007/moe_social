package ai

import (
	"backend/api/internal/common"
	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

func (l *ResourceLogic) ListAgents(userID uint) (*types.AiAgentsResp, error) {
	items, baseResp := l.list(userID, "agents")
	return &types.AiAgentsResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}

func (l *ResourceLogic) UpsertAgent(userID uint, item map[string]interface{}) (*types.AiAgentsResp, error) {
	items, baseResp := l.upsert(userID, "agents", item)
	return &types.AiAgentsResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}

func (l *ResourceLogic) DeleteAgent(userID uint, id string) (*types.AiAgentsResp, error) {
	items, baseResp := l.delete(userID, "agents", id)
	return &types.AiAgentsResp{
		BaseResp: baseResp,
		Data:     items,
	}, nil
}

func (l *ResourceLogic) ListPublicAgents(limit int32) (*types.AiAgentsResp, error) {
	resp, err := l.svcCtx.AIGW.ListPublicAiAgents(l.ctx, &super.ListPublicAiAgentsReq{
		Limit: limit,
	})
	if err != nil {
		return nil, err
	}
	items := make([]map[string]interface{}, 0, len(resp.Items))
	for _, item := range resp.Items {
		items = append(items, decodeObject(item.GetPayloadJson()))
	}
	return &types.AiAgentsResp{
		BaseResp: common.HandleRPCError(nil, "操作成功"),
		Data:     items,
	}, nil
}
