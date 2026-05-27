package adminbiz

import "errors"

var (
	ErrListAccounts        = errors.New("list accounts failed")
	ErrEmptyAccountUsername = errors.New("empty account username")
	ErrEmptyAccountPassword = errors.New("empty account password")
	ErrEmptyAccountRole     = errors.New("empty account role")
	ErrInvalidAccountID     = errors.New("invalid account id")
	ErrAccountNotFound      = errors.New("account not found")
	ErrAccountDuplicate     = errors.New("account duplicate")
	ErrCreateAccount        = errors.New("create account failed")
	ErrUpdateAccount        = errors.New("update account failed")
	ErrDeleteAccount        = errors.New("delete account failed")
	ErrLastAdminAccount     = errors.New("last admin account")
)
