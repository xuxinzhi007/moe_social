package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetMemoryStatsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetMemoryStatsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetMemoryStatsLogic {
	return &AdminGetMemoryStatsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetMemoryStatsLogic) AdminGetMemoryStats(_ *super.AdminGetMemoryStatsReq) (*super.AdminGetMemoryStatsResp, error) {
	db := l.svcCtx.DB
	stats := &super.AdminMemoryStats{}

	var totalMemories int64
	if err := db.Model(&model.UserMemory{}).Count(&totalMemories).Error; err != nil {
		l.Errorf("[admin] memory stats total: %v", err)
		return nil, errorx.Internal("查询记忆统计失败")
	}
	stats.TotalMemories = int32(totalMemories)
	var usersWith int64
	if err := db.Model(&model.UserMemory{}).Distinct("user_id").Count(&usersWith).Error; err != nil {
		return nil, errorx.Internal("查询记忆统计失败")
	}
	stats.UsersWithMemories = int32(usersWith)

	var totalFeedbacks int64
	if err := db.Model(&model.UserMemoryFeedback{}).Count(&totalFeedbacks).Error; err != nil {
		return nil, errorx.Internal("查询记忆统计失败")
	}
	stats.TotalFeedbacks = int32(totalFeedbacks)
	var totalEmbeddings int64
	if err := db.Model(&model.UserMemoryEmbedding{}).Count(&totalEmbeddings).Error; err != nil {
		return nil, errorx.Internal("查询记忆统计失败")
	}
	stats.TotalEmbeddings = int32(totalEmbeddings)

	type typeRow struct {
		MemoryType string
		Count      int64
	}
	var typeRows []typeRow
	if err := db.Model(&model.UserMemory{}).
		Select("memory_type, COUNT(*) as count").
		Group("memory_type").
		Order("count DESC").
		Scan(&typeRows).Error; err != nil {
		return nil, errorx.Internal("查询记忆统计失败")
	}
	stats.ByType = make([]*super.AdminMemoryTypeStat, len(typeRows))
	for i, row := range typeRows {
		stats.ByType[i] = &super.AdminMemoryTypeStat{
			MemoryType: row.MemoryType,
			Count:      int32(row.Count),
		}
	}
	return &super.AdminGetMemoryStatsResp{Stats: stats}, nil
}
