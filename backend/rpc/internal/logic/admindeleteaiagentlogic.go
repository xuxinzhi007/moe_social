package logic

import (
	"context"
	"strings"

	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteAiAgentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteAiAgentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteAiAgentLogic {
	return &AdminDeleteAiAgentLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteAiAgentLogic) AdminDeleteAiAgent(in *super.AdminDeleteAiAgentReq) (*super.AdminDeleteAiAgentResp, error) {
	userID := strings.TrimSpace(in.GetUserId())
	agentID := strings.TrimSpace(in.GetAgentId())
	if userID == "" || agentID == "" {
		return nil, errorx.InvalidArgument("用户 ID 与角色 ID 不能为空")
	}
	_, err := NewAiResourcesLogic(l.ctx, l.svcCtx).delete("agents", &super.DeleteAiResourceReq{
		UserId: userID,
		Id:     agentID,
	})
	if err != nil {
		return nil, err
	}
	return &super.AdminDeleteAiAgentResp{}, nil
}
