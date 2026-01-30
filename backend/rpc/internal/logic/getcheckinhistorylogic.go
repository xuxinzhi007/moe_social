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

type GetCheckInHistoryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetCheckInHistoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetCheckInHistoryLogic {
	return &GetCheckInHistoryLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetCheckInHistoryLogic) GetCheckInHistory(in *super.GetCheckInHistoryReq) (*super.GetCheckInHistoryResp, error) {
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

	// 3. 查询签到记录总数
	var total int64
	if err := l.svcCtx.DB.Model(&model.UserCheckIn{}).
		Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return nil, fmt.Errorf("查询签到记录总数失败: %v", err)
	}

	// 4. 分页查询签到记录
	var checkInRecords []model.UserCheckIn
	offset := (page - 1) * pageSize
	if err := l.svcCtx.DB.Where("user_id = ?", userID).
		Order("check_in_date DESC").
		Limit(int(pageSize)).Offset(int(offset)).
		Find(&checkInRecords).Error; err != nil {
		return nil, fmt.Errorf("查询签到记录失败: %v", err)
	}

	// 5. 转换为proto格式
	var records []*super.CheckInRecord
	for _, record := range checkInRecords {
		records = append(records, &super.CheckInRecord{
			CheckInDate:        record.CheckInDate.Format("2006-01-02"),
			ConsecutiveDays:    int32(record.ConsecutiveDays),
			ExpReward:          int32(record.ExpReward),
			IsSpecialReward:    record.IsSpecialReward,
			SpecialRewardDesc:  record.SpecialRewardDesc,
		})
	}

	return &super.GetCheckInHistoryResp{
		Records: records,
		Total:   int32(total),
	}, nil
}
