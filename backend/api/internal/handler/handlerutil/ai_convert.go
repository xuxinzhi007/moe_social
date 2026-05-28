package handlerutil

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
)

func aiList(ctx context.Context, svcCtx *svc.ServiceContext, userID uint, kind string) ([]map[string]interface{}, types.BaseResp) {
	req := &moe.ListAiResourceReq{UserId: strconv.FormatUint(uint64(userID), 10)}
	var (
		resp *moe.ListAiResourceResp
		err  error
	)

	switch kind {
	case "providers":
		resp, err = svcCtx.AIGW.ListAiProviders(ctx, req)
	case "agents":
		resp, err = svcCtx.AIGW.ListAiAgents(ctx, req)
	case "lorebooks":
		resp, err = svcCtx.AIGW.ListAiLorebooks(ctx, req)
	default:
		return []map[string]interface{}{}, common.HandleError(fmt.Errorf("unknown ai resource kind: %s", kind))
	}
	if err != nil {
		return []map[string]interface{}{}, common.HandleRPCError(err, "")
	}

	items := make([]map[string]interface{}, 0, len(resp.Items))
	for _, item := range resp.Items {
		items = append(items, aiDecodeObject(item.GetPayloadJson()))
	}
	return items, common.HandleRPCError(nil, "操作成功")
}

func aiUpsert(ctx context.Context, svcCtx *svc.ServiceContext, userID uint, kind string, item map[string]interface{}) ([]map[string]interface{}, types.BaseResp) {
	id := aiStringify(item["id"])
	if id == "" {
		return []map[string]interface{}{}, common.HandleError(fmt.Errorf("missing resource id"))
	}
	raw, err := json.Marshal(item)
	if err != nil {
		return []map[string]interface{}{}, common.HandleError(fmt.Errorf("marshal resource payload: %w", err))
	}
	req := &moe.UpsertAiResourceReq{
		UserId:      strconv.FormatUint(uint64(userID), 10),
		Id:          id,
		PayloadJson: string(raw),
	}

	var rpcErr error
	switch kind {
	case "providers":
		_, rpcErr = svcCtx.AIGW.UpsertAiProvider(ctx, req)
	case "agents":
		_, rpcErr = svcCtx.AIGW.UpsertAiAgent(ctx, req)
	case "lorebooks":
		_, rpcErr = svcCtx.AIGW.UpsertAiLorebook(ctx, req)
	default:
		return []map[string]interface{}{}, common.HandleError(fmt.Errorf("unknown ai resource kind: %s", kind))
	}
	if rpcErr != nil {
		return []map[string]interface{}{}, common.HandleRPCError(rpcErr, "")
	}

	return aiList(ctx, svcCtx, userID, kind)
}

func aiDelete(ctx context.Context, svcCtx *svc.ServiceContext, userID uint, kind, id string) ([]map[string]interface{}, types.BaseResp) {
	req := &moe.DeleteAiResourceReq{
		UserId: strconv.FormatUint(uint64(userID), 10),
		Id:     id,
	}

	var err error
	switch kind {
	case "providers":
		_, err = svcCtx.AIGW.DeleteAiProvider(ctx, req)
	case "agents":
		_, err = svcCtx.AIGW.DeleteAiAgent(ctx, req)
	case "lorebooks":
		_, err = svcCtx.AIGW.DeleteAiLorebook(ctx, req)
	default:
		return []map[string]interface{}{}, common.HandleError(fmt.Errorf("unknown ai resource kind: %s", kind))
	}
	if err != nil {
		return []map[string]interface{}{}, common.HandleRPCError(err, "")
	}

	return aiList(ctx, svcCtx, userID, kind)
}

func aiDecodeObject(raw string) map[string]interface{} {
	if raw == "" {
		return map[string]interface{}{}
	}
	var out map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return map[string]interface{}{}
	}
	return out
}

func aiStringify(v interface{}) string {
	if v == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(v))
}

func aiDecodeJSONObject(raw string) map[string]interface{} {
	return aiDecodeObject(raw)
}

// AIListProviders lists provider profiles for a user.
func AIListProviders(ctx context.Context, svcCtx *svc.ServiceContext, userID uint) (*types.AiProviderProfilesResp, error) {
	items, baseResp := aiList(ctx, svcCtx, userID, "providers")
	return &types.AiProviderProfilesResp{BaseResp: baseResp, Data: items}, nil
}

// AIUpsertProvider upserts a provider profile.
func AIUpsertProvider(ctx context.Context, svcCtx *svc.ServiceContext, userID uint, item map[string]interface{}) (*types.AiProviderProfilesResp, error) {
	items, baseResp := aiUpsert(ctx, svcCtx, userID, "providers", item)
	return &types.AiProviderProfilesResp{BaseResp: baseResp, Data: items}, nil
}

// AIDeleteProvider deletes a provider profile.
func AIDeleteProvider(ctx context.Context, svcCtx *svc.ServiceContext, userID uint, id string) (*types.AiProviderProfilesResp, error) {
	items, baseResp := aiDelete(ctx, svcCtx, userID, "providers", id)
	return &types.AiProviderProfilesResp{BaseResp: baseResp, Data: items}, nil
}

