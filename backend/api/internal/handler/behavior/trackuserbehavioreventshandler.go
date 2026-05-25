package behavior

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend/api/internal/logic/behavior"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func TrackUserBehaviorEventsHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.TrackUserBehaviorEventsReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		authHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(authHeader, "Bearer ") {
			httpx.ErrorCtx(r.Context(), w, errors.New("missing or invalid authorization header"))
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		userID, err := utils.GetUserIDFromToken(tokenString)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		req.UserId = strconv.Itoa(int(userID))

		l := behavior.NewTrackUserBehaviorEventsLogic(r.Context(), svcCtx)
		resp, err := l.TrackUserBehaviorEvents(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
