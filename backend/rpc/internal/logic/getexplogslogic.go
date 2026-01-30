package logic

import (
	"context"
	"fmt"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetExpLogsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetExpLogsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetExpLogsLogic {
	return &GetExpLogsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetExpLogsLogic) GetExpLogs(in *super.GetExpLogsReq) (*super.GetExpLogsResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("无效的用户ID: %v", err)
	}

	// 1. 检查用户是否存在
	var user model.User
	if err := l.svcCtx.DB.Where("id = ?", userID).First(&user).Error; err != nil {
		return nil, fmt.Errorf("用户不存在")
	}

	// 2. 设置默认分页参数
	page := in.Page
	pageSize := in.PageSize
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100 // 限制最大页面大小
	}

	// 3. 查询经验日志总数
	var total int64
	if err := l.svcCtx.DB.Model(&model.ExpLog{}).
		Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return nil, fmt.Errorf("查询经验日志总数失败: %v", err)
	}

	// 4. 分页查询经验日志记录
	var expLogs []model.ExpLog
	offset := (page - 1) * pageSize
	if err := l.svcCtx.DB.Where("user_id = ?", userID).
		Order("created_at DESC").
		Limit(int(pageSize)).Offset(int(offset)).
		Find(&expLogs).Error; err != nil {
		return nil, fmt.Errorf("查询经验日志失败: %v", err)
	}

	// 5. 转换为proto格式
	var logs []*super.ExpLogRecord
	for _, log := range expLogs {
		logs = append(logs, &super.ExpLogRecord{
			Id:          fmt.Sprintf("%d", log.ID),
			ExpChange:   int32(log.ExpChange),
			Source:      log.Source,
			Description: log.Description,
			CreatedAt:   log.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}

	return &super.GetExpLogsResp{
		Logs:  logs,
		Total: int32(total),
	}, nil
}
