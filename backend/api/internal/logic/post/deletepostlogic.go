package post

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeletePostLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewDeletePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeletePostLogic {
	return &DeletePostLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *DeletePostLogic) DeletePost(req *types.DeletePostReq) (resp *types.DeletePostResp, err error) {
	_, err = l.svcCtx.SuperRpcClient.DeletePost(l.ctx, &super.DeletePostReq{
		PostId: req.PostId,
		UserId: req.UserId,
	})
	if err != nil {
		return &types.DeletePostResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.DeletePostResp{BaseResp: common.HandleRPCError(nil, "删除成功")}, nil
}
