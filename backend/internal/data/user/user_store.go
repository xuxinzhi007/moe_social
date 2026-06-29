package userdata

import (
	"context"
	"errors"
	"time"

	userbiz "backend/internal/biz/user"
	"backend/model"

	"gorm.io/gorm"
)

type userStore struct {
	db *gorm.DB
}

// NewUserStore 构造 biz.UserStore（P4-D Lane C）。
func NewUserStore(db *gorm.DB) userbiz.UserStore {
	if db == nil {
		return nil
	}
	return &userStore{db: db}
}

func (s *userStore) Raw() *gorm.DB { return s.db }

func (s *userStore) WithContext(ctx context.Context) userbiz.UserStore {
	return &userStore{db: s.db.WithContext(ctx)}
}

func (s *userStore) GetUserByID(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).First(&user, userID).Error
	return user, err
}

func (s *userStore) UpdateUserFields(ctx context.Context, userID uint, updates map[string]interface{}) error {
	return s.db.WithContext(ctx).Model(&model.User{}).Where("id = ?", userID).Updates(updates).Error
}

func (s *userStore) ReloadUser(ctx context.Context, userID uint) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).First(&user, userID).Error
	return user, err
}

func (s *userStore) Begin(ctx context.Context) (userbiz.UserTx, error) {
	tx := s.db.WithContext(ctx).Begin()
	if tx.Error != nil {
		return nil, tx.Error
	}
	return &userTx{tx: tx}, nil
}

func (s *userStore) FindUserByNormalizedEmail(ctx context.Context, emailNorm string) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).Where("LOWER(TRIM(email)) = ?", emailNorm).First(&user).Error
	return user, err
}

func (s *userStore) FindUserByMoeNo(ctx context.Context, moeNo string) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).Where("moe_no = ?", moeNo).First(&user).Error
	return user, err
}

func (s *userStore) FindUserByUsername(ctx context.Context, username string) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).Where("username = ?", username).First(&user).Error
	return user, err
}

func (s *userStore) ExistsUserByUsername(ctx context.Context, username string) (bool, error) {
	var existing model.User
	err := s.db.WithContext(ctx).Where("username = ?", username).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return false, nil
	}
	return err == nil, err
}

func (s *userStore) ExistsUserByNormalizedEmail(ctx context.Context, emailNorm string) (bool, error) {
	var existing model.User
	err := s.db.WithContext(ctx).Where("LOWER(TRIM(email)) = ?", emailNorm).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return false, nil
	}
	return err == nil, err
}

func (s *userStore) CreateUser(ctx context.Context, user *model.User) error {
	return s.db.WithContext(ctx).Create(user).Error
}

func (s *userStore) SaveUser(ctx context.Context, user *model.User) error {
	return s.db.WithContext(ctx).Save(user).Error
}

func (s *userStore) DeleteUserHard(ctx context.Context, userID uint) error {
	return s.db.WithContext(ctx).Delete(&model.User{}, userID).Error
}

func (s *userStore) FindUserByEmail(ctx context.Context, email string) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).Where("email = ?", email).First(&user).Error
	return user, err
}

func (s *userStore) GetUserSelectedFields(ctx context.Context, userID uint, fields ...string) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).Select(fields).First(&user, userID).Error
	return user, err
}

func (s *userStore) CountUsers(ctx context.Context) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.User{}).Count(&total).Error
	return total, err
}

func (s *userStore) ListUsers(ctx context.Context, offset, limit int) ([]model.User, error) {
	var users []model.User
	err := s.db.WithContext(ctx).Offset(offset).Limit(limit).Find(&users).Error
	return users, err
}

func (s *userStore) FindFollowUnscoped(ctx context.Context, followerID, followingID uint) (model.Follow, bool, error) {
	var existing model.Follow
	err := s.db.WithContext(ctx).Unscoped().
		Where("follower_id = ? AND following_id = ?", followerID, followingID).
		First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.Follow{}, false, nil
	}
	return existing, err == nil, err
}

func (s *userStore) RestoreFollow(ctx context.Context, follow *model.Follow) error {
	return s.db.WithContext(ctx).Unscoped().Model(follow).
		Updates(map[string]interface{}{"deleted_at": nil}).Error
}

