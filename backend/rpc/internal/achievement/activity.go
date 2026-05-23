package achievement

import (
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

func (e *Engine) bumpDailyActivity(tx *gorm.DB, userID uint, now time.Time, post, comment, checkIn bool) error {
	date := todayDate(now)
	var row model.UserDailyActivity
	err := tx.Where("user_id = ? AND activity_date = ?", userID, date).First(&row).Error
	if err == gorm.ErrRecordNotFound {
		row = model.UserDailyActivity{
			UserID:       userID,
			ActivityDate: date,
		}
	}
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

	if row.ID == 0 {
		if err := tx.Create(&row).Error; err != nil {
			return err
		}
	} else {
		if err := tx.Save(&row).Error; err != nil {
			return err
		}
	}

	if err := e.syncWeeklyActivity(tx, userID, now, row); err != nil {
		return err
	}

	if row.TaskScore >= 2 && !row.DailyComboCounted {
		row.DailyComboCounted = true
		if err := tx.Save(&row).Error; err != nil {
			return err
		}
		if _, err := e.incrementProgress(tx, userID, "daily_task_keeper", 1); err != nil {
			return err
		}
	}
	return nil
}

func (e *Engine) syncWeeklyActivity(tx *gorm.DB, userID uint, now time.Time, day model.UserDailyActivity) error {
	ws := weekStartDate(now)
	var week model.UserWeeklyActivity
	err := tx.Where("user_id = ? AND week_start = ?", userID, ws).First(&week).Error
	if err == gorm.ErrRecordNotFound {
		week = model.UserWeeklyActivity{UserID: userID, WeekStart: ws}
	}

	var days []model.UserDailyActivity
	if err := tx.Where("user_id = ? AND activity_date >= ? AND activity_date < ?",
		userID, ws, ws.AddDate(0, 0, 7)).Find(&days).Error; err != nil {
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
		if err := tx.Create(&week).Error; err != nil {
			return err
		}
	} else {
		if err := tx.Save(&week).Error; err != nil {
			return err
		}
	}

	if week.TaskTotal >= 8 && !week.WeeklyCounted {
		week.WeeklyCounted = true
		if err := tx.Save(&week).Error; err != nil {
			return err
		}
		_, err := e.incrementProgress(tx, userID, "weekly_task_keeper", 1)
		return err
	}
	return nil
}
