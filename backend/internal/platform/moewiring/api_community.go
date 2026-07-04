package moewiring

import (
	communityapp "backend/internal/service/community"
	"backend/utils"
)

func CommunityAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.community_api_in_process")
}

func NewAPICommunityService() (*communityapp.AppService, error) {
	if !CommunityAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return communityapp.New(db), nil
}
