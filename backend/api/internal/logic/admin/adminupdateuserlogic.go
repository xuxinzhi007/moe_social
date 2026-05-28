// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin

import (
	"context"
	"fmt"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateUserLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateUserLogic {
	return &AdminUpdateUserLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminUpdateUserLogic) AdminUpdateUser(req *types.AdminUpdateUserReq) (*types.AdminUpdateUserResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminUpdateUser(l.ctx, &moe.AdminUpdateUserReq{
		UserId:          req.UserId,
		Role:            req.Role,
		IsVip:           req.IsVip,
		UpdateIsVip:     req.UpdateIsVip,
		Signature:       req.Signature,
		UpdateSignature: req.UpdateSignature,
		Avatar:          req.Avatar,
		UpdateAvatar:    req.UpdateAvatar,
	})
	if err != nil {
		return &types.AdminUpdateUserResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	resp := &types.AdminUpdateUserResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcUserToTypes(rpcResp.User),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "user", fmt.Sprintf("%d", req.UserId), "更新 App 用户")
	}
	return resp, nil
}
