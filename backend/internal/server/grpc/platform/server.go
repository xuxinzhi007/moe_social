package platformgrpc

import (
	platformv1 "backend/api/platform/v1"
	"backend/internal/platform/svc"
	appcfgapp "backend/internal/service/appcfg"
	contentapp "backend/internal/service/content"
	moeadmin "backend/internal/service/moe"
	voiceapp "backend/internal/service/voice"
)

// Server 实现 platform.v1.Platform gRPC/HTTP（D2 compat 迁入）。
type Server struct {
	platformv1.UnimplementedPlatformServer
	svcCtx       *svc.ServiceContext
	appcfg       *appcfgapp.AppService
	contentApp   *contentapp.AppService
	moePlatform  *moeadmin.PlatformApp
	voiceApp     *voiceapp.AppService
}

// New 构造 Platform gRPC/HTTP 服务。
func New(svcCtx *svc.ServiceContext) *Server {
	if svcCtx == nil {
		return &Server{}
	}
	return &Server{
		svcCtx:      svcCtx,
		appcfg:      appcfgapp.New(svcCtx.Config.ClientPublicApiBaseUrl),
		contentApp:  contentapp.New(),
		moePlatform: moeadmin.NewPlatform(newPlatformMoeToolExecutor(svcCtx)),
		voiceApp:    newVoiceApp(svcCtx),
	}
}

func (s *Server) requireSvc() (*svc.ServiceContext, error) {
	if s.svcCtx == nil {
		return nil, errSvcCtxNil
	}
	return s.svcCtx, nil
}
