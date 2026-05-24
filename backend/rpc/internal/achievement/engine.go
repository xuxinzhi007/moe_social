package achievement

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"backend/model"
	"backend/rpc/internal/level"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

// Engine evaluates achievement rules.
type Engine struct {
	db *gorm.DB

	mu          sync.RWMutex
	definitions []model.AchievementDefinition
}

// NewEngine creates an achievement engine.
func NewEngine(db *gorm.DB) *Engine {
	return &Engine{db: db}
}

func (e *Engine) loadDefinitions(tx *gorm.DB) ([]model.AchievementDefinition, error) {
	e.mu.RLock()
	if len(e.definitions) > 0 {
		defs := e.definitions
		e.mu.RUnlock()
		return defs, nil
	}
	e.mu.RUnlock()

	var defs []model.AchievementDefinition
	if err := tx.Where("enabled = ?", true).Order("sort_order ASC").Find(&defs).Error; err != nil {
		return nil, err
	}
	if len(defs) == 0 {
		logx.Infof("成就定义表为空，请在 Moe Admin 执行「导入默认成就」后再触发成就逻辑")
	}
	e.mu.Lock()
	e.definitions = defs
	e.mu.Unlock()
	return defs, nil
}

// tryBumpDailyActivity 更新日活；失败只记日志，避免评论/发帖/签到主流程回滚。
func (e *Engine) tryBumpDailyActivity(tx *gorm.DB, userID uint, now time.Time, post, comment, checkIn bool) {
	if err := e.bumpDailyActivity(tx, userID, now, post, comment, checkIn); err != nil {
		logx.Errorf("user %d daily activity bump skipped: %v", userID, err)
	}
}

// ApplyEvent processes an achievement event inside tx.
func (e *Engine) ApplyEvent(tx *gorm.DB, userID uint, ev Event) ([]UnlockResult, error) {
	if _, err := e.loadDefinitions(tx); err != nil {
		return nil, err
	}

	var unlocked []UnlockResult
	now := time.Now()

	switch ev.Type {
	case EventUserInitialized:
		u, err := e.incrementProgress(tx, userID, "welcome_aboard", 1)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)

	case EventCheckIn:
		u, err := e.incrementProgress(tx, userID, "loyal_user", 1)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
		e.tryBumpDailyActivity(tx, userID, now, false, false, true)

	case EventPostCreated:
		u, err := e.handlePostCreated(tx, userID, ev)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
		e.tryBumpDailyActivity(tx, userID, now, true, false, false)

	case EventCommentCreated:
		u, err := e.incrementProgress(tx, userID, "social_butterfly", 1)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
		e.tryBumpDailyActivity(tx, userID, now, false, true, false)

	case EventPostLiked:
		u, err := e.setMaxProgress(tx, userID, "like_magnet", ev.PostLikeCount)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)

	case EventGiftSent:
		u1, err := e.incrementProgress(tx, userID, "generous_giver", ev.GiftCount)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u1...)
		u2, err := e.addSumProgress(tx, userID, "gift_tycoon", int(ev.GiftValue))
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u2...)

	case EventVipActivated:
		u, err := e.incrementProgress(tx, userID, "vip_member", 1)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)

	case EventNewFollower:
		u, err := e.evalFollowerCount(tx, userID)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
	}

	return unlocked, nil
}

func (e *Engine) handlePostCreated(tx *gorm.DB, userID uint, ev Event) ([]UnlockResult, error) {
	var unlocked []UnlockResult

	u, err := e.incrementProgress(tx, userID, "first_post", 1)
	if err != nil {
		return nil, err
	}
	unlocked = append(unlocked, u...)

	u, err = e.incrementProgress(tx, userID, "post_master", 1)
	if err != nil {
		return nil, err
	}
	unlocked = append(unlocked, u...)

	if ev.ImageCount > 0 {
		u, err = e.incrementProgress(tx, userID, "photographer", ev.ImageCount)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
	}

	if ev.HasTopic {
		u, err = e.incrementProgress(tx, userID, "trendsetter", 1)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
	}

	if ev.MoodTag != "" {
		u, err = e.incrementProgress(tx, userID, "emotion_expert", 1)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
	}

	if ev.HandDrawApproved {
		u, err = e.incrementProgress(tx, userID, "creative_genius", 1)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
	}

	if ev.ContentLen >= 500 {
		u, err = e.incrementProgress(tx, userID, "storyteller", 1)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
	}

	if ev.Hour < 8 {
		u, err = e.incrementProgress(tx, userID, "early_bird", 1)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
	}
	if ev.Hour >= 23 {
		u, err = e.incrementProgress(tx, userID, "night_owl", 1)
		if err != nil {
			return nil, err
		}
		unlocked = append(unlocked, u...)
	}

	return unlocked, nil
}

