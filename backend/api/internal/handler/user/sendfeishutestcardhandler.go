package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SendFeishuTestCardHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.EmptyReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		userID, err := common.UserIDString(r.Context())
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		_, rpcErr := svcCtx.UserGW.SendFeishuTestCard(r.Context(), &moe.SendFeishuTestCardReq{UserId: userID})
		if rpcErr != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.SendFeishuTestCardResp{
				BaseResp: common.HandleRPCError(rpcErr, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.SendFeishuTestCardResp{
			BaseResp: common.HandleRPCError(nil, "测试卡片已发送，请在飞书客户端查看"),
		})
	}
}
