package viphttp

import (
	"context"

	vipv1 "backend/api/vip/v1"
	apicomm "backend/internal/platform/apicomm"
	userapp "backend/internal/service/user"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Server 实现 vip.v1.VipService HTTP/gRPC 适配。
type Server struct {
	vipv1.UnimplementedVipServiceServer
	app *userapp.AppService
}

// New 构造 Vip 服务。
func New(app *userapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*userapp.AppService, error) {
	if s.app == nil {
		return nil, errVipAppNil
	}
	return s.app, nil
}

func (s *Server) GetVipRecords(ctx context.Context, in *vipv1.GetVipRecordsReq) (*vipv1.GetVipRecordsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	return app.GetVipRecords(ctx, in)
}

func (s *Server) GetUserActiveVipRecord(ctx context.Context, in *vipv1.GetUserActiveVipRecordReq) (*vipv1.GetUserActiveVipRecordResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserActiveVipRecord(ctx, in)
}

func (s *Server) CreateVipOrder(ctx context.Context, in *vipv1.CreateVipOrderReq) (*vipv1.CreateVipOrderResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	return app.CreateVipOrder(ctx, in)
}

func (s *Server) GetUserVipStatus(ctx context.Context, in *vipv1.GetUserVipStatusReq) (*vipv1.GetUserVipStatusResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserVipStatus(ctx, in)
}

// UpdateUserVip 仅允许携带有效管理员 token（X-Admin-Token / admin_id context）的调用方执行，
// 防止普通用户调用 PUT /api/user/{user_id}/vip 免费给自己或他人开通 VIP。
func (s *Server) UpdateUserVip(ctx context.Context, in *vipv1.UpdateUserVipReq) (*vipv1.UpdateUserVipResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if ctx.Value("admin_id") == nil {
		if req, ok := khttp.RequestFromServerContext(ctx); ok && req != nil {
			if _, br := apicomm.RequireAdminToken(req); br != nil {
				return nil, status.Error(codes.PermissionDenied, "仅管理员可修改用户 VIP 状态")
			}
		} else if _, uerr := apicomm.UserIDString(ctx); uerr == nil {
			return nil, status.Error(codes.PermissionDenied, "仅管理员可修改用户 VIP 状态")
		}
	}
	return app.UpdateUserVip(ctx, in)
}

func (s *Server) UpdateAutoRenew(ctx context.Context, in *vipv1.UpdateAutoRenewReq) (*vipv1.UpdateAutoRenewResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	return app.UpdateAutoRenew(ctx, in)
}

func (s *Server) CheckUserVip(ctx context.Context, in *vipv1.CheckUserVipReq) (*vipv1.CheckUserVipResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.CheckUserVip(ctx, in)
}

func (s *Server) GetVipOrders(ctx context.Context, in *vipv1.GetVipOrdersReq) (*vipv1.GetVipOrdersResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	return app.GetVipOrders(ctx, in)
}

func (s *Server) SyncUserVipStatus(ctx context.Context, in *vipv1.SyncUserVipStatusReq) (*vipv1.SyncUserVipStatusResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	uid, err := apicomm.RequireSelfOrUnbound(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	in.UserId = uid
	return app.SyncUserVipStatus(ctx, in)
}
