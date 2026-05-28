package voice

import (
	"encoding/json"
	"errors"
	"net/http"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	rtctokenbuilder "github.com/AgoraIO-Community/go-tokenbuilder/rtctokenbuilder"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func GetRtcTokenHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.GetRtcTokenReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		appId := svcCtx.Config.Agora.AppId
		appCertificate := svcCtx.Config.Agora.AppCertificate

		if appId == "" || appCertificate == "" {
			httpx.ErrorCtx(r.Context(), w, errors.New("Agora AppId/Certificate not configured"))
			return
		}

		userAccount := req.UserAccount
		if userAccount == "" {
			uidVal := r.Context().Value("userId")
			if uidVal == nil {
				uidVal = r.Context().Value("user_id")
			}
			if uidVal == nil {
				httpx.ErrorCtx(r.Context(), w, errors.New("User not logged in or userId not found in context"))
				return
			}

			switch v := uidVal.(type) {
			case string:
				userAccount = v
			case json.Number:
				userAccount = v.String()
			default:
				if s, ok := uidVal.(string); ok {
					userAccount = s
				} else {
					httpx.ErrorCtx(r.Context(), w, errors.New("Invalid userId type in context"))
					return
				}
			}
		}

		expireTimeInSeconds := uint32(86400)

		role := rtctokenbuilder.RolePublisher
		if req.Role == 2 {
			role = rtctokenbuilder.RoleSubscriber
		}

		token, err := rtctokenbuilder.BuildTokenWithAccount(appId, appCertificate, req.ChannelName, userAccount, rtctokenbuilder.Role(role), expireTimeInSeconds)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.GetRtcTokenResp{
			BaseResp: types.BaseResp{
				Code:    0,
				Message: "success",
				Success: true,
			},
			Token: token,
			AppId: appId,
		})
	}
}
