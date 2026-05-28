package achievementgrpc

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errAchievementAppNil = status.Error(codes.FailedPrecondition, "AchievementApp 未初始化")
