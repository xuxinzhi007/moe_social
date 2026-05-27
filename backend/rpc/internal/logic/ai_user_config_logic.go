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
	userID, err := aibiz.ParseUserID(in.UserId)
	if err != nil {
		return nil, mapAIResourceErr(err)
	}
	cfg, err := aibiz.LoadOrCreateConfig(l.svcCtx.DB, userID)
	if err != nil {
		return nil, errorx.Internal(fmt.Sprintf("读取AI用户配置失败: %v", err))
	}
	return &super.GetAiUserConfigResp{
		UserPersona:     cfg.UserPersona,
		PreferencesJson: cfg.PreferencesJSON,
	}, nil
}

func (l *AiUserConfigLogic) Upsert(in *super.UpsertAiUserConfigReq) (*super.UpsertAiUserConfigResp, error) {
	userID, err := aibiz.ParseUserID(in.UserId)
	if err != nil {
		return nil, mapAIResourceErr(err)
	}
	cfg, err := aibiz.LoadOrCreateConfig(l.svcCtx.DB, userID)
	if err != nil {
		return nil, errorx.Internal(fmt.Sprintf("读取AI用户配置失败: %v", err))
	}
	if in.HasUserPersona {
		cfg.UserPersona = in.UserPersona
	}
	if in.PreferencesJson != "" {
		cfg.PreferencesJSON = in.PreferencesJson
	}
	if err := l.svcCtx.DB.Save(cfg).Error; err != nil {
		return nil, errorx.Internal(fmt.Sprintf("保存AI用户配置失败: %v", err))
	}
	return &super.UpsertAiUserConfigResp{
		UserPersona:     cfg.UserPersona,
		PreferencesJson: cfg.PreferencesJSON,
	}, nil
}
