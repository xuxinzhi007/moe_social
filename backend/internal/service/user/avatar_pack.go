package userapp

import (
	"context"
	"encoding/json"

	userbiz "backend/internal/biz/user"
)

// UpsertAvatarPackRevision 保存角色包版本快照。
func (s *AppService) UpsertAvatarPackRevision(ctx context.Context, userID, packID, version string, manifest, artifacts json.RawMessage) (*userbiz.AvatarPackRevisionItem, error) {
	return userbiz.UpsertAvatarPackRevision(ctx, s.store, userID, packID, version, manifest, artifacts)
}

// GetAvatarPackRevision 获取指定版本的角色包快照。
func (s *AppService) GetAvatarPackRevision(ctx context.Context, userID, packID, version string) (*userbiz.AvatarPackRevisionItem, error) {
	return userbiz.GetAvatarPackRevision(ctx, s.store, userID, packID, version)
}

// GetLatestAvatarPackRevision 获取最近保存的角色包快照。
func (s *AppService) GetLatestAvatarPackRevision(ctx context.Context, userID, packID string) (*userbiz.AvatarPackRevisionItem, error) {
	return userbiz.GetLatestAvatarPackRevision(ctx, s.store, userID, packID)
}