func (s *userStore) CreateFollow(ctx context.Context, follow *model.Follow) error {
	return s.db.WithContext(ctx).Create(follow).Error
}

func (s *userStore) DeleteFollow(ctx context.Context, followerID, followingID uint) error {
	return s.db.WithContext(ctx).
		Where("follower_id = ? AND following_id = ?", followerID, followingID).
		Delete(&model.Follow{}).Error
}

func (s *userStore) CountActiveFollow(ctx context.Context, followerID, followingID uint) (int64, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&model.Follow{}).
		Where("follower_id = ? AND following_id = ? AND deleted_at IS NULL", followerID, followingID).
		Count(&count).Error
	return count, err
}

func (s *userStore) CountFollowers(ctx context.Context, userID uint) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.Follow{}).
		Where("following_id = ? AND deleted_at IS NULL", userID).Count(&total).Error
	return total, err
}

func (s *userStore) ListFollowerRows(ctx context.Context, userID uint, offset, limit int) ([]model.Follow, error) {
	var follows []model.Follow
	err := s.db.WithContext(ctx).Model(&model.Follow{}).
		Where("following_id = ? AND deleted_at IS NULL", userID).
		Order("created_at DESC").Offset(offset).Limit(limit).Find(&follows).Error
	return follows, err
}

func (s *userStore) CountFollowings(ctx context.Context, userID uint) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.Follow{}).
		Where("follower_id = ? AND deleted_at IS NULL", userID).Count(&total).Error
	return total, err
}

func (s *userStore) ListFollowingRows(ctx context.Context, userID uint, offset, limit int) ([]model.Follow, error) {
	var follows []model.Follow
	err := s.db.WithContext(ctx).Model(&model.Follow{}).
		Where("follower_id = ? AND deleted_at IS NULL", userID).
		Order("created_at DESC").Offset(offset).Limit(limit).Find(&follows).Error
	return follows, err
}

func (s *userStore) FindUsersByIDs(ctx context.Context, ids []uint) ([]model.User, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	var users []model.User
	err := s.db.WithContext(ctx).Where("id IN ?", ids).Find(&users).Error
	return users, err
}

func (s *userStore) FindLatestFriendRequestBetween(ctx context.Context, a, b uint) (model.FriendRequest, bool, error) {
	var fr model.FriendRequest
	err := s.db.WithContext(ctx).Where(
		"(from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?)",
		a, b, b, a,
	).Order("id desc").First(&fr).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.FriendRequest{}, false, nil
	}
	return fr, err == nil, err
}

func (s *userStore) SaveFriendRequest(ctx context.Context, fr *model.FriendRequest) error {
	return s.db.WithContext(ctx).Save(fr).Error
}

func (s *userStore) CreateFriendRequest(ctx context.Context, fr *model.FriendRequest) error {
	return s.db.WithContext(ctx).Create(fr).Error
}

func (s *userStore) ReloadFriendRequest(ctx context.Context, id uint) (model.FriendRequest, error) {
	var fr model.FriendRequest
	err := s.db.WithContext(ctx).First(&fr, id).Error
	return fr, err
}

func (s *userStore) ListIncomingFriendRequests(ctx context.Context, actorID uint) ([]model.FriendRequest, error) {
	var list []model.FriendRequest
	err := s.db.WithContext(ctx).Where("to_user_id = ? AND status = ?", actorID, "pending").
		Order("id desc").Find(&list).Error
	return list, err
}

func (s *userStore) ListOutgoingFriendRequests(ctx context.Context, actorID uint) ([]model.FriendRequest, error) {
	var list []model.FriendRequest
	err := s.db.WithContext(ctx).Where("from_user_id = ? AND status = ?", actorID, "pending").
		Order("id desc").Find(&list).Error
	return list, err
}

func (s *userStore) GetFriendRequestByID(ctx context.Context, id uint) (model.FriendRequest, error) {
	var fr model.FriendRequest
	err := s.db.WithContext(ctx).First(&fr, id).Error
	return fr, err
}

func (s *userStore) ListAcceptedFriendRequests(ctx context.Context, actorID uint) ([]model.FriendRequest, error) {
	var list []model.FriendRequest
	err := s.db.WithContext(ctx).
		Where("status = ? AND (from_user_id = ? OR to_user_id = ?)", "accepted", actorID, actorID).
		Find(&list).Error
	return list, err
}

