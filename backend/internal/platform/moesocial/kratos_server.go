//go:build hybrid

package moesocial

import (
	"context"

	"github.com/zeromicro/go-zero/rest"
)

// restServer 将 go-zero rest 适配为 kratos transport.Server。
type restServer struct {
	inner *rest.Server
}

func (s *restServer) Start(ctx context.Context) error {
	if s.inner == nil {
		return nil
	}
	done := make(chan struct{})
	go func() {
		s.inner.Start()
		close(done)
	}()
	select {
	case <-ctx.Done():
		s.inner.Stop()
		return ctx.Err()
	case <-done:
		return nil
	}
}

func (s *restServer) Stop(ctx context.Context) error {
	if s.inner != nil {
		s.inner.Stop()
	}
	return nil
}

func wrapREST(s *rest.Server) *restServer { return &restServer{inner: s} }
