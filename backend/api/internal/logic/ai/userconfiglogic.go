package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type UserConfigLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUserConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UserConfigLogic {
	return &UserConfigLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UserConfigLogic) Get(userID uint) (*types.AiUserConfigResp, error) {
	resp, err := l.svcCtx.LLMGW.GetAiUserConfig(l.ctx, &moe.GetAiUserConfigReq{
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
			Preferences:      decodeJSONObject(resp.PreferencesJson),
		},
	}, nil
}

func (l *UserConfigLogic) Upsert(userID uint, req *types.AiUserConfigReq) (*types.AiUserConfigResp, error) {
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
	resp, err := l.svcCtx.LLMGW.UpsertAiUserConfig(l.ctx, &moe.UpsertAiUserConfigReq{
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
			Preferences:      decodeJSONObject(resp.PreferencesJson),
		},
	}, nil
}

func decodeJSONObject(raw string) map[string]interface{} {
	if raw == "" {
		return map[string]interface{}{}
	}
	var out map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return map[string]interface{}{}
	}
	return out
}
