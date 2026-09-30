package moewiring

import (
	"context"
	"errors"
	"strconv"

	arenabiz "backend/internal/biz/arena"
	userbiz "backend/internal/biz/user"
	arenadata "backend/internal/data/arena"
	userdata "backend/internal/data/user"
	"backend/internal/platform/appdb"
	arenaapp "backend/internal/service/arena"
)

// NewAPIArenaService 装配星辉远征服务。
func NewAPIArenaService() (*arenaapp.AppService, error) {
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	repo := arenadata.NewRepo(db)
	uc := arenabiz.NewUsecase(repo)
	users := userdata.NewUserStore(db)
	uc.SetMembership(func(ctx context.Context, userID string) (bool, error) {
		id, err := strconv.ParseUint(userID, 10, 64)
		if err != nil || id == 0 {
			return false, nil
		}
		active, err := userbiz.CheckVipActive(ctx, users, uint(id))
		if errors.Is(err, userbiz.ErrNotFound) {
			return false, nil
		}
		return active, err
	})
	return arenaapp.New(uc), nil
}
