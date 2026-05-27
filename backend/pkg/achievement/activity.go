package achievement

import (
	"strings"
	"time"

	"backend/model"

	"gorm.io/gorm"
)

// CurrentEventHour returns hour in Asia/Shanghai for achievement time windows.
func CurrentEventHour() int {
	return time.Now().In(activityLocation).Hour()
}

var activityLocation = func() *time.Location {
	loc, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		return time.FixedZone("CST", 8*3600)
	}
	return loc
}()

func todayDate(now time.Time) time.Time {
	n := now.In(activityLocation)
	y, m, d := n.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, activityLocation)
}

func weekStartDate(now time.Time) time.Time {
	n := now.In(activityLocation)
	weekday := int(n.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	monday := n.AddDate(0, 0, -(weekday - 1))
	y, m, d := monday.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, activityLocation)
}

func activityDayString(t time.Time) string {
	return t.In(activityLocation).Format("2006-01-02")
}

// activityStorageDate 将上海自然日映射为 UTC 零点的 DATE，避免写入 MySQL 时因会话时区变成前一天。
func activityStorageDate(t time.Time) time.Time {
	t = t.In(activityLocation)
	y, m, d := t.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

func dailyActivityLookupDates(shanghaiDay time.Time) []time.Time {
	stored := activityStorageDate(shanghaiDay)
	return []time.Time{stored, stored.AddDate(0, 0, -1)}
}

func findDailyActivityAggressive(tx *gorm.DB, userID uint, shanghaiDay time.Time) (model.UserDailyActivity, error) {
	days := []string{
		activityDayString(shanghaiDay.AddDate(0, 0, -1)),
		activityDayString(shanghaiDay),
		activityDayString(shanghaiDay.AddDate(0, 0, 1)),
	}
	var row model.UserDailyActivity
	err := tx.Unscoped().
		Where("user_id = ? AND DATE(activity_date) IN ?", userID, days).
		Order("activity_date DESC").
		First(&row).Error
	if err == nil {
		row.DeletedAt = gorm.DeletedAt{}
		return row, nil
	}
	return findDailyActivity(tx, userID, shanghaiDay)
}

func findDailyActivity(tx *gorm.DB, userID uint, shanghaiDay time.Time) (model.UserDailyActivity, error) {
	dayStr := activityDayString(shanghaiDay)
	prevStr := activityDayString(shanghaiDay.AddDate(0, 0, -1))
	for _, d := range []string{dayStr, prevStr} {
		var row model.UserDailyActivity
		err := tx.Unscoped().
			Where("user_id = ? AND DATE(activity_date) = ?", userID, d).
			First(&row).Error
		if err == nil {
			row.DeletedAt = gorm.DeletedAt{}
			return row, nil
		}
		if err != gorm.ErrRecordNotFound {
			return row, err
		}
	}
	for _, d := range dailyActivityLookupDates(shanghaiDay) {
		var row model.UserDailyActivity
		err := tx.Unscoped().
			Where("user_id = ? AND activity_date = ?", userID, d).
			First(&row).Error
		if err == nil {
			row.DeletedAt = gorm.DeletedAt{}
			return row, nil
		}
		if err != gorm.ErrRecordNotFound {
			return row, err
		}
	}
	return model.UserDailyActivity{}, gorm.ErrRecordNotFound
}

// loadOrInitDailyActivity 按「自然日」查找活跃记录（含曾软删的行与旧版时区存法，避免唯一键冲突）。
func loadOrInitDailyActivity(tx *gorm.DB, userID uint, shanghaiDay time.Time) (model.UserDailyActivity, error) {
	dates := dailyActivityLookupDates(shanghaiDay)
	row, err := findDailyActivity(tx, userID, shanghaiDay)
	if err == gorm.ErrRecordNotFound {
		return model.UserDailyActivity{
			UserID:       userID,
			ActivityDate: dates[0],
		}, nil
	}
	return row, err
}

func isDuplicateKeyErr(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "Duplicate entry") ||
		strings.Contains(msg, "duplicate key") ||
		strings.Contains(msg, "1062")
}

func applyDailyActivityDelta(row *model.UserDailyActivity, post, comment, checkIn bool) {
	if post {
		row.PostCount++
	}
	if comment {
		row.CommentCount++
	}
	if checkIn {
		row.CheckIn = true
	}
	score := 0
	if row.PostCount > 0 {
		score++
	}
	if row.CommentCount > 0 {
		score++
	}
	if row.CheckIn {
		score++
	}
	row.TaskScore = score
}

