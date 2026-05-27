package ai

import (
	"context"
	"strconv"

	"backend/api/internal/common"
	llmlogic "backend/api/internal/logic/llm"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type PutAiMemorySettingsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewPutAiMemorySettingsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *PutAiMemorySettingsLogic {
	return &PutAiMemorySettingsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *PutAiMemorySettingsLogic) PutAiMemorySettings(req *types.AiMemorySettingsReq) (*types.AiMemorySettingsResp, error) {
	userID, err := common.UserIDUint(l.ctx)
	if err != nil {
		return nil, err
	}
	uid := strconv.FormatUint(uint64(userID), 10)
	existing := map[string]interface{}{}
	if l.svcCtx.SuperRpcClient != nil {
		if cur, err := l.svcCtx.SuperRpcClient.GetAiUserConfig(l.ctx, &super.GetAiUserConfigReq{UserId: uid}); err == nil && cur != nil {
			existing = decodePrefsMap(cur.GetPreferencesJson())
		}
	}
	prefsJSON := llmlogic.MergeMemoryAutoLearnPref(existing, req.AutoLearn)
	if l.svcCtx.SuperRpcClient == nil {
		return &types.AiMemorySettingsResp{BaseResp: common.HandleError(nil), Data: types.AiMemorySettingsData{AutoLearn: req.AutoLearn}}, nil
	}
	_, rpcErr := l.svcCtx.SuperRpcClient.UpsertAiUserConfig(l.ctx, &super.UpsertAiUserConfigReq{
		UserId:          uid,
		PreferencesJson: prefsJSON,
	})
	if rpcErr != nil {
		return &types.AiMemorySettingsResp{BaseResp: common.HandleRPCError(rpcErr, "")}, nil
	}
	return &types.AiMemorySettingsResp{
		BaseResp: common.HandleError(nil),
		Data:     types.AiMemorySettingsData{AutoLearn: req.AutoLearn},
	}, nil
}

func decodePrefsMap(raw string) map[string]interface{} {
	return llmlogic.DecodePreferencesJSON(raw)
}