func (s *userStore) FindAcceptedFriendRelation(ctx context.Context, a, b uint) (model.FriendRequest, bool, error) {
	var acc model.FriendRequest
	err := s.db.WithContext(ctx).Where(
		"status = ? AND ((from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?))",
		"accepted", a, b, b, a,
	).First(&acc).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.FriendRequest{}, false, nil
	}
	return acc, err == nil, err
}

func (s *userStore) FindPendingFriendRequest(ctx context.Context, from, to uint) (model.FriendRequest, bool, error) {
	var p model.FriendRequest
	err := s.db.WithContext(ctx).
		Where("from_user_id = ? AND to_user_id = ? AND status = ?", from, to, "pending").
		First(&p).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.FriendRequest{}, false, nil
	}
	return p, err == nil, err
}

func (s *userStore) CountUserDevices(ctx context.Context, userID uint) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.UserDevice{}).Where("user_id = ?", userID).Count(&total).Error
	return total, err
}

func (s *userStore) ListUserDevices(ctx context.Context, userID uint, offset, limit int) ([]model.UserDevice, error) {
	var devices []model.UserDevice
	err := s.db.WithContext(ctx).Model(&model.UserDevice{}).Where("user_id = ?", userID).
		Order("last_seen_at desc").Offset(offset).Limit(limit).Find(&devices).Error
	return devices, err
}

func (s *userStore) FindUserDevice(ctx context.Context, userID uint, deviceID string) (model.UserDevice, bool, error) {
	var dev model.UserDevice
	err := s.db.WithContext(ctx).Where("user_id = ? AND device_id = ?", userID, deviceID).First(&dev).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.UserDevice{}, false, nil
	}
	return dev, err == nil, err
}

func (s *userStore) FindUserDeviceUnscoped(ctx context.Context, userID uint, deviceID string) (model.UserDevice, bool, error) {
	var deleted model.UserDevice
	err := s.db.WithContext(ctx).Unscoped().
		Where("user_id = ? AND device_id = ?", userID, deviceID).First(&deleted).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.UserDevice{}, false, nil
	}
	return deleted, err == nil, err
}

func (s *userStore) CreateUserDevice(ctx context.Context, dev *model.UserDevice) error {
	return s.db.WithContext(ctx).Omit("User").Create(dev).Error
}

func (s *userStore) SaveUserDeviceUnscoped(ctx context.Context, dev *model.UserDevice) error {
	return s.db.WithContext(ctx).Unscoped().Save(dev).Error
}

func (s *userStore) CountTransactions(ctx context.Context, userID int) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.Transaction{}).Where("user_id = ?", userID).Count(&total).Error
	return total, err
}

func (s *userStore) ListTransactions(ctx context.Context, userID int, offset, limit int) ([]model.Transaction, error) {
	var transactions []model.Transaction
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).
		Order("created_at DESC").Offset(offset).Limit(limit).Find(&transactions).Error
	return transactions, err
}

func (s *userStore) GetTransactionByID(ctx context.Context, id int) (model.Transaction, error) {
	var transaction model.Transaction
	err := s.db.WithContext(ctx).First(&transaction, id).Error
	return transaction, err
}

func (s *userStore) CountVipOrders(ctx context.Context, userID uint64) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.VipOrder{}).Where("user_id = ?", userID).Count(&total).Error
	return total, err
}

func (s *userStore) ListVipOrdersWithPlan(ctx context.Context, userID uint64, offset, limit int) ([]model.VipOrder, error) {
	var orders []model.VipOrder
	err := s.db.WithContext(ctx).Preload("Plan").
		Where("user_id = ?", userID).
		Offset(offset).Limit(limit).Find(&orders).Error
	return orders, err
}

func (s *userStore) ListVipOrdersByUserID(ctx context.Context, userID interface{}, offset, limit int) ([]model.VipOrder, error) {
	var orders []model.VipOrder
	err := s.db.WithContext(ctx).Preload("Plan").Where("user_id = ?", userID).
		Offset(offset).Limit(limit).Find(&orders).Error
	return orders, err
}

