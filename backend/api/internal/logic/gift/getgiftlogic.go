package gift

import (
	"context"
	"strconv"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftLogic {
	return &GetGiftLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetGiftLogic) GetGift(req *types.GetGiftReq) (resp *types.GetGiftResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetGift(l.ctx, &super.GetGiftReq{
		GiftId: req.GiftId,
	})
	if err != nil {
		return nil, err
	}

	if !rpcResp.Success {
		return &types.GetGiftResp{
			BaseResp: types.BaseResp{
				Code:    1,
				Message: rpcResp.Message,
				Success: false,
			},
		}, nil
	}

	return &types.GetGiftResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: rpcResp.Message,
			Success: true,
		},
		Data: types.Gift{
			Id:          strconv.FormatUint(rpcResp.Gift.Id, 10),
			Name:        rpcResp.Gift.Name,
			Price:       int(rpcResp.Gift.Price),
			Icon:        rpcResp.Gift.Icon,
			Description: rpcResp.Gift.Description,
			CreatedAt:   rpcResp.Gift.CreatedAt,
			UpdatedAt:   rpcResp.Gift.UpdatedAt,
		},
	}, nil
}
