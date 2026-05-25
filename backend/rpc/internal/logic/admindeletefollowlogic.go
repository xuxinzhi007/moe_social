package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteFollowLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteFollowLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteFollowLogic {
	return &AdminDeleteFollowLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteFollowLogic) AdminDeleteFollow(in *super.AdminDeleteFollowReq) (*super.AdminDeleteFollowResp, error) {
	id, err := strconv.ParseUint(strings.TrimSpace(in.GetFollowId()), 10, 64)
	if err != nil || id == 0 {
		return nil, errorx.InvalidArgument("关注 ID 无效")
	}
	if err := l.svcCtx.DB.Delete(&model.Follow{}, id).Error; err != nil {
		l.Errorf("[admin] delete follow: %v", err)
		return nil, errorx.Internal("删除关注失败")
	}
	return &super.AdminDeleteFollowResp{}, nil
}
