package checkinapp

import (
	"context"
	checkinv1 "backend/api/checkin/v1"
	checkinbiz "backend/internal/biz/checkin"
)

func (s *AppService) GetExpLogs(ctx context.Context, in *checkinv1.GetExpLogsRequest) (*checkinv1.GetExpLogsReply, error) {
	logs, total, err := checkinbiz.ListExpLogs(ctx, s.store, in.GetUserId(), in.GetPage(), in.GetPageSize())
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetExpLogsReply{
		Logs:  logs,
		Total: total,
	}, nil
}

func (s *AppService) GetUserLevel(ctx context.Context, in *checkinv1.GetUserLevelRequest) (*checkinv1.GetUserLevelReply, error) {
	info, err := checkinbiz.GetUserLevel(ctx, s.store, in.GetUserId())
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetUserLevelReply{LevelInfo: info}, nil
}
