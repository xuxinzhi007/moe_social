package userbiz

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"

	"backend/model"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// AvatarPackRevisionItem 角色包版本快照。
type AvatarPackRevisionItem struct {
	ID        string          `json:"id"`
	UserID    string          `json:"user_id"`
	PackID    string          `json:"pack_id"`
	Version   string          `json:"version"`
	Manifest  json.RawMessage `json:"manifest"`
	Artifacts json.RawMessage `json:"artifacts"`
	CreatedAt string          `json:"created_at"`
	UpdatedAt string          `json:"updated_at"`
}

// UpsertAvatarPackRevision 保存或覆盖一个版本的角色包快照。
func UpsertAvatarPackRevision(ctx context.Context, store UserStore, userID, packID, version string, manifest, artifacts json.RawMessage) (*AvatarPackRevisionItem, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID = strings.TrimSpace(userID)
	packID = strings.TrimSpace(packID)
	version = strings.TrimSpace(version)
	if userID == "" || packID == "" || version == "" {
		return nil, ErrInvalidArgument
	}
	manifestJSON, err := normalizeJSONPayload(manifest, false)
	if err != nil {
		return nil, err
	}
	artifactsJSON, err := normalizeJSONPayload(artifacts, true)
	if err != nil {
		return nil, err
	}
	revision := model.AvatarPackRevision{
		ID:            uuid.NewString(),
		UserID:        userID,
		PackID:        packID,
		Version:       version,
		ManifestJSON:  manifestJSON,
		ArtifactsJSON: artifactsJSON,
	}
	if err := store.UpsertAvatarPackRevision(ctx, &revision); err != nil {
		return nil, err
	}
	stored, _, err := store.GetAvatarPackRevision(ctx, userID, packID, version)
	if err != nil {
		return nil, err
	}
	return avatarPackRevisionFromModel(stored), nil
}

// GetAvatarPackRevision 获取指定版本的角色包快照。
func GetAvatarPackRevision(ctx context.Context, store UserStore, userID, packID, version string) (*AvatarPackRevisionItem, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID = strings.TrimSpace(userID)
	packID = strings.TrimSpace(packID)
	version = strings.TrimSpace(version)
	if userID == "" || packID == "" || version == "" {
		return nil, ErrInvalidArgument
	}
	revision, found, err := store.GetAvatarPackRevision(ctx, userID, packID, version)
	if err != nil {
		return nil, err
	}
	if !found {
		return nil, ErrNotFound
	}
	return avatarPackRevisionFromModel(revision), nil
}

// GetLatestAvatarPackRevision 获取最近保存的角色包快照。
func GetLatestAvatarPackRevision(ctx context.Context, store UserStore, userID, packID string) (*AvatarPackRevisionItem, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID = strings.TrimSpace(userID)
	packID = strings.TrimSpace(packID)
	if userID == "" || packID == "" {
		return nil, ErrInvalidArgument
	}
	revision, found, err := store.GetLatestAvatarPackRevision(ctx, userID, packID)
	if err != nil {
		return nil, err
	}
	if !found {
		return nil, ErrNotFound
	}
	return avatarPackRevisionFromModel(revision), nil
}

func avatarPackRevisionFromModel(revision model.AvatarPackRevision) *AvatarPackRevisionItem {
	item := &AvatarPackRevisionItem{
		ID:        revision.ID,
		UserID:    revision.UserID,
		PackID:    revision.PackID,
		Version:   revision.Version,
		Manifest:  json.RawMessage(bytes.TrimSpace([]byte(revision.ManifestJSON))),
		Artifacts: json.RawMessage(bytes.TrimSpace([]byte(revision.ArtifactsJSON))),
		CreatedAt: revision.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt: revision.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
	return item
}

func normalizeJSONPayload(raw json.RawMessage, allowEmptyAsArray bool) (string, error) {
	trimmed := bytes.TrimSpace([]byte(raw))
	if len(trimmed) == 0 {
		if allowEmptyAsArray {
			return "[]", nil
		}
		return "", ErrInvalidArgument
	}
	if !json.Valid(trimmed) {
		return "", ErrInvalidArgument
	}
	return string(trimmed), nil
}
