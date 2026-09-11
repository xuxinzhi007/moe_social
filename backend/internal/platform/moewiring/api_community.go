package moewiring

import (
	"backend/internal/platform/appdb"
	communityapp "backend/internal/service/community"
	"backend/pkg/conf"
)

func CommunityAPIInProcessEnabled() bool {
	return conf.DomainInProcess("community")
}

func NewAPICommunityService() (*communityapp.AppService, error) {
	if !CommunityAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return communityapp.New(db), nil
}
