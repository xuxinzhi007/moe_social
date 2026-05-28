//go:build hybrid

package avatar

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func UpdateUserAvatarHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UpdateUserAvatarReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.UpdateUserAvatar(r.Context(), &moe.UpdateUserAvatarReq{
			UserId: req.UserId,
			BaseConfig: &moe.AvatarBaseConfig{
				FaceShape: req.BaseConfig.FaceShape,
				SkinColor: req.BaseConfig.SkinColor,
				EyeType:   req.BaseConfig.EyeType,
				HairStyle: req.BaseConfig.HairStyle,
				HairColor: req.BaseConfig.HairColor,
			},
			CurrentOutfit: &moe.AvatarOutfitConfig{
				Clothes:     req.CurrentOutfit.Clothes,
				Accessories: req.CurrentOutfit.Accessories,
				Background:  req.CurrentOutfit.Background,
			},
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		if rpcResp.Avatar == nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

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

		httpx.OkJsonCtx(r.Context(), w, &types.UpdateUserAvatarResp{
			BaseResp: common.HandleError(nil),
			Data:     updatedAvatar,
		})
	}
}
