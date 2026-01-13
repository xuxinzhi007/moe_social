package avatar

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserAvatarLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserAvatarLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserAvatarLogic {
	return &GetUserAvatarLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserAvatarLogic) GetUserAvatar(req *types.GetUserAvatarReq) (resp *types.GetUserAvatarResp, err error) {
	// 模拟获取用户虚拟形象数据
	// 实际项目中应该调用RPC服务或数据库查询

	// 如果用户没有设置形象，返回默认形象数据
	defaultAvatar := types.UserAvatar{
		UserId: req.UserId,
		BaseConfig: types.BaseConfig{
			FaceShape: "round",
			SkinColor: "light",
			EyeType:   "big",
			HairStyle: "short",
			HairColor: "black",
		},
		CurrentOutfit: types.OutfitConfig{
			Clothes:     "casual",
			Accessories: []string{},
			Background:  "default",
		},
		OwnedOutfits: []string{},
	}

	return &types.GetUserAvatarResp{
		BaseResp: common.HandleError(nil),
		Data:     defaultAvatar,
	}, nil
}
