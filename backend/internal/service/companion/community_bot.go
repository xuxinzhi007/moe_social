package companionapp

import (
	"context"
	"fmt"
	"strings"

	companionbiz "backend/internal/biz/companion"
	"backend/model"
)

// ensureCommunityBot 保证伙伴有可发帖的 bot 用户：无则创建，有则同步展示名/头像。
func (s *AppService) ensureCommunityBot(
	ctx context.Context,
	ownerUserID uint,
	profile *companionbiz.Profile,
) (*model.User, string, error) {
	if s == nil || s.identityStore == nil || profile == nil {
		return nil, "", nil
	}

	agentID := strings.TrimSpace(profile.AgentID)
	if agentID == "" {
		agentID = fmt.Sprintf("companion-%d", ownerUserID)
		profile.AgentID = agentID
		engine, err := s.requireEngine()
		if err == nil && engine != nil {
			_, _ = engine.UpsertProfile(ctx, ownerUserID, profile)
		}
	}

	botUser, err := s.identityStore.EnsureCommunityBot(
		ctx,
		ownerUserID,
		agentID,
		profile.Name,
		profile.AvatarURL,
		profile.Persona,
	)
	if err != nil {
		return nil, "", err
	}
	return botUser, agentID, nil
}
