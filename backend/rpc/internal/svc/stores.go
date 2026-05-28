package svc

import (
	adminbiz "backend/internal/biz/admin"
	behaviorbiz "backend/internal/biz/behavior"
	chatbiz "backend/internal/biz/chat"
	commentbiz "backend/internal/biz/comment"
	communitybiz "backend/internal/biz/community"
	giftbiz "backend/internal/biz/gift"
	notifybiz "backend/internal/biz/notify"
	postbiz "backend/internal/biz/post"
	userbiz "backend/internal/biz/user"
	vipbiz "backend/internal/biz/vip"
	aibiz "backend/internal/biz/ai"
	llmbiz "backend/internal/biz/llm"
	moebiz "backend/internal/biz/moe"
	admindata "backend/internal/data/admin"
	aidata "backend/internal/data/ai"
	behaviordata "backend/internal/data/behavior"
	chatdata "backend/internal/data/chat"
	commentdata "backend/internal/data/comment"
	communitydata "backend/internal/data/community"
	giftdata "backend/internal/data/gift"
	llmdata "backend/internal/data/llm"
	moedata "backend/internal/data/moe"
	notifydata "backend/internal/data/notify"
	postdata "backend/internal/data/post"
	userdata "backend/internal/data/user"
	vipdata "backend/internal/data/vip"
)

// UserStore 用户持久化（P4-D lazy）。
func (s *ServiceContext) UserStore() userbiz.UserStore {
	if s.DB == nil {
		return nil
	}
	return userdata.NewUserStore(s.DB)
}

// AdminStore 管理台持久化。
func (s *ServiceContext) AdminStore() adminbiz.AdminStore {
	if s.DB == nil {
		return nil
	}
	return admindata.NewStore(s.DB)
}

// NotifyStore 通知持久化。
func (s *ServiceContext) NotifyStore() notifybiz.NotifyStore {
	if s.DB == nil {
		return nil
	}
	return notifydata.NewStore(s.DB)
}

// PostStore 帖子持久化。
func (s *ServiceContext) PostStore() postbiz.PostStore {
	if s.DB == nil {
		return nil
	}
	return postdata.NewStore(s.DB)
}

// CommentStore 评论持久化。
func (s *ServiceContext) CommentStore() commentbiz.CommentStore {
	if s.DB == nil {
		return nil
	}
	return commentdata.NewStore(s.DB)
}

// CommunityStore 社区持久化。
func (s *ServiceContext) CommunityStore() communitybiz.CommunityStore {
	if s.DB == nil {
		return nil
	}
	return communitydata.NewStore(s.DB)
}

// GiftStore 礼物持久化。
func (s *ServiceContext) GiftStore() giftbiz.GiftStore {
	if s.DB == nil {
		return nil
	}
	return giftdata.NewStore(s.DB)
}

// VipStore VIP 持久化。
func (s *ServiceContext) VipStore() vipbiz.VipStore {
	if s.DB == nil {
		return nil
	}
	return vipdata.NewStore(s.DB)
}

// ChatStore 私信持久化。
func (s *ServiceContext) ChatStore() chatbiz.PrivateMessageStore {
	if s.DB == nil {
		return nil
	}
	return chatdata.NewStore(s.DB)
}

// BehaviorStore 行为埋点持久化。
func (s *ServiceContext) BehaviorStore() behaviorbiz.BehaviorStore {
	if s.DB == nil {
		return nil
	}
	return behaviordata.NewStore(s.DB)
}

// MemoryStore LLM 记忆持久化（P4-D）。
func (s *ServiceContext) MemoryStore() llmbiz.MemoryStore {
	if s.DB == nil {
		return nil
	}
	return llmdata.NewStore(s.DB)
}

// AiStore AI 配置持久化（P4-D）。
func (s *ServiceContext) AiStore() aibiz.AiStore {
	if s.DB == nil {
		return nil
	}
	return aidata.NewStore(s.DB)
}

// MoeStore Moe 域持久化（P4-D）。
func (s *ServiceContext) MoeStore() moebiz.MoeStore {
	if s.DB == nil {
		return nil
	}
	return moedata.NewStore(s.DB)
}
