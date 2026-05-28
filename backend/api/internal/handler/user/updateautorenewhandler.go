package user

import (
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func UpdateAutoRenewHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UpdateAutoRenewReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		_, err := svcCtx.UserGW.UpdateAutoRenew(r.Context(), &moe.UpdateAutoRenewReq{
			UserId:    req.UserId,
			AutoRenew: req.AutoRenew,
		})
		if err != nil {
			logx.WithContext(r.Context()).Errorf("调用RPC服务失败: %v", err)
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.EmptyResp{})
	}
}
