package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListMediaImagesLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListMediaImagesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMediaImagesLogic {
	return &AdminListMediaImagesLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListMediaImagesLogic) AdminListMediaImages(req *types.AdminListMediaImagesReq, publicBase string) (*types.AdminListMediaImagesResp, error) {
	rows, owners, total, err := utils.ListAdminMediaImages(
		l.svcCtx.Config.Image.LocalDir,
		publicBase,
		req.Page,
		req.PageSize,
		req.Keyword,
		req.OwnerFolder,
		req.MediaKind,
	)
	if err != nil {
		l.Errorf("[admin] list media images: %v", err)
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
}
