package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserAchievementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserAchievementsLogic {
	return &GetUserAchievementsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserAchievementsLogic) GetUserAchievements(in *super.GetUserAchievementsReq) (*super.GetUserAchievementsResp, error) {
	uid, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return &super.GetUserAchievementsResp{}, nil
	}

	var rows []model.UserBadgeProgress
	if err := l.svcCtx.DB.Where("user_id = ?", uint(uid)).Find(&rows).Error; err != nil {
		l.Error("查询成就进度失败:", err)
		return nil, err
	}

	entries := make([]*super.UserBadgeProgressEntry, 0, len(rows))
	for _, r := range rows {
		e := &super.UserBadgeProgressEntry{
			BadgeId:      r.BadgeID,
			CurrentCount: int32(r.CurrentCount),
			IsUnlocked:   r.UnlockedAt != nil,
		}
		if r.UnlockedAt != nil {
			e.UnlockedAt = r.UnlockedAt.Format("2006-01-02T15:04:05.000Z")
		}
		entries = append(entries, e)
	}

	return &super.GetUserAchievementsResp{Entries: entries}, nil
}
