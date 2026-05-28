package post

import (
	"context"
	"strconv"

	"backend/api/internal/common"
	"backend/api/internal/moebridge"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type SearchPostsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSearchPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SearchPostsLogic {
	return &SearchPostsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SearchPostsLogic) SearchPosts(req *types.SearchPostsReq) (*types.SearchPostsResp, error) {
	limit := req.PageSize
	if limit <= 0 {
		limit = 10
	}
	if limit > 30 {
		limit = 30
	}
	var viewerUID uint64
	if req.ViewerUserId != "" {
		if v, err := strconv.ParseUint(req.ViewerUserId, 10, 32); err == nil {
			viewerUID = v
		}
	}
	var topicID uint64
	if req.TopicTagId != "" {
		if v, err := strconv.ParseUint(req.TopicTagId, 10, 32); err == nil {
			topicID = v
		}
	}
	rpcResp, err := l.svcCtx.PostGW.MoeSearchPosts(l.ctx, &moe.MoeSearchPostsReq{
		Query:        req.Q,
		Limit:        int32(limit),
		ViewerUserId: viewerUID,
		MoodTag:      req.MoodTag,
		TopicTagId:   topicID,
	})
	if err != nil {
		l.Errorf("post search rpc failed: %v", err)
		return &types.SearchPostsResp{BaseResp: common.HandleRPCError(err, "检索失败")}, nil
	}
	return &types.SearchPostsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     moebridge.SearchPostsFromRPC(rpcResp),
	}, nil
}