func (e *Engine) bumpDailyActivity(tx *gorm.DB, userID uint, now time.Time, post, comment, checkIn bool) error {
	date := todayDate(now)
	row, err := loadOrInitDailyActivity(tx, userID, date)
	if err != nil {
		return err
	}
	applyDailyActivityDelta(&row, post, comment, checkIn)

	created := false
	if row.ID == 0 {
		if err := tx.Unscoped().Create(&row).Error; err != nil {
			if !isDuplicateKeyErr(err) {
				return err
			}
			row, err = findDailyActivityAggressive(tx, userID, date)
			if err != nil {
				return err
			}
			applyDailyActivityDelta(&row, post, comment, checkIn)
			created = false
		} else {
			created = true
		}
	}
	if !created {
		if err := tx.Unscoped().Save(&row).Error; err != nil {
			return err
		}
	}

	if err := e.syncWeeklyActivity(tx, userID, now, row); err != nil {
		return err
	}

	if row.TaskScore >= 2 && !row.DailyComboCounted {
		row.DailyComboCounted = true
		if err := tx.Unscoped().Save(&row).Error; err != nil {
			return err
		}
		if _, err := e.incrementProgress(tx, userID, "daily_task_keeper", 1); err != nil {
			return err
		}
	}
	return nil
}

func weeklyActivityLookupDates(weekStart time.Time) []time.Time {
	stored := activityStorageDate(weekStart)
	return []time.Time{stored, stored.AddDate(0, 0, -1)}
}

func loadOrInitWeeklyActivity(tx *gorm.DB, userID uint, weekStart time.Time) (model.UserWeeklyActivity, error) {
	dates := weeklyActivityLookupDates(weekStart)
	for _, d := range dates {
		var week model.UserWeeklyActivity
		err := tx.Unscoped().
			Where("user_id = ? AND week_start = ?", userID, d).
			First(&week).Error
		if err == nil {
			week.DeletedAt = gorm.DeletedAt{}
			return week, nil
		}
		if err != gorm.ErrRecordNotFound {
			return week, err
		}
	}
	return model.UserWeeklyActivity{
		UserID:    userID,
		WeekStart: dates[0],
	}, nil
}

func (e *Engine) syncWeeklyActivity(tx *gorm.DB, userID uint, now time.Time, day model.UserDailyActivity) error {
	ws := weekStartDate(now)
	week, err := loadOrInitWeeklyActivity(tx, userID, ws)
	if err != nil {
		return err
	}

	weekDates := weeklyActivityLookupDates(ws)
	rangeStart := weekDates[len(weekDates)-1]
	rangeEnd := weekDates[0].AddDate(0, 0, 7)
	var days []model.UserDailyActivity
	if err := tx.Unscoped().Where("user_id = ? AND activity_date >= ? AND activity_date < ?",
		userID, rangeStart, rangeEnd).Find(&days).Error; err != nil {
		return err
	}
	total := 0
	for _, d := range days {
		total += d.PostCount + d.CommentCount
		if d.CheckIn {
			total++
		}
	}
	week.TaskTotal = total

	if week.ID == 0 {
		if err := tx.Unscoped().Create(&week).Error; err != nil {
			if !isDuplicateKeyErr(err) {
				return err
			}
			week, err = loadOrInitWeeklyActivity(tx, userID, ws)
			if err != nil {
				return err
			}
			// recompute total after reload
			var days []model.UserDailyActivity
			if err := tx.Unscoped().Where("user_id = ? AND activity_date >= ? AND activity_date < ?",
				userID, rangeStart, rangeEnd).Find(&days).Error; err != nil {
				return err
			}
			total := 0
			for _, d := range days {
				total += d.PostCount + d.CommentCount
				if d.CheckIn {
					total++
				}
			}
			week.TaskTotal = total
		}
	}
	if err := tx.Unscoped().Save(&week).Error; err != nil {
		return err
	}

	if week.TaskTotal >= 8 && !week.WeeklyCounted {
		week.WeeklyCounted = true
		if err := tx.Unscoped().Save(&week).Error; err != nil {
			return err
		}
		_, err := e.incrementProgress(tx, userID, "weekly_task_keeper", 1)
		return err
	}
	return nil
}
