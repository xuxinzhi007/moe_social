package gift

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type SendGiftLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSendGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendGiftLogic {
	return &SendGiftLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SendGiftLogic) SendGift(req *types.SendGiftReq) (resp *types.SendGiftResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.SendGift(l.ctx, &super.SendGiftReq{
		FromUserId: req.UserId,
		ToUserId:   req.ToUserId,
		GiftId:    req.GiftId,
		Quantity:  int32(req.Quantity),
	})
	if err != nil {
		return &types.SendGiftResp{
			BaseResp: types.BaseResp{
				Code:    1,
				Message: err.Error(),
				Success: false,
			},
		}, nil
	}

	return &types.SendGiftResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: rpcResp.Message,
			Success: rpcResp.Success,
		},
	}, nil
}
