// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteMyAccountLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewDeleteMyAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteMyAccountLogic {
	return &DeleteMyAccountLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *DeleteMyAccountLogic) DeleteMyAccount(req *types.EmptyReq) (resp *types.DeleteUserResp, err error) {
	userID, err := common.UserIDString(l.ctx)
	if err != nil {
		return nil, err
	}

	_, err = l.svcCtx.SuperRpcClient.DeleteUser(l.ctx, &super.DeleteUserReq{
		UserId: userID,
	})
	if err != nil {
		return &types.DeleteUserResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.DeleteUserResp{
		BaseResp: common.HandleRPCError(nil, "账号已注销"),
	}, nil
}
