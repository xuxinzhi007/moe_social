package logic

import (
	"context"
	"fmt"

	aibiz "backend/internal/biz/ai"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AiUserConfigLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAiUserConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AiUserConfigLogic {
	return &AiUserConfigLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AiUserConfigLogic) Get(in *super.GetAiUserConfigReq) (*super.GetAiUserConfigResp, error) {
	resp, err := aibiz.GetAiUserConfig(l.ctx, l.svcCtx.DB, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		return nil, errorx.Internal(fmt.Sprintf("读取AI用户配置失败: %v", err))
	}
	return resp, nil
}

func (l *AiUserConfigLogic) Upsert(in *super.UpsertAiUserConfigReq) (*super.UpsertAiUserConfigResp, error) {
	resp, err := aibiz.UpsertAiUserConfig(l.ctx, l.svcCtx.DB, in)
	if err != nil {
		if mapped := mapAIResourceErr(err); mapped != nil {
			return nil, mapped
		}
		return nil, errorx.Internal(fmt.Sprintf("保存AI用户配置失败: %v", err))
	}
	return resp, nil
}
