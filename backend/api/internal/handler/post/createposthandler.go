package post

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/handler/handlerutil"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func CreatePostHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.CreatePostReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.PostGW.CreatePost(r.Context(), &moe.CreatePostReq{
			UserId:           req.UserId,
			Content:          req.Content,
			Images:           req.Images,
			TopicTags:        handlerutil.TopicTagsToRPC(req.TopicTags),
			HandDrawCard:     req.HandDrawCard,
			HandDrawThumbUrl: req.HandDrawThumbUrl,
			MoodTag:          req.MoodTag,
			GroupId:          req.GroupId,
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.CreatePostResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		httpx.OkJsonCtx(r.Context(), w, &types.CreatePostResp{
			BaseResp:        common.HandleRPCError(nil, "创建帖子成功"),
			NewAchievements: handlerutil.UnlocksFromRPC(rpcResp.NewAchievements),
			Data:            handlerutil.PostFromRPC(rpcResp.Post),
		})
	}
}
