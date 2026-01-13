package avatar

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetAvatarOutfitLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetAvatarOutfitLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetAvatarOutfitLogic {
	return &GetAvatarOutfitLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetAvatarOutfitLogic) GetAvatarOutfit(req *types.GetAvatarOutfitReq) (resp *types.GetAvatarOutfitResp, err error) {
	// 模拟获取单个装扮物品详情
	// 实际项目中应该调用RPC服务或数据库查询

	outfit := types.AvatarOutfit{
		Id:          req.OutfitId,
		Name:        "休闲服装",
		Description: "舒适的休闲服装",
		Category:    "clothes",
		Style:       "casual",
		Price:       0,
		IsFree:      true,
		ImageUrl:    "https://picsum.photos/200/200?random=4",
		Parts: []types.OutfitPart{
			{
				Id:       "1-1",
				Type:     "top",
				ImageUrl: "https://picsum.photos/150/150?random=5",
			},
			{
				Id:       "1-2",
				Type:     "bottom",
				ImageUrl: "https://picsum.photos/150/150?random=6",
			},
		},
		CreatedAt: "2026-01-12",
	}

	return &types.GetAvatarOutfitResp{
		BaseResp: common.HandleError(nil),
		Data:     outfit,
	}, nil
}
