//go:build hybrid

package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
	"strings"
)

func AdminCreateGiftHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminCreateGiftReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminCreateGiftReq) (resp *types.AdminCreateGiftResp, err error) {
			if strings.TrimSpace(req.Name) == "" {
			return &types.AdminCreateGiftResp{
			BaseResp: types.BaseResp{Success: false, Message: "礼物名称不能为空"},
			}, nil
			}
			if req.Price < 0 {
			return &types.AdminCreateGiftResp{
			BaseResp: types.BaseResp{Success: false, Message: "价格不能为负数"},
			}, nil
			}

			rpcResp, err := svcCtx.AdminGW.AdminCreateGift(ctx, &moe.AdminCreateGiftReq{
			Name:        strings.TrimSpace(req.Name),
			Price:       int32(req.Price),
			Icon:        req.Icon,
			Description: req.Description,
			Category:    req.Category,
			SortOrder:   int32(req.SortOrder),
			})
			if err != nil {
			return &types.AdminCreateGiftResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			resp = &types.AdminCreateGiftResp{
			BaseResp: common.HandleRPCError(nil, "创建成功"),
			Data:     common.RpcGiftToTypes(rpcResp.GetGift()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "create", "gift", resp.Data.Id, "创建礼物")
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
