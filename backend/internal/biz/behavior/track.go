package behaviorbiz

import (
	"context"
	"errors"
	"strings"
	"time"

	"backend/model"
	"backend/utils"

	"gorm.io/gorm"
)

const maxBatchSize = 50

// EventInput 单条行为事件。
type EventInput struct {
	Event      string
	Screen     string
	ParamsJSON string
	DurationMs int64
	SessionID  string
	ClientTsMs int64
}

// TrackEvents 批量写入行为事件。
func TrackEvents(ctx context.Context, store BehaviorStore, userID uint, events []EventInput) (int32, error) {
	if store == nil {
		return 0, gorm.ErrInvalidDB
	}
	if userID == 0 {
		return 0, ErrInvalidUser
	}
	if len(events) == 0 {
		return 0, nil
	}
	if len(events) > maxBatchSize {
		return 0, ErrBatchTooLarge
	}

	var accepted int32
	err := store.Transaction(ctx, func(tx BehaviorTx) error {
		for _, ev := range events {
			screen := utils.NormalizeBehaviorScreen(ev.Screen)
			eventType := utils.NormalizeBehaviorEvent(ev.Event)
			if screen == "unknown" && eventType == "" {
				continue
			}
			clientTs := time.UnixMilli(ev.ClientTsMs).UTC()
			if ev.ClientTsMs <= 0 {
				clientTs = time.Now().UTC()
			}
			row := model.UserBehaviorEvent{
				UserID:     userID,
				Event:      eventType,
				Screen:     screen,
				ParamsJSON: strings.TrimSpace(ev.ParamsJSON),
				DurationMs: ev.DurationMs,
				SessionID:  strings.TrimSpace(ev.SessionID),
				ClientTs:   clientTs,
			}
			if err := tx.CreateBehaviorEvent(&row); err != nil {
				return err
			}
			accepted++
			if eventType != utils.BehaviorEventScreenView {
				continue
			}
			activityDate := utils.BehaviorActivityDate(clientTs)
			daily, err := tx.FindBehaviorDaily(userID, activityDate, screen)
			switch {
			case errors.Is(err, gorm.ErrRecordNotFound):
				daily = model.UserBehaviorDaily{
					UserID:          userID,
					ActivityDate:    activityDate,
					Screen:          screen,
					VisitCount:      1,
					TotalDurationMs: ev.DurationMs,
				}
				if err := tx.CreateBehaviorDaily(&daily); err != nil {
					return err
				}
			case err != nil:
				return err
			default:
				if err := tx.UpdateBehaviorDaily(&daily, ev.DurationMs); err != nil {
					return err
				}
			}
		}
		return nil
	})
	return accepted, err
}
