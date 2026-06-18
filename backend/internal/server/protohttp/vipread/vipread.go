package vipreadhttp

import (
	"context"

	vipv1 "backend/api/vip/v1"
	vipbiz "backend/internal/biz/vip"
	vipadmin "backend/internal/service/vip"
)

// Server 实现 vip.v1.VipReadAdmin gRPC/HTTP。
type Server struct {
	vipv1.UnimplementedVipReadAdminServer
	admin *vipadmin.AdminService
}

// New 构造 VipReadAdmin gRPC/HTTP 服务。
func New(admin *vipadmin.AdminService) *Server {
	return &Server{admin: admin}
}

func (s *Server) requireAdmin() (*vipadmin.AdminService, error) {
	if s.admin == nil {
		return nil, errVipAdminNil
	}
	return s.admin, nil
}

func (s *Server) ListPlans(ctx context.Context, in *vipv1.ListPlansRequest) (*vipv1.ListPlansReply, error) {
	admin, err := s.requireAdmin()
	if err != nil {
		return nil, err
	}
	rows, total, err := admin.ListPlans(ctx, vipbiz.ListPlansFilter{
		Page:     int(in.GetPage()),
		PageSize: int(in.GetPageSize()),
		Keyword:  in.GetKeyword(),
	})
	if err != nil {
		return nil, err
	}
	items := make([]*vipv1.VipPlanView, 0, len(rows))
	for i := range rows {
		p := rows[i]
		items = append(items, &vipv1.VipPlanView{
			Id:           uint64(p.ID),
			Name:         p.Name,
			Price:        p.Price,
			DurationDays: int32(p.Duration),
		})
	}
	return &vipv1.ListPlansReply{Items: items, Total: total}, nil
}
