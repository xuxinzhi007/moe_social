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
	"gorm.io/gorm"
)

type AdminListMemoriesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListMemoriesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMemoriesLogic {
	return &AdminListMemoriesLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListMemoriesLogic) AdminListMemories(in *super.AdminListMemoriesReq) (*super.AdminListMemoriesResp, error) {
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := l.svcCtx.DB.Model(&model.UserMemory{})
	if uid := strings.TrimSpace(in.GetUserId()); uid != "" {
		q = q.Where("user_id = ?", uid)
	}
	if mt := strings.TrimSpace(in.GetMemoryType()); mt != "" {
		q = q.Where("memory_type = ?", mt)
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("`key` LIKE ? OR `value` LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count memories: %v", err)
		return nil, errorx.Internal("查询记忆失败")
	}
	var rows []model.UserMemory
	offset := int((page - 1) * pageSize)
	if err := q.Order("updated_at DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list memories: %v", err)
		return nil, errorx.Internal("查询记忆失败")
	}
	names := loadMemoryUsernames(l.svcCtx.DB, rows)
	items := make([]*super.AdminMemoryItem, len(rows))
	for i, row := range rows {
		items[i] = memoryToAdminProto(row, names[row.UserID])
	}
	return &super.AdminListMemoriesResp{Items: items, Total: int32(total)}, nil
}

func loadMemoryUsernames(db *gorm.DB, rows []model.UserMemory) map[uint]string {
	out := make(map[uint]string)
	if db == nil || len(rows) == 0 {
		return out
	}
	ids := make([]uint, 0, len(rows))
	seen := map[uint]struct{}{}
	for _, row := range rows {
		if _, ok := seen[row.UserID]; ok {
			continue
		}
		seen[row.UserID] = struct{}{}
		ids = append(ids, row.UserID)
	}
	var users []model.User
	if err := db.Where("id IN ?", ids).Find(&users).Error; err != nil {
		return out
	}
	for _, u := range users {
		out[u.ID] = u.Username
	}
	return out
}

func memoryToAdminProto(row model.UserMemory, username string) *super.AdminMemoryItem {
	return &super.AdminMemoryItem{
		Id:         strconv.FormatUint(uint64(row.ID), 10),
		UserId:     strconv.FormatUint(uint64(row.UserID), 10),
		Username:   username,
		Key:        row.Key,
		Value:      row.Value,
		MemoryType: row.MemoryType,
		Confidence: row.Confidence,
		Source:     row.Source,
		UpdatedAt:  row.UpdatedAt.Format(time.DateTime),
	}
}
