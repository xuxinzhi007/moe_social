package communityapp

import (
	"context"
	communityv1 "backend/api/community/v1"
	communitybiz "backend/internal/biz/community"
)

func (s *AppService) CreateGroupPost(ctx context.Context, in *communityv1.CreateGroupPostRequest) (*communityv1.CreateGroupPostReply, error) {
	return communitybiz.CreateGroupPost(ctx, s.store, s.postStore, in)
}
