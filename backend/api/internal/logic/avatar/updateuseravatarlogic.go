package avatar

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserAvatarLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpdateUserAvatarLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserAvatarLogic {
	return &UpdateUserAvatarLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpdateUserAvatarLogic) UpdateUserAvatar(req *types.UpdateUserAvatarReq) (resp *types.UpdateUserAvatarResp, err error) {
	logx.Infof("API: 更新用户虚拟形象: UserID=%s", req.UserId)

	// 调用RPC服务更新用户虚拟形象
	rpcResp, err := l.svcCtx.SuperRpcClient.UpdateUserAvatar(l.ctx, &super.UpdateUserAvatarReq{
		UserId: req.UserId,
		BaseConfig: &super.AvatarBaseConfig{
			FaceShape: req.BaseConfig.FaceShape,
			SkinColor: req.BaseConfig.SkinColor,
			EyeType:   req.BaseConfig.EyeType,
			HairStyle: req.BaseConfig.HairStyle,
			HairColor: req.BaseConfig.HairColor,
		},
		CurrentOutfit: &super.AvatarOutfitConfig{
			Clothes:     req.CurrentOutfit.Clothes,
			Accessories: req.CurrentOutfit.Accessories,
			Background:  req.CurrentOutfit.Background,
		},
	})
	if err != nil {
		logx.Errorf("RPC调用失败: %v", err)
		return nil, err
	}

	if rpcResp.Avatar == nil {
		logx.Errorf("RPC返回空数据")
		return nil, err
	}

	// 转换RPC响应为API响应格式
	updatedAvatar := types.UserAvatar{
		UserId: rpcResp.Avatar.UserId,
		BaseConfig: types.BaseConfig{
			FaceShape: rpcResp.Avatar.BaseConfig.FaceShape,
			SkinColor: rpcResp.Avatar.BaseConfig.SkinColor,
			EyeType:   rpcResp.Avatar.BaseConfig.EyeType,
			HairStyle: rpcResp.Avatar.BaseConfig.HairStyle,
			HairColor: rpcResp.Avatar.BaseConfig.HairColor,
		},
		CurrentOutfit: types.OutfitConfig{
			Clothes:     rpcResp.Avatar.CurrentOutfit.Clothes,
			Accessories: rpcResp.Avatar.CurrentOutfit.Accessories,
			Background:  rpcResp.Avatar.CurrentOutfit.Background,
		},
		OwnedOutfits: rpcResp.Avatar.OwnedOutfits,
	}

	logx.Infof("虚拟形象更新成功: %+v", updatedAvatar)

	return &types.UpdateUserAvatarResp{
		BaseResp: common.HandleError(nil),
		Data:     updatedAvatar,
	}, nil
}
