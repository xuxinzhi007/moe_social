package checkin

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetUserLevelHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetUserLevelReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CheckInGW.GetUserLevel(r.Context(), &moe.GetUserLevelReq{
			UserId: req.UserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.GetUserLevelResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetUserLevelResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取用户等级成功", Success: true},
			Data: types.UserLevelInfo{
				Level:        int(rpcResp.LevelInfo.Level),
				Experience:   int(rpcResp.LevelInfo.Experience),
				TotalExp:     int(rpcResp.LevelInfo.TotalExp),
				NextLevelExp: int(rpcResp.LevelInfo.NextLevelExp),
				LevelTitle:   rpcResp.LevelInfo.LevelTitle,
				BadgeUrl:     rpcResp.LevelInfo.BadgeUrl,
				Progress:     rpcResp.LevelInfo.Progress,
			},
		})
	}
}
