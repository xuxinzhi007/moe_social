package logic

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetCheckInStatusLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetCheckInStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetCheckInStatusLogic {
	return &GetCheckInStatusLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetCheckInStatusLogic) GetCheckInStatus(in *super.GetCheckInStatusReq) (*super.GetCheckInStatusResp, error) {
	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("无效的用户ID: %v", err)
	}

	// 1. 检查用户是否存在
	var user model.User
	if err := l.svcCtx.DB.Where("id = ?", userID).First(&user).Error; err != nil {
		return nil, fmt.Errorf("用户不存在")
	}

	// 2. 检查今日是否已签到
	today := time.Now().Format("2006-01-02")
	var todayCheckIn model.UserCheckIn
	hasCheckedToday := l.svcCtx.DB.Where("user_id = ? AND DATE(check_in_date) = ?", userID, today).
		First(&todayCheckIn).Error == nil

	// 3. 获取当前连续签到天数
	var lastCheckIn model.UserCheckIn
	consecutiveDays := 0
	if err := l.svcCtx.DB.Where("user_id = ?", userID).Order("check_in_date DESC").
		First(&lastCheckIn).Error; err == nil {
		if hasCheckedToday {
			// 如果今天已签到，连续天数就是今天的记录
			consecutiveDays = lastCheckIn.ConsecutiveDays
		} else {
			// 如果今天还没签到，检查最近一次签到是否是昨天
			yesterday := time.Now().AddDate(0, 0, -1).Format("2006-01-02")
			lastCheckInDate := lastCheckIn.CheckInDate.Format("2006-01-02")

			if lastCheckInDate == yesterday {
				consecutiveDays = lastCheckIn.ConsecutiveDays
			}
		}
	}

	// 4. 计算今日签到奖励（如果还没签到的话）
	todayReward := 0
	nextDayReward := 0

	if !hasCheckedToday {
		// 计算今日签到奖励
		baseExp := 10
		var reward model.CheckInReward
		extraExp := 0
		futureConsecutiveDays := consecutiveDays + 1

		if err := l.svcCtx.DB.Where("consecutive_days <= ?", futureConsecutiveDays).
			Order("consecutive_days DESC").First(&reward).Error; err == nil {
			extraExp = reward.ExpReward
		}

		todayReward = baseExp + extraExp

		// VIP加成
		if user.IsVip && user.VipEndAt != nil && user.VipEndAt.After(time.Now()) {
			todayReward = int(float64(todayReward) * 1.5)
		}
	}

	// 5. 计算明日签到奖励
	baseExp := 10
	var nextReward model.CheckInReward
	extraExp := 0
	var futureConsecutiveDays int

	if hasCheckedToday {
		futureConsecutiveDays = consecutiveDays + 1
	} else {
		futureConsecutiveDays = consecutiveDays + 2
	}

	if err := l.svcCtx.DB.Where("consecutive_days <= ?", futureConsecutiveDays).
		Order("consecutive_days DESC").First(&nextReward).Error; err == nil {
		extraExp = nextReward.ExpReward
	}

	nextDayReward = baseExp + extraExp

	// VIP加成
	if user.IsVip && user.VipEndAt != nil && user.VipEndAt.After(time.Now()) {
		nextDayReward = int(float64(nextDayReward) * 1.5)
	}

	// 6. 判断是否可以签到（今天没签到就可以签到）
	canCheckIn := !hasCheckedToday

	return &super.GetCheckInStatusResp{
		Status: &super.CheckInStatus{
			HasCheckedToday:  hasCheckedToday,
			ConsecutiveDays:  int32(consecutiveDays),
			TodayReward:      int32(todayReward),
			NextDayReward:    int32(nextDayReward),
			CanCheckIn:       canCheckIn,
		},
	}, nil
}
