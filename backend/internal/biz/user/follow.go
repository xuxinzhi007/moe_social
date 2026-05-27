package userbiz

import (
	"context"
	"errors"
	"strconv"

	"backend/model"

	"gorm.io/gorm"
)

// Follow 关注用户（支持恢复软删除记录）。
func Follow(ctx context.Context, db *gorm.DB, followerID, followingID uint) error {
	if db == nil {
		return gorm.ErrInvalidDB
	}
	if followerID == 0 || followingID == 0 {
		return ErrInvalidArgument
	}

	var existing model.Follow
	result := db.WithContext(ctx).Unscoped().
		Where("follower_id = ? AND following_id = ?", followerID, followingID).
		First(&existing)
	if result.Error == nil {
		if existing.DeletedAt.Time.IsZero() {
			return nil
		}
		return db.WithContext(ctx).Unscoped().Model(&existing).
			Updates(map[string]interface{}{"deleted_at": nil}).Error
	}
	if !errors.Is(result.Error, gorm.ErrRecordNotFound) {
		return result.Error
	}

	return db.WithContext(ctx).Create(&model.Follow{
		FollowerID:  followerID,
		FollowingID: followingID,
	}).Error
}

// Unfollow 取消关注。
func Unfollow(ctx context.Context, db *gorm.DB, followerID, followingID uint) error {
	if db == nil {
		return gorm.ErrInvalidDB
	}
	if followerID == 0 || followingID == 0 {
		return ErrInvalidArgument
	}
	return db.WithContext(ctx).
		Where("follower_id = ? AND following_id = ?", followerID, followingID).
		Delete(&model.Follow{}).Error
}

// IsFollowing 是否已关注。
func IsFollowing(ctx context.Context, db *gorm.DB, followerID, followingID uint) (bool, error) {
	if db == nil {
		return false, gorm.ErrInvalidDB
	}
	var count int64
	err := db.WithContext(ctx).Model(&model.Follow{}).
		Where("follower_id = ? AND following_id = ? AND deleted_at IS NULL", followerID, followingID).
		Count(&count).Error
	return count > 0, err
}

// IsFollowingByStringID 使用字符串 ID 检查关注（与 legacy CheckFollow RPC 一致）。
func IsFollowingByStringID(ctx context.Context, db *gorm.DB, followerID, followingID string) (bool, error) {
	if db == nil {
		return false, gorm.ErrInvalidDB
	}
	var count int64
	err := db.WithContext(ctx).Model(&model.Follow{}).
		Where("follower_id = ? AND following_id = ? AND deleted_at IS NULL", followerID, followingID).
		Count(&count).Error
	return count > 0, err
}

// FollowListPage 分页参数。
type FollowListPage struct {
	Page     int32
	PageSize int32
}

func normalizeFollowPage(p FollowListPage) (page, pageSize, offset int32) {
	page = p.Page
	if page <= 0 {
		page = 1
	}
	pageSize = p.PageSize
	if pageSize <= 0 {
		pageSize = 10
	}
	offset = (page - 1) * pageSize
	return page, pageSize, offset
}

// FollowListResult 关注/粉丝列表。
type FollowListResult struct {
	Users []model.User
	Total int64
}

// ListFollowers 粉丝列表（following_id = userID）。
func ListFollowers(ctx context.Context, db *gorm.DB, userID uint, p FollowListPage) (FollowListResult, error) {
	if db == nil {
		return FollowListResult{}, gorm.ErrInvalidDB
	}
	_, pageSize, offset := normalizeFollowPage(p)

	var total int64
	base := db.WithContext(ctx).Model(&model.Follow{}).
		Where("following_id = ? AND deleted_at IS NULL", userID)
	if err := base.Count(&total).Error; err != nil {
		return FollowListResult{}, err
	}

	var follows []model.Follow
	if err := base.Order("created_at DESC").Offset(int(offset)).Limit(int(pageSize)).Find(&follows).Error; err != nil {
		return FollowListResult{}, err
	}

	ids := make([]uint, len(follows))
	for i := range follows {
		ids[i] = follows[i].FollowerID
	}
	users, err := usersInFollowOrder(ctx, db, ids)
	if err != nil {
		return FollowListResult{}, err
	}
	return FollowListResult{Users: users, Total: total}, nil
}

// ListFollowings 关注列表（follower_id = userID）。
func ListFollowings(ctx context.Context, db *gorm.DB, userID uint, p FollowListPage) (FollowListResult, error) {
	if db == nil {
		return FollowListResult{}, gorm.ErrInvalidDB
	}
	_, pageSize, offset := normalizeFollowPage(p)

	var total int64
	base := db.WithContext(ctx).Model(&model.Follow{}).
		Where("follower_id = ? AND deleted_at IS NULL", userID)
	if err := base.Count(&total).Error; err != nil {
		return FollowListResult{}, err
	}

	var follows []model.Follow
	if err := base.Order("created_at DESC").Offset(int(offset)).Limit(int(pageSize)).Find(&follows).Error; err != nil {
		return FollowListResult{}, err
	}

	ids := make([]uint, len(follows))
	for i := range follows {
		ids[i] = follows[i].FollowingID
	}
	users, err := usersInFollowOrder(ctx, db, ids)
	if err != nil {
		return FollowListResult{}, err
	}
	return FollowListResult{Users: users, Total: total}, nil
}

func usersInFollowOrder(ctx context.Context, db *gorm.DB, orderIDs []uint) ([]model.User, error) {
	if len(orderIDs) == 0 {
		return nil, nil
	}
	var users []model.User
	if err := db.WithContext(ctx).Where("id IN ?", orderIDs).Find(&users).Error; err != nil {
		return nil, err
	}
	userMap := make(map[uint]model.User, len(users))
	for i := range users {
		userMap[users[i].ID] = users[i]
	}
	out := make([]model.User, 0, len(orderIDs))
	for _, id := range orderIDs {
		if u, ok := userMap[id]; ok {
			out = append(out, u)
		}
	}
	return out, nil
}

// ParseFollowPair 解析关注双方 ID。
func ParseFollowPair(followerRaw, followingRaw string) (followerID, followingID uint, err error) {
	followerID, err = parseUserIDString(followerRaw)
	if err != nil {
		return 0, 0, err
	}
	followingID, err = parseUserIDString(followingRaw)
	if err != nil {
		return 0, 0, err
	}
	return followerID, followingID, nil
}

func parseUserIDString(raw string) (uint, error) {
	n, err := strconv.ParseUint(raw, 10, 32)
	if err != nil || n == 0 {
		return 0, ErrInvalidArgument
	}
	return uint(n), nil
}
