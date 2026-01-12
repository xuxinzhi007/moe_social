package avatar

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetAvatarOutfitsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetAvatarOutfitsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetAvatarOutfitsLogic {
	return &GetAvatarOutfitsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetAvatarOutfitsLogic) GetAvatarOutfits(req *types.GetAvatarOutfitsReq) (resp *types.GetAvatarOutfitsResp, err error) {
	// 模拟获取装扮物品列表
	// 实际项目中应该调用RPC服务或数据库查询

	// 如果没有装扮物品，返回空数组
	outfits := []types.AvatarOutfit{}

	// 模拟返回一些装扮物品数据
	outfits = append(outfits, types.AvatarOutfit{
		Id:          "1",
		Name:        "休闲服装",
		Description: "舒适的休闲服装",
		Category:    "clothes",
		Style:       "casual",
		Price:       0,
		IsFree:      true,
		ImageUrl:    "https://via.placeholder.com/200/90EE90/FFFFFF?text=Outfit",
		Parts: []types.OutfitPart{
			{
				Id:       "1-1",
				Type:     "top",
				ImageUrl: "https://via.placeholder.com/150/4682B4/FFFFFF?text=Top",
			},
			{
				Id:       "1-2",
				Type:     "bottom",
				ImageUrl: "https://via.placeholder.com/150/DA70D6/FFFFFF?text=Bottom",
			},
		},
		CreatedAt: "2026-01-12",
	})

	return &types.GetAvatarOutfitsResp{
		BaseResp: common.HandleError(nil),
		Data:     outfits,
		Total:    len(outfits),
	}, nil
}
