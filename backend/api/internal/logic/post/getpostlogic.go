package post

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetPostLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetPostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetPostLogic {
	return &GetPostLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetPostLogic) GetPost(req *types.GetPostReq) (resp *types.GetPostResp, err error) {
	// 调用RPC服务获取帖子
	rpcResp, err := l.svcCtx.SuperRpcClient.GetPost(l.ctx, &rpc.GetPostReq{
		PostId: req.PostId,
	})
	if err != nil {
		return &types.GetPostResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应格式
	return &types.GetPostResp{
		BaseResp: common.HandleRPCError(nil, "获取帖子成功"),
		Data: types.Post{
			Id:         rpcResp.Post.Id,
			UserId:     rpcResp.Post.UserId,
			UserName:   rpcResp.Post.UserName,
			UserAvatar: rpcResp.Post.UserAvatar,
			Content:    rpcResp.Post.Content,
			Images:     rpcResp.Post.Images,
			Likes:      int(rpcResp.Post.Likes),
			Comments:   int(rpcResp.Post.Comments),
			IsLiked:    rpcResp.Post.IsLiked,
			CreatedAt:  rpcResp.Post.CreatedAt,
		},
	}, nil
}

