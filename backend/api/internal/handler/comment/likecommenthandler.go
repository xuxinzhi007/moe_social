package comment

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func LikeCommentHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.LikeCommentReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CommentGW.LikeComment(r.Context(), &moe.LikeCommentReq{
			CommentId: req.CommentId, UserId: req.UserId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.LikeCommentResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.LikeCommentResp{
			BaseResp: common.HandleRPCError(nil, "操作成功"),
			Data: types.Comment{
				Id: rpcResp.Comment.Id, PostId: rpcResp.Comment.PostId, UserId: rpcResp.Comment.UserId,
				UserName: rpcResp.Comment.UserName, UserAvatar: rpcResp.Comment.UserAvatar,
				Content: rpcResp.Comment.Content, Likes: int(rpcResp.Comment.Likes),
				IsLiked: rpcResp.Comment.IsLiked, CreatedAt: rpcResp.Comment.CreatedAt,
			},
		})
	}
}
