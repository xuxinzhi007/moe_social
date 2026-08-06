package moewiring

import (
	"backend/internal/platform/appdb"
	userapp "backend/internal/service/user"
)

// NewAPIUserService API 进程内 User 应用服务。
func NewAPIUserService() (*userapp.AppService, error) {
	if !UserAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return userapp.New(db), nil
}
