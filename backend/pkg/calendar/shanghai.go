package calendar

import "time"

var shanghaiLocation = func() *time.Location {
	loc, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		return time.FixedZone("CST", 8*3600)
	}
	return loc
}()

func todayInShanghai(now time.Time) time.Time {
	n := now.In(shanghaiLocation)
	y, m, d := n.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, shanghaiLocation)
}

func storageDateUTC(t time.Time) time.Time {
	t = t.In(shanghaiLocation)
	y, m, d := t.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

// ShanghaiDayBounds 返回上海自然日对应的半开区间 [start, end)，用于按日查询 DATETIME 列。
func ShanghaiDayBounds(now time.Time) (time.Time, time.Time) {
	start := storageDateUTC(todayInShanghai(now))
	return start, start.AddDate(0, 0, 1)
}
