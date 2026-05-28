package admin

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/rest/httpx"
)

func AdminListMediaImagesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminListMediaImagesReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		publicBase := utils.ResolveMediaPublicBase(
			r,
			svcCtx.Config.Image.PublicBaseUrl,
			svcCtx.Config.ClientPublicApiBaseUrl,
		)
		resp, err := func(req *types.AdminListMediaImagesReq, publicBase string) (*types.AdminListMediaImagesResp, error) {
			rows, owners, total, err := utils.ListAdminMediaImages(
				svcCtx.Config.Image.LocalDir,
				publicBase,
				req.Page,
				req.PageSize,
				req.Keyword,
				req.OwnerFolder,
				req.MediaKind,
			)
			if err != nil {
				logx.WithContext(ctx).Errorf("[admin] list media images: %v", err)
				return &types.AdminListMediaImagesResp{BaseResp: common.HandleError(err)}, nil
			}
			items := make([]types.AdminMediaImageItem, len(rows))
			for i, row := range rows {
				items[i] = types.AdminMediaImageItem{
					Filename:    row.Filename,
					FileName:    row.FileName,
					OwnerFolder: row.OwnerFolder,
					MediaKind:   row.MediaKind,
					Url:         row.URL,
					Size:        row.Size,
					CreatedAt:   row.CreatedAt,
					OwnerHint:   row.OwnerHint,
				}
			}
			ownerItems := make([]types.AdminMediaOwnerSummary, len(owners))
			for i, o := range owners {
				ownerItems[i] = types.AdminMediaOwnerSummary{
					OwnerFolder:  o.OwnerFolder,
					UserId:       o.UserID,
					UsernameHint: o.UsernameHint,
					FileCount:    o.FileCount,
					TotalBytes:   o.TotalBytes,
				}
			}
			return &types.AdminListMediaImagesResp{
				BaseResp: common.HandleError(nil),
				Data: types.AdminListMediaImagesData{
					Items:  items,
					Total:  total,
					Owners: ownerItems,
				},
			}, nil
		}(&req, publicBase)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
