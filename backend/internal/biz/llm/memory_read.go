package llmbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

var (
	ErrMemoryNotFound = errors.New("用户记忆不存在")
)

// GetUserMemories 分页查询用户记忆（排除设备同步项）。
func GetUserMemories(ctx context.Context, db *gorm.DB, in *super.GetUserMemoriesReq) (*super.GetUserMemoriesResp, error) {
	if in.GetUserId() == "" {
		return nil, ErrMemoryEmptyUserID
	}
	userID, err := strconv.Atoi(in.GetUserId())
	if err != nil {
		return nil, ErrMemoryInvalidUser
	}

	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	offset := int(in.GetOffset())
	if offset < 0 {
		offset = 0
	}

	memScope := db.WithContext(ctx).Model(&model.UserMemory{}).
		Where("user_id = ?", uint(userID)).
		Where("`key` NOT LIKE ?", "device_info:%").
		Where("source <> ?", "device_sync")

	var total int64
	if err := memScope.Count(&total).Error; err != nil {
		return nil, err
	}

	var memories []model.UserMemory
	if err := memScope.Order("updated_at desc").Offset(offset).Limit(limit).Find(&memories).Error; err != nil {
		return nil, err
	}

	rpcMemories := make([]*super.UserMemory, 0, len(memories))
	for _, m := range memories {
		rpcMemories = append(rpcMemories, userMemoryToProto(m))
	}

	return &super.GetUserMemoriesResp{
		Memories: rpcMemories,
		Total:    total,
		Limit:    int32(limit),
		Offset:   int32(offset),
		HasMore:  int64(offset+len(rpcMemories)) < total,
	}, nil
}

// GetUserMemoryProfiles 返回用户画像缓存（必要时重建）。
func GetUserMemoryProfiles(ctx context.Context, db *gorm.DB, in *super.GetUserMemoryProfilesReq) (*super.GetUserMemoryProfilesResp, error) {
	if strings.TrimSpace(in.GetUserId()) == "" {
		return nil, ErrMemoryEmptyUserID
	}
	userID, err := strconv.Atoi(in.GetUserId())
	if err != nil {
		return nil, ErrMemoryInvalidUser
	}
	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 6
	}
	if limit > 20 {
		limit = 20
	}

	if err := EnsureUserMemoryProfileCache(db, uint(userID), false); err != nil {
		return nil, err
	}

	var caches []model.UserMemoryProfileCache
	if err := db.WithContext(ctx).Model(&model.UserMemoryProfileCache{}).
		Where("user_id = ?", uint(userID)).
		Order("item_count desc, confidence desc").
		Limit(limit).
		Find(&caches).Error; err != nil {
		return nil, err
	}

	profiles := make([]*super.UserMemoryProfile, 0, len(caches))
	for _, c := range caches {
		profiles = append(profiles, &super.UserMemoryProfile{
			MemoryType: c.MemoryType,
			Summary:    c.Summary,
			ItemCount:  int32(c.ItemCount),
			Confidence: c.Confidence,
		})
	}
	return &super.GetUserMemoryProfilesResp{Profiles: profiles}, nil
}

// DeleteUserMemory 按 user_id + key 删除记忆。
func DeleteUserMemory(ctx context.Context, db *gorm.DB, in *super.DeleteUserMemoryReq) (*super.DeleteUserMemoryResp, error) {
	if in.GetUserId() == "" {
		return nil, ErrMemoryEmptyUserID
	}
	if in.GetKey() == "" {
		return nil, ErrMemoryEmptyKey
	}
	userID, err := strconv.Atoi(in.GetUserId())
	if err != nil {
		return nil, ErrMemoryInvalidUser
	}

	result := db.WithContext(ctx).Where("user_id = ? AND `key` = ?", uint(userID), in.GetKey()).
		Delete(&model.UserMemory{})
	if result.Error != nil {
		return nil, result.Error
	}
	if result.RowsAffected == 0 {
		return nil, ErrMemoryNotFound
	}
	return &super.DeleteUserMemoryResp{}, nil
}

// EnsureUserMemoryProfileCache 若缓存过期则重建。
func EnsureUserMemoryProfileCache(db *gorm.DB, userID uint, force bool) error {
	if db == nil || userID == 0 {
		return nil
	}
	if force {
		return RebuildUserMemoryProfileCache(db, userID)
	}
	var latest model.UserMemoryProfileCache
	err := db.Where("user_id = ?", userID).Order("updated_at desc").First(&latest).Error
	if err == nil && time.Since(latest.UpdatedAt) < profileCacheStaleAfter {
		return nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	return RebuildUserMemoryProfileCache(db, userID)
}

// RebuildUserMemoryProfileCache 从记忆行重建画像缓存。
func RebuildUserMemoryProfileCache(db *gorm.DB, userID uint) error {
	return rebuildUserMemoryProfileCache(db, userID)
}
