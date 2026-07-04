package platformhttp

import (
	platformv1 "backend/api/platform/v1"
	llmbiz "backend/internal/biz/llm"
	voicebiz "backend/internal/biz/voice"
	"backend/internal/platform/svc"
	adminapp "backend/internal/service/admin"
	appcfgapp "backend/internal/service/appcfg"
	contentapp "backend/internal/service/content"
	llmapp "backend/internal/service/llm"
	moeadmin "backend/internal/service/moe"
	userapp "backend/internal/service/user"
	voiceapp "backend/internal/service/voice"
	"backend/pkg/llminference"
	"backend/utils"
)

type Deps struct {
	PublicAPIBaseURL string
	AdminApp         *adminapp.AppService
	MoeAdmin         *moeadmin.AdminService
	UserApp          *userapp.AppService
	LLMApp           *llmapp.AppService
	ModelCache       *utils.ModelCache
	InferenceConfig  llminference.Config
	ConfigSnapshot   llmbiz.ConfigSnapshot
	VoiceConfig      voicebiz.AgoraConfig
}

type Server struct {
	platformv1.UnimplementedPlatformServer
	deps        Deps
	appcfg      *appcfgapp.AppService
	contentApp  *contentapp.AppService
	moePlatform *moeadmin.PlatformApp
	voiceApp    *voiceapp.AppService
}

func New(deps Deps) *Server {
	s := &Server{deps: deps, contentApp: contentapp.New()}
	if deps.PublicAPIBaseURL != "" {
		s.appcfg = appcfgapp.New(deps.PublicAPIBaseURL)
	}
	if deps.MoeAdmin != nil {
		s.moePlatform = moeadmin.NewPlatform(newPlatformMoeToolExecutor(deps.MoeAdmin))
	}
	if deps.VoiceConfig.AppID != "" {
		s.voiceApp = voiceapp.New(newVoiceUserResolver(deps.UserApp), deps.VoiceConfig)
	}
	return s
}

func DepsFromServiceContext(svcCtx *svc.ServiceContext) Deps {
	if svcCtx == nil {
		return Deps{}
	}
	return Deps{
		PublicAPIBaseURL: svcCtx.Config.ClientPublicApiBaseUrl,
		AdminApp:         svcCtx.Domains.Access.AdminApp,
		MoeAdmin:         svcCtx.Domains.Access.MoeAdmin,
		UserApp:          svcCtx.Domains.Access.UserApp,
		LLMApp:           svcCtx.Domains.AI.LLMApp,
		ModelCache:       svcCtx.ModelCache,
		InferenceConfig:  platformInferenceCfgFromConfig(svcCtx.Config),
		ConfigSnapshot:   platformConfigSnapshotFromConfig(svcCtx.Config),
		VoiceConfig: voicebiz.AgoraConfig{
			AppID:          svcCtx.Config.Agora.AppId,
			AppCertificate: svcCtx.Config.Agora.AppCertificate,
		},
	}
}

func (s *Server) hasDeps() bool {
	return s != nil
}
