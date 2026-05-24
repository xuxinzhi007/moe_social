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

type AdminDeletePostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeletePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeletePostLogic {
	return &AdminDeletePostLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminDeletePostLogic) AdminDeletePost(in *super.AdminDeletePostReq) (*super.AdminDeletePostResp, error) {
	raw := strings.TrimSpace(in.GetPostId())
	if raw == "" {
		return nil, errorx.InvalidArgument("帖子 ID 不能为空")
	}
	postID, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || postID == 0 {
		return nil, errorx.InvalidArgument("无效的帖子 ID")
	}

	var p model.Post
	if err := l.svcCtx.DB.First(&p, postID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("帖子不存在")
		}
		l.Errorf("[admin] delete post load: %v", err)
		return nil, errorx.Internal("查询帖子失败")
	}

	l.svcCtx.DB.Where("post_id = ?", p.ID).Delete(&model.PostTopic{})
	if err := l.svcCtx.DB.Delete(&p).Error; err != nil {
		l.Errorf("[admin] delete post: %v", err)
		return nil, errorx.Internal("删除帖子失败")
	}

	return &super.AdminDeletePostResp{}, nil
}
