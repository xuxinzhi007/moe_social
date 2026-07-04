package platformhttp

import (
	"context"
	"errors"
	"net/http"
	"reflect"
	"strconv"
	"strings"

	platformv1 "backend/api/platform/v1"
	userv1 "backend/api/user/v1"
	"backend/internal/apilegacy/common"
	contentbiz "backend/internal/biz/content"
	llmbiz "backend/internal/biz/llm"
	moebiz "backend/internal/biz/moe"
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

	kerrors "github.com/go-kratos/kratos/v2/errors"
	"github.com/go-kratos/kratos/v2/transport"
	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
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

var (
	errPlatformUnavailable = status.Error(codes.FailedPrecondition, "platform dependencies not initialized")
	errLLMAppNil           = status.Error(codes.FailedPrecondition, "LLMApp not initialized")
	errUnauthorized        = status.Error(codes.Unauthenticated, "unauthorized")
)

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

func (s *Server) GetPublicClientConfig(ctx context.Context, _ *platformv1.GetPublicClientConfigReq) (*platformv1.GetPublicClientConfigResp, error) {
	if !s.hasDeps() {
		return nil, errPlatformUnavailable
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

func (s *Server) ListAnnouncements(ctx context.Context, in *platformv1.ListAnnouncementsReq) (*platformv1.ListAnnouncementsResp, error) {
	if !s.hasDeps() {
		return nil, errPlatformUnavailable
	}
	if s.deps.AdminApp == nil {
		return nil, kerrors.ServiceUnavailable("ADMIN_UNAVAILABLE", "admin service unavailable")
	}
	return s.deps.AdminApp.ListPublishedAnnouncements(ctx, in)
}

func (s *Server) GetAnnouncement(ctx context.Context, in *platformv1.GetAnnouncementReq) (*platformv1.GetAnnouncementResp, error) {
	if !s.hasDeps() {
		return nil, errPlatformUnavailable
	}
	if s.deps.AdminApp == nil {
		return nil, kerrors.ServiceUnavailable("ADMIN_UNAVAILABLE", "admin service unavailable")
	}
	return s.deps.AdminApp.GetPublishedAnnouncement(ctx, in)
}

func (s *Server) ListUserContent(ctx context.Context, in *platformv1.ListUserContentReq) (*platformv1.ListUserContentResp, error) {
	if !s.hasDeps() {
		return nil, errPlatformUnavailable
	}
	if s.contentApp == nil {
		return nil, kerrors.BadRequest("CONTENT_UNAVAILABLE", "content app unavailable")
	}
	page := int(in.GetPage())
	if page <= 0 {
		page = 1
	}
	pageSize := int(in.GetPageSize())
	if pageSize <= 0 {
		pageSize = 10
	}
	result := s.contentApp.ListContent(ctx, contentbiz.ListInput{
		UserID: in.GetUserId(), Type: in.GetType(), Page: page, PageSize: pageSize,
	})
	items := make([]*platformv1.ContentItem, 0, len(result.Items))
	for _, item := range result.Items {
		items = append(items, &platformv1.ContentItem{
			Id: item.ID, UserId: item.UserID, Type: item.Type, Prompt: item.Prompt,
			Url: item.URL, Content: item.Content, CreatedAt: item.CreatedAt,
		})
	}
	return &platformv1.ListUserContentResp{
		Code: 200, Message: "获取内容列表成功", Success: true,
		Data: items, Total: int32(result.Total),
	}, nil
}

type platformMoeToolExecutor struct {
	admin *moeadmin.AdminService
}

func newPlatformMoeToolExecutor(admin *moeadmin.AdminService) moeadmin.ToolExecutor {
	return &platformMoeToolExecutor{admin: admin}
}

func (e *platformMoeToolExecutor) ExecuteTool(ctx context.Context, in moebiz.ExecuteToolInput) (moebiz.ExecuteToolResult, error) {
	if e == nil || e.admin == nil {
		return moebiz.ExecuteToolResult{}, errors.New("moe backend unavailable")
	}
	return e.admin.ExecuteTool(ctx, in)
}

type voiceUserResolver struct {
	app *userapp.AppService
}

func newVoiceUserResolver(app *userapp.AppService) voicebiz.UserDisplayResolver {
	return &voiceUserResolver{app: app}
}

func (r *voiceUserResolver) ResolveVoiceUserDisplay(ctx context.Context, userID string) (displayName, avatar string) {
	displayName = "用户"
	avatar = ""
	if r == nil || r.app == nil {
		return displayName, avatar
	}
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return displayName, avatar
	}
	resp, err := r.app.GetUser(ctx, &userv1.GetUserReq{UserId: userID})
	if err != nil || resp == nil || resp.GetUser() == nil {
		return displayName, avatar
	}
	u := resp.GetUser()
	if n := strings.TrimSpace(u.GetUsername()); n != "" {
		displayName = n
	}
	avatar = strings.TrimSpace(u.GetAvatar())
	return displayName, avatar
}

func actorUserIDString(ctx context.Context) (string, error) {
	if s, err := common.UserIDString(ctx); err == nil {
		return s, nil
	}
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return "", errUnauthorized
	}
	return bearerUserIDString(req)
}

func moeBearerUserID(ctx context.Context) (uint, error) {
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return 0, errUnauthorized
	}
	authHeader := req.Header.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return 0, errUnauthorized
	}
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	return utils.GetUserIDFromToken(tokenString)
}

func bearerUserIDString(r *http.Request) (string, error) {
	uid, err := bearerUserID(r)
	if err != nil {
		return "", err
	}
	return strconv.FormatUint(uint64(uid), 10), nil
}

func bearerUserID(r *http.Request) (uint, error) {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(auth, "Bearer ") {
		auth = strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
	}
	if auth == "" {
		return 0, errUnauthorized
	}
	cl, err := utils.ParseToken(auth)
	if err != nil {
		return 0, err
	}
	return cl.UserID, nil
}

func httpFromContext(ctx context.Context) (http.ResponseWriter, *http.Request, bool) {
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return nil, nil, false
	}
	tr, ok := transport.FromServerContext(ctx)
	if !ok {
		return nil, req, false
	}
	rv := reflect.ValueOf(tr)
	if rv.Kind() == reflect.Pointer {
		rv = rv.Elem()
	}
	f := rv.FieldByName("response")
	if !f.IsValid() || f.IsNil() {
		return nil, req, false
	}
	w, _ := f.Interface().(http.ResponseWriter)
	return w, req, w != nil
}
