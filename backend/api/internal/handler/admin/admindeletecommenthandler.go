package admin

import (
	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"
	"github.com/zeromicro/go-zero/rest/httpx"
	"net/http"
)

func AdminDeleteCommentHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, ok := common.PrepareAdminContext(w, r)
		if !ok {
			return
		}
		var req types.AdminDeleteCommentReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(ctx, w, err)
			return
		}
		resp, err := func(req *types.AdminDeleteCommentReq) (resp *types.AdminDeleteCommentResp, err error) {
			_, err = svcCtx.AdminGW.AdminDeleteComment(ctx, &moe.AdminDeleteCommentReq{
			CommentId: req.CommentId,
			})
			if err != nil {
			return &types.AdminDeleteCommentResp{BaseResp: common.HandleRPCError(err, "")}, nil
			}
			resp = &types.AdminDeleteCommentResp{
			BaseResp: common.HandleRPCError(nil, "已删除"),
			}
			if resp.BaseResp.Success {
			common.TryRecordAdminAudit(ctx, svcCtx, "delete", "comment", req.CommentId, "删除评论")
			}
			return resp, nil
		}(&req)
		if err != nil {
			httpx.ErrorCtx(ctx, w, err)
		} else {
			httpx.OkJsonCtx(ctx, w, resp)
		}
	}
}
