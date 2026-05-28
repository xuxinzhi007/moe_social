package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminUpdateGiftHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminUpdateGiftReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminUpdateGiftReq) (resp *types.AdminUpdateGiftResp, err error) {
			rpcResp, err := svcCtx.AdminGW.AdminUpdateGift(ctx, &moe.AdminUpdateGiftReq{
			GiftId:            req.GiftId,
			Name:              req.Name,
			Price:             int32(req.Price),
			Icon:              req.Icon,
			Description:       req.Description,
			Category:          req.Category,
			SortOrder:         int32(req.SortOrder),
			UpdateName:        req.UpdateName,
			UpdatePrice:       req.UpdatePrice,
			UpdateIcon:        req.UpdateIcon,
			UpdateDescription: req.UpdateDescription,
			UpdateCategory:    req.UpdateCategory,
			UpdateSortOrder:   req.UpdateSortOrder,
			})
			if err != nil {
			return &types.AdminUpdateGiftResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}

			resp = &types.AdminUpdateGiftResp{
			BaseResp: common.HandleRPCError(nil, "保存成功"),
			Data:     common.RpcGiftToTypes(rpcResp.GetGift()),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "gift", req.GiftId, "更新礼物")
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
