package logic

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminDeleteCommentLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteCommentLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteCommentLogic {
	return &AdminDeleteCommentLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminDeleteCommentLogic) AdminDeleteComment(in *super.AdminDeleteCommentReq) (*super.AdminDeleteCommentResp, error) {
	raw := strings.TrimSpace(in.GetCommentId())
	if raw == "" {
		return nil, errorx.InvalidArgument("评论 ID 不能为空")
	}
	commentID, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || commentID == 0 {
		return nil, errorx.InvalidArgument("无效的评论 ID")
	}

	var c model.Comment
	if err := l.svcCtx.DB.First(&c, commentID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("评论不存在")
		}
		l.Errorf("[admin] delete comment load: %v", err)
		return nil, errorx.Internal("查询评论失败")
	}

	if err := l.svcCtx.DB.Delete(&c).Error; err != nil {
		l.Errorf("[admin] delete comment: %v", err)
		return nil, errorx.Internal("删除评论失败")
	}

	return &super.AdminDeleteCommentResp{}, nil
}
