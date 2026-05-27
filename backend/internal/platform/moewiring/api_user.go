package moewiring

import (
	userapp "backend/internal/service/user"
	"backend/utils"
)

// NewAPIUserService API 进程内 User 应用服务。
func NewAPIUserService() (*userapp.AppService, error) {
	if !UserAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return userapp.New(db), nil
}
