package achievement

import "time"

// StorageDateForShanghaiDay 将上海自然日映射为 UTC 零点，便于写入 MySQL DATE/DATETIME 且与业务日一致。
func StorageDateForShanghaiDay(t time.Time) time.Time {
	return activityStorageDate(t.In(activityLocation))
}

// ShanghaiDayBounds 返回上海自然日对应的半开区间 [start, end)，用于按日查询 DATETIME 列。
func ShanghaiDayBounds(now time.Time) (time.Time, time.Time) {
	start := activityStorageDate(todayDate(now))
	return start, start.AddDate(0, 0, 1)
}

// ShanghaiDayString 返回 now 在上海时区下的 YYYY-MM-DD。
func ShanghaiDayString(now time.Time) string {
	return activityDayString(todayDate(now))
}

// ShanghaiDayStringFrom 将任意时刻转为上海自然日字符串（用于比较历史记录）。
func ShanghaiDayStringFrom(t time.Time) string {
	return activityDayString(t)
}

// ShanghaiYesterdayString 返回上海时区下的「昨天」YYYY-MM-DD。
func ShanghaiYesterdayString(now time.Time) string {
	return activityDayString(todayDate(now).AddDate(0, 0, -1))
}