// AIListAgents lists agents for a user.
func AIListAgents(ctx context.Context, svcCtx *svc.ServiceContext, userID uint) (*types.AiAgentsResp, error) {
	items, baseResp := aiList(ctx, svcCtx, userID, "agents")
	return &types.AiAgentsResp{BaseResp: baseResp, Data: items}, nil
}

// AIUpsertAgent upserts an agent.
func AIUpsertAgent(ctx context.Context, svcCtx *svc.ServiceContext, userID uint, item map[string]interface{}) (*types.AiAgentsResp, error) {
	items, baseResp := aiUpsert(ctx, svcCtx, userID, "agents", item)
	return &types.AiAgentsResp{BaseResp: baseResp, Data: items}, nil
}

// AIDeleteAgent deletes an agent.
func AIDeleteAgent(ctx context.Context, svcCtx *svc.ServiceContext, userID uint, id string) (*types.AiAgentsResp, error) {
	items, baseResp := aiDelete(ctx, svcCtx, userID, "agents", id)
	return &types.AiAgentsResp{BaseResp: baseResp, Data: items}, nil
}

// AIListPublicAgents lists public agents.
func AIListPublicAgents(ctx context.Context, svcCtx *svc.ServiceContext, limit int32) (*types.AiAgentsResp, error) {
	resp, err := svcCtx.AIGW.ListPublicAiAgents(ctx, &moe.ListPublicAiAgentsReq{Limit: limit})
	if err != nil {
		return nil, err
	}
	items := make([]map[string]interface{}, 0, len(resp.Items))
	for _, item := range resp.Items {
		items = append(items, aiDecodeObject(item.GetPayloadJson()))
	}
	return &types.AiAgentsResp{
		BaseResp: common.HandleRPCError(nil, "操作成功"),
		Data:     items,
	}, nil
}

// AIListLorebooks lists lorebooks for a user.
func AIListLorebooks(ctx context.Context, svcCtx *svc.ServiceContext, userID uint) (*types.AiLorebooksResp, error) {
	items, baseResp := aiList(ctx, svcCtx, userID, "lorebooks")
	return &types.AiLorebooksResp{BaseResp: baseResp, Data: items}, nil
}

// AIUpsertLorebook upserts a lorebook.
func AIUpsertLorebook(
	ctx context.Context,
	svcCtx *svc.ServiceContext,
	userID uint,
	item map[string]interface{},
	entries []map[string]interface{},
) (*types.AiLorebooksResp, error) {
	if entries != nil {
		item["entries"] = entries
	}
	items, baseResp := aiUpsert(ctx, svcCtx, userID, "lorebooks", item)
	return &types.AiLorebooksResp{BaseResp: baseResp, Data: items}, nil
}

// AIDeleteLorebook deletes a lorebook.
func AIDeleteLorebook(ctx context.Context, svcCtx *svc.ServiceContext, userID uint, id string) (*types.AiLorebooksResp, error) {
	items, baseResp := aiDelete(ctx, svcCtx, userID, "lorebooks", id)
	return &types.AiLorebooksResp{BaseResp: baseResp, Data: items}, nil
}

// AIGetUserConfig returns ai user config.
func AIGetUserConfig(ctx context.Context, svcCtx *svc.ServiceContext, userID uint) (*types.AiUserConfigResp, error) {
	resp, err := svcCtx.LLMGW.GetAiUserConfig(ctx, &moe.GetAiUserConfigReq{
		UserId: strconv.FormatUint(uint64(userID), 10),
	})
	if err != nil {
		return &types.AiUserConfigResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	return &types.AiUserConfigResp{
		BaseResp: common.HandleRPCError(nil, "操作成功"),
		Data: types.AiUserConfigData{
			ProviderProfiles: []map[string]interface{}{},
			Agents:           []map[string]interface{}{},
			Lorebooks:        []map[string]interface{}{},
			UserPersona:      resp.UserPersona,
			Preferences:      aiDecodeJSONObject(resp.PreferencesJson),
		},
	}, nil
}

// AIUpsertUserConfig upserts ai user config.
func AIUpsertUserConfig(ctx context.Context, svcCtx *svc.ServiceContext, userID uint, req *types.AiUserConfigReq) (*types.AiUserConfigResp, error) {
	var preferencesJSON string
	if req.Preferences != nil {
		raw, err := json.Marshal(req.Preferences)
		if err != nil {
			return &types.AiUserConfigResp{
				BaseResp: common.HandleError(fmt.Errorf("marshal preferences: %w", err)),
			}, nil
		}
		preferencesJSON = string(raw)
	}
	resp, err := svcCtx.LLMGW.UpsertAiUserConfig(ctx, &moe.UpsertAiUserConfigReq{
		UserId:          strconv.FormatUint(uint64(userID), 10),
		UserPersona:     req.UserPersona,
		HasUserPersona:  req.HasUserPersona,
		PreferencesJson: preferencesJSON,
	})
	if err != nil {
		return &types.AiUserConfigResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	return &types.AiUserConfigResp{
		BaseResp: common.HandleRPCError(nil, "操作成功"),
		Data: types.AiUserConfigData{
			ProviderProfiles: []map[string]interface{}{},
			Agents:           []map[string]interface{}{},
			Lorebooks:        []map[string]interface{}{},
			UserPersona:      resp.UserPersona,
			Preferences:      aiDecodeJSONObject(resp.PreferencesJson),
		},
	}, nil
}
