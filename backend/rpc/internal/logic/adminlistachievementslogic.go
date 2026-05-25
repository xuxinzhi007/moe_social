package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAchievementsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAchievementsLogic {
	return &AdminListAchievementsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAchievementsLogic) AdminListAchievements(in *super.AdminListAchievementsReq) (*super.AdminListAchievementsResp, error) {
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := l.svcCtx.DB.Model(&model.AchievementDefinition{})
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("name LIKE ? OR description LIKE ? OR id LIKE ?", like, like, like)
	}
	if cat := strings.TrimSpace(in.GetCategory()); cat != "" {
		q = q.Where("category = ?", cat)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count achievements: %v", err)
		return nil, errorx.Internal("查询成就失败")
	}
	var rows []model.AchievementDefinition
	offset := int((page - 1) * pageSize)
	if err := q.Order("sort_order ASC, id ASC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list achievements: %v", err)
		return nil, errorx.Internal("查询成就失败")
	}
	items := make([]*super.AdminAchievementItem, len(rows))
	for i, row := range rows {
		items[i] = achievementToProto(row)
	}
	return &super.AdminListAchievementsResp{Items: items, Total: int32(total)}, nil
}
