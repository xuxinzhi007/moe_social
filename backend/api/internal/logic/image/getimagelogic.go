package image

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetImageLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetImageLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetImageLogic {
	return &GetImageLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetImageLogic) GetImage(req *types.DeleteImageReq) (resp *types.EmptyResp, err error) {
	// 这个函数不会被调用，因为我们已经在handler中直接处理了图片请求
	// handler已经实现了直接返回图片文件的逻辑
	return &types.EmptyResp{}, nil
}