func (e *Engine) getDefinition(tx *gorm.DB, badgeID string) (*model.AchievementDefinition, error) {
	if tx == nil {
		tx = e.db
	}
	defs, err := e.loadDefinitions(tx)
	if err != nil {
		return nil, err
	}
	for i := range defs {
		if defs[i].ID == badgeID {
			return &defs[i], nil
		}
	}
	return nil, fmt.Errorf("achievement definition not found: %s", badgeID)
}

func (e *Engine) getOrCreateProgress(tx *gorm.DB, userID uint, badgeID string) (*model.UserAchievementProgress, error) {
	var p model.UserAchievementProgress
	err := tx.Where("user_id = ? AND badge_id = ?", userID, badgeID).First(&p).Error
	if err == gorm.ErrRecordNotFound {
		p = model.UserAchievementProgress{UserID: userID, BadgeID: badgeID}
		if err := tx.Create(&p).Error; err != nil {
			return nil, err
		}
		return &p, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (e *Engine) incrementProgress(tx *gorm.DB, userID uint, badgeID string, delta int) ([]UnlockResult, error) {
	if delta <= 0 {
		return nil, nil
	}
	p, err := e.getOrCreateProgress(tx, userID, badgeID)
	if err != nil {
		return nil, err
	}
	if p.UnlockedAt != nil {
		return nil, nil
	}
	p.CurrentCount += delta
	if err := tx.Save(p).Error; err != nil {
		return nil, err
	}
	return e.tryUnlock(tx, userID, badgeID, p)
}

func (e *Engine) addSumProgress(tx *gorm.DB, userID uint, badgeID string, delta int) ([]UnlockResult, error) {
	return e.incrementProgress(tx, userID, badgeID, delta)
}

func (e *Engine) setMaxProgress(tx *gorm.DB, userID uint, badgeID string, value int) ([]UnlockResult, error) {
	p, err := e.getOrCreateProgress(tx, userID, badgeID)
	if err != nil {
		return nil, err
	}
	if p.UnlockedAt != nil {
		return nil, nil
	}
	if value <= p.CurrentCount {
		return nil, nil
	}
	p.CurrentCount = value
	if err := tx.Save(p).Error; err != nil {
		return nil, err
	}
	return e.tryUnlock(tx, userID, badgeID, p)
}

func (e *Engine) evalFollowerCount(tx *gorm.DB, userID uint) ([]UnlockResult, error) {
	var count int64
	if err := tx.Model(&model.Follow{}).Where("following_id = ? AND deleted_at IS NULL", userID).Count(&count).Error; err != nil {
		return nil, err
	}
	return e.setMaxProgress(tx, userID, "influencer", int(count))
}

func (e *Engine) tryUnlock(tx *gorm.DB, userID uint, badgeID string, p *model.UserAchievementProgress) ([]UnlockResult, error) {
	def, err := e.getDefinition(tx, badgeID)
	if err != nil {
		// 成就定义未入库时不阻断发帖/点赞等业务（常见于未执行 rpc -migrate 种子）。
		return nil, nil
	}
	if p.UnlockedAt != nil || p.CurrentCount < def.RequiredCount {
		return nil, nil
	}

	now := time.Now()
	p.UnlockedAt = &now
	var results []UnlockResult
	expGranted := 0
	levelUp := false
	newLevel := 0

	if def.ExpReward > 0 && !p.ExpGranted {
		res, err := level.AddExperience(tx, userID, def.ExpReward, "achievement_unlock", badgeID,
			fmt.Sprintf("解锁成就「%s」获得%d经验", def.Name, def.ExpReward))
		if err != nil {
			return nil, err
		}
		expGranted = def.ExpReward
		levelUp = res.LevelUp
		newLevel = res.NewLevel
		p.ExpGranted = true
	}

	if err := tx.Save(p).Error; err != nil {
		return nil, err
	}

	results = append(results, UnlockResult{
		BadgeID:    badgeID,
		Name:       def.Name,
		ExpGranted: expGranted,
		NewLevel:   newLevel,
		LevelUp:    levelUp,
	})
	return results, nil
}

// EnsureUserInitialized unlocks welcome badge if needed (idempotent).
func (e *Engine) EnsureUserInitialized(tx *gorm.DB, userID uint) ([]UnlockResult, error) {
	return e.ApplyEvent(tx, userID, Event{Type: EventUserInitialized})
}

// BadgeDTO is API-facing achievement item.
type BadgeDTO struct {
	ID            string  `json:"id"`
	Name          string  `json:"name"`
	Description   string  `json:"description"`
	Category      string  `json:"category"`
	Rarity        string  `json:"rarity"`
	Condition     string  `json:"condition"`
	RequiredCount int     `json:"required_count"`
	CurrentCount  int     `json:"current_count"`
	Progress      float64 `json:"progress"`
	IsUnlocked    bool    `json:"is_unlocked"`
	UnlockedAt    string  `json:"unlocked_at,omitempty"`
}

// SummaryDTO is achievement statistics.
type SummaryDTO struct {
	TotalBadges          int     `json:"total_badges"`
	UnlockedBadges       int     `json:"unlocked_badges"`
	CompletionPercentage float64 `json:"completion_percentage"`
}

// ListUserAchievements returns all badges with progress for a user.
func (e *Engine) ListUserAchievements(tx *gorm.DB, userID uint, includeLocked bool) ([]BadgeDTO, error) {
	defs, err := e.loadDefinitions(tx)
	if err != nil {
		return nil, err
	}
	var progress []model.UserAchievementProgress
	if err := tx.Where("user_id = ?", userID).Find(&progress).Error; err != nil {
		return nil, err
	}
	progMap := make(map[string]model.UserAchievementProgress, len(progress))
	for _, p := range progress {
		progMap[p.BadgeID] = p
	}

	out := make([]BadgeDTO, 0, len(defs))
	for _, d := range defs {
		p, ok := progMap[d.ID]
		cur := 0
		unlocked := false
		var unlockedAt string
		if ok {
			cur = p.CurrentCount
			unlocked = p.UnlockedAt != nil
			if p.UnlockedAt != nil {
				unlockedAt = p.UnlockedAt.Format(time.RFC3339)
			}
		}
		if !includeLocked && !unlocked {
			continue
		}
		prog := 0.0
		if d.RequiredCount > 0 {
			prog = float64(cur) / float64(d.RequiredCount)
			if prog > 1 {
				prog = 1
			}
		}
		out = append(out, BadgeDTO{
			ID:            d.ID,
			Name:          d.Name,
			Description:   d.Description,
			Category:      d.Category,
			Rarity:        d.Rarity,
			Condition:     d.ConditionText,
			RequiredCount: d.RequiredCount,
			CurrentCount:  cur,
			Progress:      prog,
			IsUnlocked:    unlocked,
			UnlockedAt:    unlockedAt,
		})
	}
	return out, nil
}

// GetSummary returns achievement summary.
func (e *Engine) GetSummary(tx *gorm.DB, userID uint) (*SummaryDTO, error) {
	badges, err := e.ListUserAchievements(tx, userID, true)
	if err != nil {
		return nil, err
	}
	unlocked := 0
	for _, b := range badges {
		if b.IsUnlocked {
			unlocked++
		}
	}
	total := len(badges)
	pct := 0.0
	if total > 0 {
		pct = float64(unlocked) / float64(total) * 100
	}
	return &SummaryDTO{
		TotalBadges:          total,
		UnlockedBadges:       unlocked,
		CompletionPercentage: pct,
	}, nil
}

// ParseRuleParams decodes rule params JSON.
func ParseRuleParams(raw string, out interface{}) error {
	if raw == "" || raw == `{}` {
		return nil
	}
	return json.Unmarshal([]byte(raw), out)
}
