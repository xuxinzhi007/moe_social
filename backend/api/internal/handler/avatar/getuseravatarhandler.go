package avatar

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetUserAvatarHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserAvatarReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.GetUserAvatar(r.Context(), &moe.GetUserAvatarReq{
			UserId: req.UserId,
		})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		if rpcResp.Avatar == nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserAvatarResp{
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
			})
			return
		}

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

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserAvatarResp{
			BaseResp: common.HandleError(nil),
			Data:     avatar,
		})
	}
}
