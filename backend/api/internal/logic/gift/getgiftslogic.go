package gift

import (
	"context"
	"strconv"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftsLogic {
	return &GetGiftsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetGiftsLogic) GetGifts(req *types.GetGiftsReq) (resp *types.GetGiftsResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetGifts(l.ctx, &super.GetGiftsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return nil, err
	}

	gifts := make([]types.Gift, len(rpcResp.Gifts))
	for i, g := range rpcResp.Gifts {
		gifts[i] = types.Gift{
			Id:          strconv.FormatUint(g.Id, 10),
			Name:        g.Name,
			Price:       int(g.Price),
			Icon:        g.Icon,
			Description: g.Description,
			CreatedAt:   g.CreatedAt,
			UpdatedAt:   g.UpdatedAt,
		}
	}

	return &types.GetGiftsResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data:  gifts,
		Total: int(rpcResp.Total),
	}, nil
}
