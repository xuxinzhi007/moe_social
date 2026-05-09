package gift

import (
	"context"
	"strconv"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGiftRecordsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetGiftRecordsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGiftRecordsLogic {
	return &GetGiftRecordsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetGiftRecordsLogic) GetGiftRecords(req *types.GetGiftRecordsReq) (resp *types.GetGiftRecordsResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetGiftRecords(l.ctx, &super.GetGiftRecordsReq{
		UserId:   req.UserId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return nil, err
	}

	records := make([]types.GiftRecord, len(rpcResp.Records))
	for i, r := range rpcResp.Records {
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

		records[i] = types.GiftRecord{
			Id:        strconv.FormatUint(r.Id, 10),
			FromUserID: strconv.FormatUint(r.FromUserId, 10),
			ToUserID:   strconv.FormatUint(r.ToUserId, 10),
			GiftID:     strconv.FormatUint(r.GiftId, 10),
			Gift:       gift,
			Quantity:   int(r.Quantity),
			CreatedAt:  r.CreatedAt,
		}
	}

	return &types.GetGiftRecordsResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data:  records,
		Total: int(rpcResp.Total),
	}, nil
}
