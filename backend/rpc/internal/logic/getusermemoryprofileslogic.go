package logic

import (
	"context"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserMemoryProfilesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserMemoryProfilesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserMemoryProfilesLogic {
	return &GetUserMemoryProfilesLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserMemoryProfilesLogic) GetUserMemoryProfiles(in *super.GetUserMemoryProfilesReq) (*super.GetUserMemoryProfilesResp, error) {
	start := time.Now()
	if strings.TrimSpace(in.UserId) == "" {
		return nil, errorx.InvalidArgument("user_id不能为空")
	}
	userID, err := strconv.Atoi(in.UserId)
	if err != nil {
		return nil, errorx.InvalidArgument("无效的user_id")
	}
	limit := int(in.Limit)
	if limit <= 0 {
		limit = 6
	}
	if limit > 20 {
		limit = 20
	}

	if err := ensureUserMemoryProfileCache(l.svcCtx.DB, uint(userID), false); err != nil {
		l.Errorf("ensure user profile cache failed: %v", err)
		return nil, errorx.Internal("查询用户画像失败")
	}

	var caches []model.UserMemoryProfileCache
	if err := l.svcCtx.DB.Model(&model.UserMemoryProfileCache{}).
		Where("user_id = ?", uint(userID)).
		Order("item_count desc, confidence desc").
		Limit(limit).
		Find(&caches).Error; err != nil {
		l.Errorf("query user profile cache failed: %v", err)
		return nil, errorx.Internal("查询用户画像失败")
	}
	if cost := time.Since(start); cost > 120*time.Millisecond {
		l.Infof("slow get user memory profiles query, user_id=%d limit=%d rows=%d cost_ms=%d", userID, limit, len(caches), cost.Milliseconds())
	}

	profiles := make([]*super.UserMemoryProfile, 0, len(caches))
	for _, c := range caches {
		profiles = append(profiles, &super.UserMemoryProfile{
			MemoryType: c.MemoryType,
			Summary:    c.Summary,
			ItemCount:  int32(c.ItemCount),
			Confidence: c.Confidence,
		})
	}

	return &super.GetUserMemoryProfilesResp{Profiles: profiles}, nil
}
