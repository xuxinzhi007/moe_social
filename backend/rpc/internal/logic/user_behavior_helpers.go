package logic

import (
	"sort"
	"time"

	"backend/model"
	"backend/rpc/pb/super"
	"backend/utils"

	"gorm.io/gorm"
)

func loadUserBehaviorSummary(db *gorm.DB, uid uint) *super.AdminUserBehaviorSummary {
	if db == nil || uid == 0 {
		return nil
	}

	since := time.Now().UTC().AddDate(0, 0, -7)
	var dailyRows []model.UserBehaviorDaily
	_ = db.Where("user_id = ? AND activity_date >= ?", uid, since).
		Order("activity_date desc").
		Find(&dailyRows).Error

	type screenAgg struct {
		visits   int
		duration int64
	}
	byScreen := map[string]screenAgg{}
	for _, row := range dailyRows {
		item := byScreen[row.Screen]
		item.visits += row.VisitCount
		item.duration += row.TotalDurationMs
		byScreen[row.Screen] = item
	}

	type ranked struct {
		screen   string
		visits   int
		duration int64
	}
	rankedList := make([]ranked, 0, len(byScreen))
	for screen, item := range byScreen {
		rankedList = append(rankedList, ranked{
			screen:   screen,
			visits:   item.visits,
			duration: item.duration,
		})
	}
	sort.Slice(rankedList, func(i, j int) bool {
		if rankedList[i].visits == rankedList[j].visits {
			return rankedList[i].duration > rankedList[j].duration
		}
		return rankedList[i].visits > rankedList[j].visits
	})
	if len(rankedList) > 8 {
		rankedList = rankedList[:8]
	}

	topScreens := make([]*super.AdminUserBehaviorScreenStat, 0, len(rankedList))
	for _, item := range rankedList {
		topScreens = append(topScreens, &super.AdminUserBehaviorScreenStat{
			Screen:            item.screen,
			Label:             utils.BehaviorScreenLabel(item.screen),
			VisitCount:        int32(item.visits),
			TotalDurationMs:   item.duration,
		})
	}

	var totalEvents7d int64
	_ = db.Model(&model.UserBehaviorEvent{}).
		Where("user_id = ? AND created_at >= ?", uid, since).
		Count(&totalEvents7d).Error

	lastActiveAt := ""
	var lastEvent model.UserBehaviorEvent
	if err := db.Where("user_id = ?", uid).Order("created_at desc").First(&lastEvent).Error; err == nil {
		lastActiveAt = lastEvent.CreatedAt.UTC().Format(time.RFC3339)
	}

	return &super.AdminUserBehaviorSummary{
		TopScreens:    topScreens,
		Tags:          utils.BuildBehaviorTags(dailyRows),
		LastActiveAt:  lastActiveAt,
		TotalEvents_7D: int32(totalEvents7d),
	}
}
