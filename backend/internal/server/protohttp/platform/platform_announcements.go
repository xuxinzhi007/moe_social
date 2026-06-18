package platformhttp

import (
	"context"

	platformv1 "backend/api/platform/v1"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

func (s *Server) ListAnnouncements(ctx context.Context, in *platformv1.ListAnnouncementsReq) (*platformv1.ListAnnouncementsResp, error) {
	svc, err := s.requireSvc()
	if err != nil {
		return nil, err
	}
	if svc.AdminApp == nil {
		return nil, kerrors.ServiceUnavailable("ADMIN_UNAVAILABLE", "admin service unavailable")
	}
	return svc.AdminApp.ListPublishedAnnouncements(ctx, in)
}

func (s *Server) GetAnnouncement(ctx context.Context, in *platformv1.GetAnnouncementReq) (*platformv1.GetAnnouncementResp, error) {
	svc, err := s.requireSvc()
	if err != nil {
		return nil, err
	}
	if svc.AdminApp == nil {
		return nil, kerrors.ServiceUnavailable("ADMIN_UNAVAILABLE", "admin service unavailable")
	}
	return svc.AdminApp.GetPublishedAnnouncement(ctx, in)
}
