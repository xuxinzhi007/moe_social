package postdata

import (
	"fmt"
	"time"
)

// hotRankWindow 热门排序的扰动窗口。同一窗口内分页顺序稳定，窗口过后第一名会换。
const hotRankWindow = 10 * time.Minute

// hotRankSeed 把当前时间收成窗口序号，供热门排序做稳定扰动。
func hotRankSeed(now time.Time) int64 {
	return now.Unix() / int64(hotRankWindow/time.Second)
}

// hotOrderSQL 热门排序：互动取对数，按发帖时间衰减，再在窗口内打散。
//
// 纯点赞倒序会让同一条高赞帖永远排第一。对数压平点赞差距，小时衰减让旧帖让位，
// CRC32 扰动让接近的帖子在每个窗口里换顺序。seed 只来自时间窗口，不是用户输入。
func hotOrderSQL(seed int64) string {
	return fmt.Sprintf(`(
		(LN(likes + 1) * 2 + LN(comments + 1) + 0.2)
		/ POW(GREATEST(TIMESTAMPDIFF(HOUR, created_at, NOW()), 0) + 2, 0.55)
		* (0.72 + MOD(CRC32(CONCAT(id, '-', %d)), 1000) / 1000.0 * 0.56)
	) DESC`, seed)
}
