//go:build hybrid

package moesocial

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	apirun "backend/api/runserver"
	"backend/api/moehttp"
	"backend/internal/platform/kratosprogress"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/zeromicro/go-zero/rest"
)

// kratosFrontServer PK-4：对外 Kratos HTTP（:8888）+ 内网 go-zero 回退。
type kratosFrontServer struct {
	publicAddr string
	legacy     *rest.Server
	khttp      *khttp.Server
}

func newKratosFrontServer(apiRes *apirun.StartResult, publicHost string, publicPort int) (*kratosFrontServer, error) {
	if apiRes == nil || apiRes.Server == nil || apiRes.Svc == nil {
		return nil, fmt.Errorf("kratos front: api start result required")
	}
	if publicPort <= 0 {
		publicPort = 8888
	}
	if strings.TrimSpace(publicHost) == "" {
		publicHost = "0.0.0.0"
	}
	publicAddr := fmt.Sprintf("%s:%d", publicHost, publicPort)

	legacyURL := &url.URL{Scheme: "http", Host: fmt.Sprintf("%s:%d", apiRes.Host, apiRes.Port)}
	proxy := httputil.NewSingleHostReverseProxy(legacyURL)
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		http.Error(w, "legacy api unavailable: "+err.Error(), http.StatusBadGateway)
	}

	httpSrv := khttp.NewServer(khttp.Address(publicAddr))
	moehttp.RegisterAll(httpSrv, pilotDepsFromAPI(apiRes))

	// 未匹配试点路由 → go-zero 内网（PathPrefix 优先级低于已注册的精确路径）
	httpSrv.HandlePrefix("/", proxy)

	return &kratosFrontServer{
		publicAddr: publicAddr,
		legacy:     apiRes.Server,
		khttp:      httpSrv,
	}, nil
}

func (s *kratosFrontServer) Start(ctx context.Context) error {
	if s == nil {
		return nil
	}
	legacyDone := make(chan struct{})
	go func() {
		s.legacy.Start()
		close(legacyDone)
	}()
	kratosDone := make(chan struct{})
	go func() {
		if err := s.khttp.Start(ctx); err != nil && ctx.Err() == nil {
			log.Printf("moe-social: kratos http front stopped: %v", err)
		}
		close(kratosDone)
	}()

	if err := waitTCPListen(s.publicAddr, 20); err != nil {
		_ = s.khttp.Stop(ctx)
		s.legacy.Stop()
		return err
	}
	rep := kratosprogress.Current()
	log.Printf("moe-social: PK-4 Kratos HTTP front %s (complete %d%%, rollout %d%%)", s.publicAddr, rep.Percent, rep.RolloutPercent)
	return nil
}

func (s *kratosFrontServer) Stop(ctx context.Context) error {
	if s == nil {
		return nil
	}
	if s.khttp != nil {
		_ = s.khttp.Stop(ctx)
	}
	if s.legacy != nil {
		s.legacy.Stop()
	}
	return nil
}

