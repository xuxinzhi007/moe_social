package checkinapp

import (
	"context"
	"strings"

	checkinv1 "backend/api/checkin/v1"
	checkinbiz "backend/internal/biz/checkin"
)

func (s *AppService) ClaimDailyExp(ctx context.Context, in *checkinv1.ClaimDailyExpRequest) (*checkinv1.ClaimDailyExpReply, error) {
	action := checkinbiz.DailyExpAction(strings.TrimSpace(in.GetAction()))
	if action != checkinbiz.DailyExpActionBrowse {
		return &checkinv1.ClaimDailyExpReply{}, nil
	}
	result, err := checkinbiz.GrantDailyExpOnce(ctx, s.store, in.GetUserId(), action)
	if err != nil {
		return nil, err
	}
	return &checkinv1.ClaimDailyExpReply{
		Granted:   result.Granted,
		ExpGained: int32(result.ExpGained),
		LevelUp:   result.LevelUp,
		NewLevel:  int32(result.NewLevel),
	}, nil
}
