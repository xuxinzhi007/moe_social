//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"fmt"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminUpdateUserHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpdateUserReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateUserReq) (*types.AdminUpdateUserResp, error) {
			rpcResp, err := svcCtx.AdminGW.AdminUpdateUser(ctx, &moe.AdminUpdateUserReq{
			UserId:          req.UserId,
			Role:            req.Role,
			IsVip:           req.IsVip,
			UpdateIsVip:     req.UpdateIsVip,
			Signature:       req.Signature,
			UpdateSignature: req.UpdateSignature,
			Avatar:          req.Avatar,
			UpdateAvatar:    req.UpdateAvatar,
			})
			if err != nil {
			return &types.AdminUpdateUserResp{
			BaseResp: common.HandleRPCError(err, ""),
			}, nil
			}

			resp := &types.AdminUpdateUserResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcUserToTypes(rpcResp.User),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "user", fmt.Sprintf("%d", req.UserId), "更新 App 用户")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
