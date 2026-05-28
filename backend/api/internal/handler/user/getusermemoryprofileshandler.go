package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetUserMemoryProfilesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserMemoryProfilesReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.LLMGW.GetUserMemoryProfiles(r.Context(), &moe.GetUserMemoryProfilesReq{
			UserId: req.UserId,
			Limit:  int32(req.Limit),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserMemoryProfilesResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		profiles := make([]types.UserMemoryProfile, 0, len(rpcResp.Profiles))
		for _, p := range rpcResp.Profiles {
			profiles = append(profiles, types.UserMemoryProfile{
				MemoryType: p.MemoryType,
				Summary:    p.Summary,
				ItemCount:  int(p.ItemCount),
				Confidence: p.Confidence,
			})
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserMemoryProfilesResp{
			BaseResp: common.HandleRPCError(nil, "获取用户画像摘要成功"),
			Data:     profiles,
		})
	}
}
