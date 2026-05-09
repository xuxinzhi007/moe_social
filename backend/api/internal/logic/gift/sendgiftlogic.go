package gift

import (
	"context"
	"strconv"

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

func rpcGiftRecordToAPI(r *super.GiftRecord) types.GiftRecord {
	if r == nil {
		return types.GiftRecord{}
	}
	var gift types.Gift
	if r.Gift != nil {
		gift = types.Gift{
			Id:          strconv.FormatUint(r.Gift.Id, 10),
			Name:        r.Gift.Name,
			Price:       int(r.Gift.Price),
			Icon:        r.Gift.Icon,
			Description: r.Gift.Description,
		}
	}
	return types.GiftRecord{
		Id:         strconv.FormatUint(r.Id, 10),
		FromUserID: strconv.FormatUint(r.FromUserId, 10),
		ToUserID:   strconv.FormatUint(r.ToUserId, 10),
		GiftID:     strconv.FormatUint(r.GiftId, 10),
		Gift:       gift,
		Quantity:   int(r.Quantity),
		CreatedAt:  r.CreatedAt,
	}
}

func (l *SendGiftLogic) SendGift(req *types.SendGiftReq) (resp *types.SendGiftResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.SendGift(l.ctx, &super.SendGiftReq{
		FromUserId: req.UserId,
		ToUserId:   req.ToUserId,
		GiftId:     req.GiftId,
		Quantity:   int32(req.Quantity),
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

	out := types.SendGiftResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: rpcResp.Message,
			Success: rpcResp.Success,
		},
	}
	if rpcResp.Success && rpcResp.Record != nil {
		out.Data = rpcGiftRecordToAPI(rpcResp.Record)
	}
	return &out, nil
}
