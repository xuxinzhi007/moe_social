package comment

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateCommentLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCreateCommentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateCommentLogic {
	return &CreateCommentLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreateCommentLogic) CreateComment(req *types.CreateCommentReq) (resp *types.CreateCommentResp, err error) {
	// 调用RPC服务创建评论
	rpcResp, err := l.svcCtx.SuperRpcClient.CreateComment(l.ctx, &rpc.CreateCommentReq{
		PostId:  req.PostId,
		UserId:  req.UserId,
		Content: req.Content,
	})
	if err != nil {
		return &types.CreateCommentResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应格式
	return &types.CreateCommentResp{
		BaseResp: common.HandleRPCError(nil, "创建评论成功"),
		Data: types.Comment{
			Id:         rpcResp.Comment.Id,
			PostId:     rpcResp.Comment.PostId,
			UserId:     rpcResp.Comment.UserId,
			UserName:   rpcResp.Comment.UserName,
			UserAvatar: rpcResp.Comment.UserAvatar,
			Content:    rpcResp.Comment.Content,
			Likes:      int(rpcResp.Comment.Likes),
			IsLiked:    rpcResp.Comment.IsLiked,
			CreatedAt:  rpcResp.Comment.CreatedAt,
		},
	}, nil
}

