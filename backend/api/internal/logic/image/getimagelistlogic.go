package image

import (
	"context"
	"fmt"
	"os"
	"sort"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetImageListLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetImageListLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetImageListLogic {
	return &GetImageListLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetImageListLogic) GetImageList(req *types.GetImageListReq) (resp *types.GetImageListResp, err error) {
	// 读取本地图片目录
	files, err := os.ReadDir(localImgDir)
	if err != nil {
		return &types.GetImageListResp{
			BaseResp: common.HandleError(err),
		}, nil
	}

	// 构建图片信息列表
	imageInfos := make([]types.ImageInfo, 0, len(files))
	for _, file := range files {
		// 跳过目录
		if file.IsDir() {
			continue
		}

		// 获取文件信息
		fileInfo, err := file.Info()
		if err != nil {
			continue
		}

		// 构建图片信息
		imageInfo := types.ImageInfo{
			Id:        file.Name(),
			Filename:  file.Name(),
			Url:       fmt.Sprintf("%s/api/images/%s", localServerUrl, file.Name()),
			Size:      fileInfo.Size(),
			CreatedAt: fileInfo.ModTime().Format("2006-01-02 15:04:05"),
		}
		imageInfos = append(imageInfos, imageInfo)
	}

	// 按创建时间降序排序
	sort.Slice(imageInfos, func(i, j int) bool {
		return imageInfos[i].CreatedAt > imageInfos[j].CreatedAt
	})

	// 计算分页
	total := len(imageInfos)
	start := (req.Page - 1) * req.PageSize
	end := start + req.PageSize
	if start > total {
		start = total
	}
	if end > total {
		end = total
	}

	// 获取分页数据
	var paginatedImages []types.ImageInfo
	if start < total {
		paginatedImages = imageInfos[start:end]
	} else {
		paginatedImages = []types.ImageInfo{}
	}

	return &types.GetImageListResp{
		BaseResp: common.HandleError(nil),
		Data:     paginatedImages,
		Total:    total,
	}, nil
}
