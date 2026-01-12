package image

import (
	"context"
	"os"
	"path/filepath"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteImageLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewDeleteImageLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteImageLogic {
	return &DeleteImageLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *DeleteImageLogic) DeleteImage(req *types.DeleteImageReq) (resp *types.DeleteImageResp, err error) {
	// 构建图片文件路径
	imgPath := filepath.Join(localImgDir, req.Filename)

	// 检查文件是否存在
	if _, err := os.Stat(imgPath); os.IsNotExist(err) {
		return &types.DeleteImageResp{
			BaseResp: common.HandleError(err),
		}, nil
	}

	// 删除文件
	if err := os.Remove(imgPath); err != nil {
		return &types.DeleteImageResp{
			BaseResp: common.HandleError(err),
		}, nil
	}

	return &types.DeleteImageResp{
		BaseResp: common.HandleError(nil),
	}, nil
}
