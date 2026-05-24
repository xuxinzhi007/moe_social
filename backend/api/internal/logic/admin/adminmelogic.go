// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminMeLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminMeLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminMeLogic {
	return &AdminMeLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminMeLogic) AdminMe(claims *utils.AdminClaims) (resp *types.AdminMeResp, err error) {
	if claims == nil {
		return &types.AdminMeResp{
			BaseResp: types.BaseResp{
				Code:    401,
				Message: "请先登录管理后台",
				Success: false,
			},
		}, nil
	}
	return &types.AdminMeResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminMeData{
			AdminId:  uint64(claims.AdminID),
			Username: claims.Username,
			Role:     claims.Role,
		},
	}, nil
}
