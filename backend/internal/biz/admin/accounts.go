package adminbiz

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// ListAccounts Admin 管理员账号列表。
func ListAccounts(ctx context.Context, db *gorm.DB, in *moe.AdminListAccountsReq) (*moe.AdminListAccountsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := db.WithContext(ctx).Model(&model.AdminAccount{})
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("username LIKE ? OR role LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListAccounts, err)
	}
	var rows []model.AdminAccount
	offset := int((page - 1) * pageSize)
	if err := q.Order("id ASC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListAccounts, err)
	}
	items := make([]*moe.AdminAccountItem, len(rows))
	for i, row := range rows {
		items[i] = adminAccountToProto(row)
	}
	return &moe.AdminListAccountsResp{Items: items, Total: int32(total)}, nil
}

// CreateAccount Admin 创建管理员账号。
func CreateAccount(ctx context.Context, db *gorm.DB, in *moe.AdminCreateAccountReq) (*moe.AdminCreateAccountResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	username := strings.TrimSpace(in.GetUsername())
	if username == "" {
		return nil, ErrEmptyAccountUsername
	}
	if strings.TrimSpace(in.GetPassword()) == "" {
		return nil, ErrEmptyAccountPassword
	}
	role := strings.TrimSpace(in.GetRole())
	if role == "" {
		role = "admin"
	}
	row := model.AdminAccount{
		Username: username,
		Password: in.GetPassword(),
		Role:     role,
	}
	if err := db.WithContext(ctx).Create(&row).Error; err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "duplicate") {
			return nil, ErrAccountDuplicate
		}
		return nil, fmt.Errorf("%w: %v", ErrCreateAccount, err)
	}
	return &moe.AdminCreateAccountResp{Account: adminAccountToProto(row)}, nil
}

// UpdateAccount Admin 更新管理员账号。
func UpdateAccount(ctx context.Context, db *gorm.DB, in *moe.AdminUpdateAccountReq) (*moe.AdminUpdateAccountResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	id, err := strconv.ParseUint(strings.TrimSpace(in.GetAccountId()), 10, 64)
	if err != nil || id == 0 {
		return nil, ErrInvalidAccountID
	}
	var row model.AdminAccount
	if err := db.WithContext(ctx).First(&row, id).Error; err != nil {
		return nil, ErrAccountNotFound
	}
	if in.GetUpdateUsername() || strings.TrimSpace(in.GetUsername()) != "" {
		username := strings.TrimSpace(in.GetUsername())
		if username == "" {
			return nil, ErrEmptyAccountUsername
		}
		row.Username = username
	}
	if in.GetUpdatePassword() || strings.TrimSpace(in.GetPassword()) != "" {
		if strings.TrimSpace(in.GetPassword()) == "" {
			return nil, ErrEmptyAccountPassword
		}
		row.Password = in.GetPassword()
	}
	if in.GetUpdateRole() || strings.TrimSpace(in.GetRole()) != "" {
		role := strings.TrimSpace(in.GetRole())
		if role == "" {
			return nil, ErrEmptyAccountRole
		}
		row.Role = role
	}
	if err := db.WithContext(ctx).Save(&row).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUpdateAccount, err)
	}
	return &moe.AdminUpdateAccountResp{Account: adminAccountToProto(row)}, nil
}

// DeleteAccount Admin 删除管理员账号。
func DeleteAccount(ctx context.Context, db *gorm.DB, in *moe.AdminDeleteAccountReq) (*moe.AdminDeleteAccountResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	id, err := strconv.ParseUint(strings.TrimSpace(in.GetAccountId()), 10, 64)
	if err != nil || id == 0 {
		return nil, ErrInvalidAccountID
	}
	if err := db.WithContext(ctx).First(&model.AdminAccount{}, id).Error; err != nil {
		return nil, ErrAccountNotFound
	}
	var count int64
	if err := db.WithContext(ctx).Model(&model.AdminAccount{}).Count(&count).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDeleteAccount, err)
	}
	if count <= 1 {
		return nil, ErrLastAdminAccount
	}
	if err := db.WithContext(ctx).Delete(&model.AdminAccount{}, id).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDeleteAccount, err)
	}
	return &moe.AdminDeleteAccountResp{}, nil
}
