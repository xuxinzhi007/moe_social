package utils

import (
	"backend/model"
	"log"

	"gorm.io/gorm"
)

type achievementSeed struct {
	ID            string
	Name          string
	Description   string
	Category      string
	Rarity        string
	ConditionText string
	RuleType      string
	RequiredCount int
	RuleParams    string
	ExpReward     int
	SortOrder     int
}

func expByRarity(rarity string) int {
	switch rarity {
	case "uncommon":
		return 50
	case "rare":
		return 100
	case "epic":
		return 200
	case "legendary":
		return 500
	default:
		return 20
	}
}

func achievementSeeds() []achievementSeed {
	raw := []achievementSeed{
		{"welcome_aboard", "初来乍到", "完成首次登录，欢迎加入 Moe Social", "special", "common", "首次登录应用", model.RuleTypeOnce, 1, `{}`, 0, 1},
		{"first_post", "初出茅庐", "发布第一条动态", "social", "common", "发布1条动态", model.RuleTypeOnce, 1, `{}`, 0, 10},
		{"post_master", "内容达人", "持续分享，发布30条动态", "social", "rare", "发布30条动态", model.RuleTypeCounter, 30, `{"event":"post"}`, 0, 20},
		{"like_magnet", "点赞收割机", "单条动态获得20个点赞", "social", "epic", "单条动态获得20个点赞", model.RuleTypeMax, 20, `{"event":"post_likes"}`, 0, 30},
		{"social_butterfly", "社交达人", "发表评论20次", "social", "rare", "发表20条评论", model.RuleTypeCounter, 20, `{"event":"comment"}`, 0, 40},
		{"generous_giver", "慷慨之星", "送出5个礼物", "interaction", "uncommon", "送出5个礼物", model.RuleTypeCounter, 5, `{"event":"gift_sent"}`, 0, 50},
		{"gift_tycoon", "礼物大亨", "礼物总价值达到200", "interaction", "legendary", "礼物总价值达到200", model.RuleTypeSum, 200, `{"event":"gift_value"}`, 0, 60},
		{"emotion_expert", "情感专家", "发布动态时使用5次情绪标签", "interaction", "rare", "使用5次情绪标签", model.RuleTypeMoodTagPosts, 5, `{}`, 0, 70},
		{"early_bird", "早起鸟儿", "在早晨 8 点前发布3次动态", "time", "uncommon", "早于8点发布3条动态", model.RuleTypeTimeWindowCount, 3, `{"hour_before":8}`, 0, 80},
		{"night_owl", "夜猫子", "在夜间 23 点后发布3次动态", "time", "uncommon", "晚于23点发布3条动态", model.RuleTypeTimeWindowCount, 3, `{"hour_from":23}`, 0, 90},
		{"loyal_user", "忠实用户", "完成7次每日活跃签到", "time", "rare", "完成7次每日签到", model.RuleTypeCounter, 7, `{"event":"check_in"}`, 0, 100},
		{"daily_task_keeper", "日常打卡王", "完成5天日常任务组合", "time", "uncommon", "同一天完成至少2个日常任务，共5天", model.RuleTypeDailyComboDays, 5, `{"min_task_score":2}`, 0, 110},
		{"weekly_task_keeper", "周常执行官", "完成4次周常任务目标", "time", "rare", "同一周完成至少8个任务行为，共4周", model.RuleTypeWeeklyComboWeeks, 4, `{"min_weekly_total":8}`, 0, 120},
		{"vip_member", "VIP会员", "成为VIP会员", "special", "epic", "开通VIP会员", model.RuleTypeOnce, 1, `{"event":"vip"}`, 0, 130},
		{"trendsetter", "潮流引领者", "发布20条带话题动态", "special", "legendary", "累计发布20条带话题的动态", model.RuleTypeCounter, 20, `{"event":"post_with_topic"}`, 0, 140},
		{"photographer", "摄影师", "发布10张照片", "special", "uncommon", "发布10张照片", model.RuleTypeCounter, 10, `{"event":"post_with_image"}`, 0, 150},
		{"influencer", "意见领袖", "粉丝数量达到200", "special", "legendary", "粉丝数量达到200", model.RuleTypeFollowerCount, 200, `{}`, 0, 160},
		{"creative_genius", "创意天才", "获得3个手绘原创认证", "creative", "epic", "发布3个审核通过的手绘动态", model.RuleTypeHanddrawApproved, 3, `{}`, 0, 170},
		{"storyteller", "故事大王", "发布3个长文章", "creative", "rare", "发布3个长文章（>500字）", model.RuleTypeTimeWindowCount, 3, `{"min_content_len":500}`, 0, 180},
	}
	for i := range raw {
		if raw[i].ExpReward == 0 {
			raw[i].ExpReward = expByRarity(raw[i].Rarity)
		}
	}
	return raw
}

// SeedAchievementDefinitions inserts default achievement definitions.
func SeedAchievementDefinitions(db *gorm.DB) error {
	if db == nil {
		return nil
	}
	for _, s := range achievementSeeds() {
		def := model.AchievementDefinition{
			ID:            s.ID,
			Name:          s.Name,
			Description:   s.Description,
			Category:      s.Category,
			Rarity:        s.Rarity,
			ConditionText: s.ConditionText,
			RuleType:      s.RuleType,
			RequiredCount: s.RequiredCount,
			RuleParams:    s.RuleParams,
			ExpReward:     s.ExpReward,
			Enabled:       true,
			SortOrder:     s.SortOrder,
		}
		var existing model.AchievementDefinition
		if err := db.Where("id = ?", s.ID).First(&existing).Error; err != nil {
			if err := db.Create(&def).Error; err != nil {
				log.Printf("创建成就定义失败 %s: %v", s.ID, err)
				return err
			}
			log.Printf("创建成就定义: %s", s.ID)
		}
	}
	log.Println("成就定义初始化完成")
	return nil
}
