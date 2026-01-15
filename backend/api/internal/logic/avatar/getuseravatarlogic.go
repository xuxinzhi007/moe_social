package avatar

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

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
	logx.Infof("API: 获取用户虚拟形象: UserID=%s", req.UserId)

	// 调用RPC服务获取用户虚拟形象
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUserAvatar(l.ctx, &super.GetUserAvatarReq{
		UserId: req.UserId,
	})
	if err != nil {
		logx.Errorf("RPC调用失败: %v", err)
		return nil, err
	}

	if rpcResp.Avatar == nil {
		logx.Errorf("RPC返回空数据")
		return &types.GetUserAvatarResp{
			BaseResp: common.HandleError(nil),
			Data: types.UserAvatar{
				UserId: req.UserId,
				BaseConfig: types.BaseConfig{
					FaceShape: "face_1",
					SkinColor: "#FDBCB4",
					EyeType:   "eyes_1",
					HairStyle: "hair_1",
					HairColor: "#8B4513",
				},
				CurrentOutfit: types.OutfitConfig{
					Clothes:     "clothes_1",
					Accessories: []string{},
					Background:  "default",
				},
				OwnedOutfits: []string{},
			},
		}, nil
	}

	// 转换RPC响应为API响应格式
	avatar := types.UserAvatar{
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

	logx.Infof("成功获取用户虚拟形象: %+v", avatar)

	return &types.GetUserAvatarResp{
		BaseResp: common.HandleError(nil),
		Data:     avatar,
	}, nil
}
