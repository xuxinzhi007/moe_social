package moesocial

import (
	"context"
	"fmt"
	"log"
	"strings"

	apirun "backend/internal/platform/wiring"
	"backend/internal/server"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// kratosPureHTTPServer PK-8/9：纯 Kratos HTTP :8888，无 go-zero rest 监听。
type kratosPureHTTPServer struct {
	addr  string
	khttp *khttp.Server
}

func newKratosPureHTTPServer(apiRes *apirun.StartResult, publicHost string, publicPort int) (*kratosPureHTTPServer, error) {
	if apiRes == nil || apiRes.Svc == nil {
		return nil, fmt.Errorf("kratos pure http: api wire result required")
	}
	if publicPort <= 0 {
		publicPort = 8888
	}
	if strings.TrimSpace(publicHost) == "" {
		publicHost = "0.0.0.0"
	}
	addr := fmt.Sprintf("%s:%d", publicHost, publicPort)

	deps := pilotDepsFromAPI(apiRes)
	httpSrv, err := server.NewHTTPServer(addr, deps)
	if err != nil {
		return nil, err
	}

	return &kratosPureHTTPServer{addr: addr, khttp: httpSrv}, nil
}

func (s *kratosPureHTTPServer) Start(ctx context.Context) error {
	if s == nil || s.khttp == nil {
		return nil
	}
	done := make(chan struct{})
	go func() {
		if err := s.khttp.Start(ctx); err != nil && ctx.Err() == nil {
			log.Printf("moe-social: kratos pure http stopped: %v", err)
		}
		close(done)
	}()
	if err := waitTCPListen(s.addr, 20); err != nil {
		_ = s.khttp.Stop(ctx)
		return err
	}
	return nil
}

func (s *kratosPureHTTPServer) Stop(ctx context.Context) error {
	if s != nil && s.khttp != nil {
		return s.khttp.Stop(ctx)
	}
	return nil
}
