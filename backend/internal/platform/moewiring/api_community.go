package moewiring

import (
	"backend/internal/platform/appdb"
	communityapp "backend/internal/service/community"
)

func CommunityAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.community_api_in_process")
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
