package logic

import (
	"context"
	"errors"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

const maxBehaviorBatchSize = 50

type TrackUserBehaviorEventsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewTrackUserBehaviorEventsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *TrackUserBehaviorEventsLogic {
	return &TrackUserBehaviorEventsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *TrackUserBehaviorEventsLogic) TrackUserBehaviorEvents(in *super.TrackUserBehaviorEventsReq) (*super.TrackUserBehaviorEventsResp, error) {
	uid := uint(in.GetUserId())
	if uid == 0 {
		return nil, errors.New("invalid user_id")
	}

	events := in.GetEvents()
	if len(events) == 0 {
		return &super.TrackUserBehaviorEventsResp{Accepted: 0}, nil
	}
	if len(events) > maxBehaviorBatchSize {
		return nil, errors.New("events batch too large")
	}

	accepted := int32(0)
	err := l.svcCtx.DB.Transaction(func(tx *gorm.DB) error {
		for _, ev := range events {
			screen := utils.NormalizeBehaviorScreen(ev.GetScreen())
			eventType := utils.NormalizeBehaviorEvent(ev.GetEvent())
			if screen == "unknown" && eventType == "" {
				continue
			}

			clientTs := time.UnixMilli(ev.GetClientTsMs()).UTC()
			if ev.GetClientTsMs() <= 0 {
				clientTs = time.Now().UTC()
			}

			row := model.UserBehaviorEvent{
				UserID:     uid,
				Event:      eventType,
				Screen:     screen,
				ParamsJSON: strings.TrimSpace(ev.GetParamsJson()),
				DurationMs: ev.GetDurationMs(),
				SessionID:  strings.TrimSpace(ev.GetSessionId()),
				ClientTs:   clientTs,
			}
			if err := tx.Create(&row).Error; err != nil {
				return err
			}
			accepted++

			if eventType != utils.BehaviorEventScreenView {
				continue
			}

			activityDate := utils.BehaviorActivityDate(clientTs)
			var daily model.UserBehaviorDaily
			err := tx.Where("user_id = ? AND activity_date = ? AND screen = ?", uid, activityDate, screen).
				First(&daily).Error
			switch {
			case errors.Is(err, gorm.ErrRecordNotFound):
				daily = model.UserBehaviorDaily{
					UserID:          uid,
					ActivityDate:    activityDate,
					Screen:          screen,
					VisitCount:      1,
					TotalDurationMs: ev.GetDurationMs(),
				}
				if err := tx.Create(&daily).Error; err != nil {
					return err
				}
			case err != nil:
				return err
			default:
				if err := tx.Model(&daily).Updates(map[string]interface{}{
					"visit_count":       gorm.Expr("visit_count + ?", 1),
					"total_duration_ms": gorm.Expr("total_duration_ms + ?", ev.GetDurationMs()),
				}).Error; err != nil {
					return err
				}
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	return &super.TrackUserBehaviorEventsResp{Accepted: accepted}, nil
}
