package post

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type LikePostLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewLikePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LikePostLogic {
	return &LikePostLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *LikePostLogic) LikePost(req *types.LikePostReq) (resp *types.LikePostResp, err error) {
	// 调用RPC服务点赞帖子
	rpcResp, err := l.svcCtx.SuperRpcClient.LikePost(l.ctx, &super.LikePostReq{
		PostId: req.PostId,
		UserId: req.UserId,
	})
	if err != nil {
		return &types.LikePostResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应格式
	return &types.LikePostResp{
		BaseResp: common.HandleRPCError(nil, "操作成功"),
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

