package adminbiz

import "errors"

var (
	ErrListLevelConfigs     = errors.New("list level configs failed")
	ErrInvalidLevelID       = errors.New("invalid level id")
	ErrLevelConfigNotFound  = errors.New("level config not found")
	ErrUpdateLevelConfig    = errors.New("update level config failed")
	ErrBootstrapLevels      = errors.New("bootstrap levels failed")
	ErrListCheckInRewards   = errors.New("list check-in rewards failed")
	ErrInvalidCheckInRewardID = errors.New("invalid check-in reward id")
	ErrCheckInRewardNotFound  = errors.New("check-in reward not found")
	ErrUpdateCheckInReward    = errors.New("update check-in reward failed")
)
