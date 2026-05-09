package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type DeletePostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeletePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeletePostLogic {
	return &DeletePostLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *DeletePostLogic) DeletePost(in *super.DeletePostReq) (*super.DeletePostResp, error) {
	if in.PostId == "" || in.UserId == "" {
		return nil, errorx.New(400, "post_id 和 user_id 不能为空")
	}

	postID, err := strconv.ParseUint(in.PostId, 10, 64)
	if err != nil {
		return nil, errorx.New(400, "无效的 post_id")
	}
	userID, err := strconv.ParseUint(in.UserId, 10, 64)
	if err != nil {
		return nil, errorx.New(400, "无效的 user_id")
	}

	var p model.Post
	if err := l.svcCtx.DB.First(&p, postID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, errorx.New(404, "帖子不存在")
		}
		return nil, errorx.New(500, "查询帖子失败")
	}

	if uint64(p.UserID) != userID {
		return nil, errorx.New(403, "无权删除此帖子")
	}

	// 级联删除话题关联，再软删除帖子
	l.svcCtx.DB.Where("post_id = ?", p.ID).Delete(&model.PostTopic{})
	if err := l.svcCtx.DB.Delete(&p).Error; err != nil {
		l.Error("删除帖子失败: ", err)
		return nil, errorx.New(500, "删除帖子失败")
	}

	return &super.DeletePostResp{}, nil
}
