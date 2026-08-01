package userbiz

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// ProfileStore 用户资料持久化（P4-D3）。
type ProfileStore interface {
	GetUserByID(ctx context.Context, userID uint) (model.User, error)
	UpdateUserFields(ctx context.Context, userID uint, updates map[string]interface{}) error
	ReloadUser(ctx context.Context, userID uint) (model.User, error)
}

// UserStore 用户域持久化（P4-D Lane C）。
type UserStore interface {
	ProfileStore

	Raw() *gorm.DB
	WithContext(ctx context.Context) UserStore
	Begin(ctx context.Context) (UserTx, error)

	FindUserByNormalizedEmail(ctx context.Context, emailNorm string) (model.User, error)
	FindUserByMoeNo(ctx context.Context, moeNo string) (model.User, error)
	FindUserByUsername(ctx context.Context, username string) (model.User, error)
	ExistsUserByUsername(ctx context.Context, username string) (bool, error)
	ExistsUserByNormalizedEmail(ctx context.Context, emailNorm string) (bool, error)
	CreateUser(ctx context.Context, user *model.User) error
	SaveUser(ctx context.Context, user *model.User) error
	DeleteUserHard(ctx context.Context, userID uint) error
	FindUserByEmail(ctx context.Context, email string) (model.User, error)
	GetUserSelectedFields(ctx context.Context, userID uint, fields ...string) (model.User, error)

	CountUsers(ctx context.Context) (int64, error)
	ListUsers(ctx context.Context, offset, limit int) ([]model.User, error)

	FindFollowUnscoped(ctx context.Context, followerID, followingID uint) (model.Follow, bool, error)
	RestoreFollow(ctx context.Context, follow *model.Follow) error
	CreateFollow(ctx context.Context, follow *model.Follow) error
	DeleteFollow(ctx context.Context, followerID, followingID uint) error
	CountActiveFollow(ctx context.Context, followerID, followingID uint) (int64, error)
	CountFollowers(ctx context.Context, userID uint) (int64, error)
	ListFollowerRows(ctx context.Context, userID uint, offset, limit int) ([]model.Follow, error)
	CountFollowings(ctx context.Context, userID uint) (int64, error)
	ListFollowingRows(ctx context.Context, userID uint, offset, limit int) ([]model.Follow, error)
	FindUsersByIDs(ctx context.Context, ids []uint) ([]model.User, error)

	FindLatestFriendRequestBetween(ctx context.Context, a, b uint) (model.FriendRequest, bool, error)
	SaveFriendRequest(ctx context.Context, fr *model.FriendRequest) error
	CreateFriendRequest(ctx context.Context, fr *model.FriendRequest) error
	ReloadFriendRequest(ctx context.Context, id uint) (model.FriendRequest, error)
	ListIncomingFriendRequests(ctx context.Context, actorID uint) ([]model.FriendRequest, error)
	ListOutgoingFriendRequests(ctx context.Context, actorID uint) ([]model.FriendRequest, error)
	GetFriendRequestByID(ctx context.Context, id uint) (model.FriendRequest, error)
	ListAcceptedFriendRequests(ctx context.Context, actorID uint) ([]model.FriendRequest, error)
	FindAcceptedFriendRelation(ctx context.Context, a, b uint) (model.FriendRequest, bool, error)
	FindPendingFriendRequest(ctx context.Context, from, to uint) (model.FriendRequest, bool, error)

	CountUserDevices(ctx context.Context, userID uint) (int64, error)
	ListUserDevices(ctx context.Context, userID uint, offset, limit int) ([]model.UserDevice, error)
	FindUserDevice(ctx context.Context, userID uint, deviceID string) (model.UserDevice, bool, error)
	FindUserDeviceUnscoped(ctx context.Context, userID uint, deviceID string) (model.UserDevice, bool, error)
	CreateUserDevice(ctx context.Context, dev *model.UserDevice) error
	SaveUserDeviceUnscoped(ctx context.Context, dev *model.UserDevice) error

	CountTransactions(ctx context.Context, userID int) (int64, error)
	ListTransactions(ctx context.Context, userID int, offset, limit int) ([]model.Transaction, error)
	GetTransactionByID(ctx context.Context, id int) (model.Transaction, error)

	CountVipOrders(ctx context.Context, userID uint64) (int64, error)
	ListVipOrdersWithPlan(ctx context.Context, userID uint64, offset, limit int) ([]model.VipOrder, error)
	ListVipOrdersByUserID(ctx context.Context, userID interface{}, offset, limit int) ([]model.VipOrder, error)
	CountVipOrdersByUserID(ctx context.Context, userID interface{}) (int64, error)
	GetActiveVipOrder(ctx context.Context, userID interface{}) (model.VipOrder, error)
	GetVipPlan(ctx context.Context, planID interface{}) (model.VipPlan, error)
	DeactivateVipOrders(ctx context.Context, userID uint) error
	CreateVipOrderRecord(ctx context.Context, order *model.VipOrder) error

	GetUserAvatar(ctx context.Context, userID string) (model.UserAvatar, bool, error)
	CreateUserAvatar(ctx context.Context, avatar *model.UserAvatar) error
	UpdateUserAvatarFields(ctx context.Context, existing *model.UserAvatar, updates map[string]interface{}) error

	UpsertAvatarPackRevision(ctx context.Context, revision *model.AvatarPackRevision) error
	GetAvatarPackRevision(ctx context.Context, userID, packID, version string) (model.AvatarPackRevision, bool, error)
	GetLatestAvatarPackRevision(ctx context.Context, userID, packID string) (model.AvatarPackRevision, bool, error)

	FindUserByFeishuOpenID(ctx context.Context, openID string) (model.User, error)
	FindUserByWechatOpenID(ctx context.Context, openID string) (model.User, error)
	UsernameTaken(ctx context.Context, candidate string) (bool, error)
	UsernameTakenExcept(ctx context.Context, candidate string, excludeUserID uint) (bool, error)
}

// UserTx 用户域事务。
type UserTx interface {
	GetUserForUpdate(userID interface{}) (model.User, error)
	UpdateUserBalance(userID uint, balance float64) error
	CreateTransaction(t *model.Transaction) error
	SaveUser(user *model.User) error
	GetVipPlan(planID interface{}) (model.VipPlan, error)
	DeactivateVipOrders(userID uint) error
	CreateVipOrder(order *model.VipOrder) error
	Commit() error
	Rollback() error
	DB() *gorm.DB
}