func (s *userStore) CountVipOrdersByUserID(ctx context.Context, userID interface{}) (int64, error) {
	var total int64
	err := s.db.WithContext(ctx).Model(&model.VipOrder{}).Where("user_id = ?", userID).Count(&total).Error
	return total, err
}

func (s *userStore) GetActiveVipOrder(ctx context.Context, userID interface{}) (model.VipOrder, error) {
	var order model.VipOrder
	err := s.db.WithContext(ctx).Where("user_id = ? AND is_active = ? AND end_at > ? AND status = ?",
		userID, true, time.Now(), "paid").First(&order).Error
	return order, err
}

func (s *userStore) GetVipPlan(ctx context.Context, planID interface{}) (model.VipPlan, error) {
	var plan model.VipPlan
	err := s.db.WithContext(ctx).First(&plan, planID).Error
	return plan, err
}

func (s *userStore) DeactivateVipOrders(ctx context.Context, userID uint) error {
	return s.db.WithContext(ctx).Model(&model.VipOrder{}).Where("user_id = ?", userID).Update("is_active", false).Error
}

func (s *userStore) CreateVipOrderRecord(ctx context.Context, order *model.VipOrder) error {
	return s.db.WithContext(ctx).Create(order).Error
}

func (s *userStore) GetUserAvatar(ctx context.Context, userID string) (model.UserAvatar, bool, error) {
	var userAvatar model.UserAvatar
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).First(&userAvatar).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return model.UserAvatar{}, false, nil
	}
	return userAvatar, err == nil, err
}

func (s *userStore) CreateUserAvatar(ctx context.Context, avatar *model.UserAvatar) error {
	return s.db.WithContext(ctx).Create(avatar).Error
}

func (s *userStore) UpdateUserAvatarFields(ctx context.Context, existing *model.UserAvatar, updates map[string]interface{}) error {
	return s.db.WithContext(ctx).Model(existing).Updates(updates).Error
}

func (s *userStore) FindUserByFeishuOpenID(ctx context.Context, openID string) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).Where("feishu_open_id = ?", openID).First(&user).Error
	return user, err
}

func (s *userStore) FindUserByWechatOpenID(ctx context.Context, openID string) (model.User, error) {
	var user model.User
	err := s.db.WithContext(ctx).Where("wechat_open_id = ?", openID).First(&user).Error
	return user, err
}

func (s *userStore) UsernameTaken(ctx context.Context, candidate string) (bool, error) {
	return s.ExistsUserByUsername(ctx, candidate)
}

func (s *userStore) UsernameTakenExcept(ctx context.Context, candidate string, excludeUserID uint) (bool, error) {
	var existing model.User
	err := s.db.WithContext(ctx).Where("username = ?", candidate).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if excludeUserID > 0 && existing.ID == excludeUserID {
		return false, nil
	}
	return true, nil
}

type userTx struct {
	tx *gorm.DB
}

func (t *userTx) GetUserForUpdate(userID interface{}) (model.User, error) {
	var user model.User
	err := t.tx.Set("gorm:query_option", "FOR UPDATE").First(&user, userID).Error
	return user, err
}

func (t *userTx) UpdateUserBalance(userID uint, balance float64) error {
	return t.tx.Model(&model.User{}).Where("id = ?", userID).UpdateColumn("balance", balance).Error
}

func (t *userTx) CreateTransaction(tr *model.Transaction) error {
	return t.tx.Create(tr).Error
}

func (t *userTx) SaveUser(user *model.User) error {
	return t.tx.Save(user).Error
}

func (t *userTx) GetVipPlan(planID interface{}) (model.VipPlan, error) {
	var plan model.VipPlan
	err := t.tx.First(&plan, planID).Error
	return plan, err
}

func (t *userTx) DeactivateVipOrders(userID uint) error {
	return t.tx.Model(&model.VipOrder{}).Where("user_id = ?", userID).Update("is_active", false).Error
}

func (t *userTx) CreateVipOrder(order *model.VipOrder) error {
	return t.tx.Create(order).Error
}

func (t *userTx) Commit() error   { return t.tx.Commit().Error }
func (t *userTx) Rollback() error { return t.tx.Rollback().Error }
func (t *userTx) DB() *gorm.DB    { return t.tx }
