package checkingrpc

import (
	"context"

	checkinv1 "backend/api/checkin/v1"
	checkinapp "backend/internal/service/checkin"
	moerpc "backend/rpc/pb/moe"
)

// Server 实现 checkin.v1.Checkin gRPC（P4-C；与 Super 并存）。
type Server struct {
	checkinv1.UnimplementedCheckinServer
	app *checkinapp.AppService
}

// New 构造 Checkin gRPC 服务。
func New(app *checkinapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*checkinapp.AppService, error) {
	if s.app == nil {
		return nil, errCheckinAppNil
	}
	return s.app, nil
}

func (s *Server) CheckIn(ctx context.Context, in *checkinv1.CheckInRequest) (*checkinv1.CheckInReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.CheckIn(ctx, &moerpc.CheckInReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &checkinv1.CheckInReply{
		ExpGained: resp.GetExpGained(), NewLevel: resp.GetNewLevel(),
		ConsecutiveDays: resp.GetConsecutiveDays(), LevelUp: resp.GetLevelUp(),
		SpecialReward:   resp.GetSpecialReward(),
		NewAchievements: achievementUnlocksToProto(resp.GetNewAchievements()),
	}, nil
}

func (s *Server) GetUserLevel(ctx context.Context, in *checkinv1.GetUserLevelRequest) (*checkinv1.GetUserLevelReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetUserLevel(ctx, &moerpc.GetUserLevelReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetUserLevelReply{LevelInfo: userLevelToProto(resp.GetLevelInfo())}, nil
}

func (s *Server) GetCheckInStatus(ctx context.Context, in *checkinv1.GetCheckInStatusRequest) (*checkinv1.GetCheckInStatusReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetCheckInStatus(ctx, &moerpc.GetCheckInStatusReq{UserId: in.GetUserId()})
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetCheckInStatusReply{Status: checkInStatusToProto(resp.GetStatus())}, nil
}

func (s *Server) GetCheckInHistory(ctx context.Context, in *checkinv1.GetCheckInHistoryRequest) (*checkinv1.GetCheckInHistoryReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetCheckInHistory(ctx, &moerpc.GetCheckInHistoryReq{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetCheckInHistoryReply{
		Records: checkInRecordsToProto(resp.GetRecords()), Total: resp.GetTotal(),
	}, nil
}

func (s *Server) GetExpLogs(ctx context.Context, in *checkinv1.GetExpLogsRequest) (*checkinv1.GetExpLogsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.GetExpLogs(ctx, &moerpc.GetExpLogsReq{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	})
	if err != nil {
		return nil, err
	}
	return &checkinv1.GetExpLogsReply{
		Logs: expLogsToProto(resp.GetLogs()), Total: resp.GetTotal(),
	}, nil
}
