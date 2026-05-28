package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"
	"github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminDeleteMediaImageHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteMediaImageReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteMediaImageReq) (*types.AdminDeleteMediaImageResp, error) {
			if err := utils.DeleteAdminMediaImage(svcCtx.Config.Image.LocalDir, req.Filename); err != nil {
			logx.WithContext(ctx).Errorf("[admin] delete media image: %v", err)
			return &types.AdminDeleteMediaImageResp{BaseResp: common.HandleError(err)}, nil
			}
			resp := &types.AdminDeleteMediaImageResp{
			BaseResp: common.HandleError(nil),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "media_image", req.Filename, "删除云图库文件")
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
