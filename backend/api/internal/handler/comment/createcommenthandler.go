//go:build hybrid

package comment

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func CreateCommentHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.CreateCommentReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.CommentGW.CreateComment(r.Context(), &moe.CreateCommentReq{
			PostId: req.PostId, UserId: req.UserId, Content: req.Content, ParentId: req.ParentId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.CreateCommentResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.CreateCommentResp{
			BaseResp:        common.HandleRPCError(nil, "创建评论成功"),
			NewAchievements: handlerutil.UnlocksFromRPC(rpcResp.NewAchievements),
			Data: types.Comment{
				Id: rpcResp.Comment.Id, PostId: rpcResp.Comment.PostId, UserId: rpcResp.Comment.UserId,
				UserName: rpcResp.Comment.UserName, UserAvatar: rpcResp.Comment.UserAvatar,
				Content: rpcResp.Comment.Content, Likes: int(rpcResp.Comment.Likes),
				IsLiked: rpcResp.Comment.IsLiked, CreatedAt: rpcResp.Comment.CreatedAt,
				ParentId: rpcResp.Comment.ParentId, ReplyToUserName: rpcResp.Comment.ReplyToUserName,
			},
		})
	}
}
