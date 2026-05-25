package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteMediaImageLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteMediaImageLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteMediaImageLogic {
	return &AdminDeleteMediaImageLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminDeleteMediaImageLogic) AdminDeleteMediaImage(req *types.AdminDeleteMediaImageReq) (*types.AdminDeleteMediaImageResp, error) {
	if err := utils.DeleteAdminMediaImage(l.svcCtx.Config.Image.LocalDir, req.Filename); err != nil {
		l.Errorf("[admin] delete media image: %v", err)
		return &types.AdminDeleteMediaImageResp{BaseResp: common.HandleError(err)}, nil
	}
	resp := &types.AdminDeleteMediaImageResp{
		BaseResp: common.HandleError(nil),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "media_image", req.Filename, "删除云图库文件")
	}
	return resp, nil
}
