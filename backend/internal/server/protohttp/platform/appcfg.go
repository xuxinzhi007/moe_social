package platformhttp

import (
	"context"
	"errors"

	platformv1 "backend/api/platform/v1"
	appcfgapp "backend/internal/service/appcfg"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

func (s *Server) GetPublicClientConfig(ctx context.Context, _ *platformv1.GetPublicClientConfigReq) (*platformv1.GetPublicClientConfigResp, error) {
	if _, err := s.requireSvc(); err != nil {
		return nil, err
	}
	if s.appcfg == nil {
		return nil, kerrors.NotFound("NO_PUBLIC_API_BASE_URL", "not found")
	}
	url, err := s.appcfg.PublicClientConfig()
	if err != nil {
		if errors.Is(err, appcfgapp.ErrNoPublicAPIBaseURL) {
			return nil, kerrors.NotFound("NO_PUBLIC_API_BASE_URL", "not found")
		}
		return nil, err
	}
	return &platformv1.GetPublicClientConfigResp{ApiBaseUrl: url}, nil
}
