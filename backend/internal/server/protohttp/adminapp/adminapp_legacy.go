package adminapphttp

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	adminv1 "backend/api/admin/v1"
	aiv1 "backend/api/ai/v1"
	"backend/internal/apilegacy/common"
	adminbiz "backend/internal/biz/admin"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (s *Server) AdminUpdateAiAgent(ctx context.Context, in *adminv1.AdminUpdateAiAgentReq) (*adminv1.AdminUpdateAiAgentResp, error) {
	actx, err := requireAdminContext(ctx)
	if err != nil {
		return nil, err
	}
	uid := strings.TrimSpace(in.GetUserId())
	aid := strings.TrimSpace(in.GetAgentId())
	payload := strings.TrimSpace(in.GetPayloadJson())
	if uid == "" || aid == "" || payload == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id, agent_id and payload_json are required")
	}
	if !json.Valid([]byte(payload)) {
		return nil, status.Error(codes.InvalidArgument, "payload_json must be valid JSON")
	}
	if s.ai == nil {
		return nil, status.Error(codes.FailedPrecondition, "AI app unavailable")
	}
	_, err = s.ai.UpsertAiAgent(actx, &aiv1.UpsertAiResourceReq{
		UserId:      uid,
		Id:          aid,
		PayloadJson: payload,
	})
	if err != nil {
		return nil, err
	}
	if s.recordAudit != nil {
		s.recordAudit(actx, "update", "ai_agent", aid, "update ai agent")
	}
	return &adminv1.AdminUpdateAiAgentResp{}, nil
}

func (s *Server) AdminMe(ctx context.Context, _ *adminv1.AdminMeReq) (*adminv1.AdminMeResp, error) {
	req, ok := requestFromContext(ctx)
	if !ok {
		return nil, errAdminUnauthorized
	}
	claims, br := common.RequireAdminToken(req)
	if br != nil {
		return nil, status.Error(codes.Unauthenticated, br.Message)
	}
	return &adminv1.AdminMeResp{
		AdminId:  uint64(claims.AdminID),
		Username: claims.Username,
		Role:     claims.Role,
	}, nil
}

func (s *Server) AdminListMediaImages(ctx context.Context, in *adminv1.AdminListMediaImagesReq) (*adminv1.AdminListMediaImagesResp, error) {
	if _, err := requireAdminContext(ctx); err != nil {
		return nil, err
	}
	if s.runtime == nil {
		return nil, status.Error(codes.FailedPrecondition, "runtime state unavailable")
	}
	req, ok := requestFromContext(ctx)
	if !ok {
		return nil, errAdminUnauthorized
	}
	publicBase := utils.ResolveMediaPublicBase(
		req,
		s.runtime.ImagePublicBaseURL,
		s.runtime.ClientPublicAPIBaseURL,
	)
	rows, owners, total, err := utils.ListAdminMediaImages(
		s.runtime.ImageLocalDir,
		publicBase,
		int(in.GetPage()),
		int(in.GetPageSize()),
		in.GetKeyword(),
		in.GetOwnerFolder(),
		in.GetMediaKind(),
	)
	if err != nil {
		return nil, err
	}
	out := &adminv1.AdminListMediaImagesResp{Total: int32(total)}
	for _, row := range rows {
		out.Items = append(out.Items, &adminv1.AdminMediaImageItem{
			Filename:      row.Filename,
			ImageBasename: row.FileName,
			OwnerFolder:   row.OwnerFolder,
			MediaKind:     row.MediaKind,
			Url:           row.URL,
			Size:          row.Size,
			CreatedAt:     row.CreatedAt,
			OwnerHint:     row.OwnerHint,
		})
	}
	for _, o := range owners {
		out.Owners = append(out.Owners, &adminv1.AdminMediaOwnerSummary{
			OwnerFolder:  o.OwnerFolder,
			UserId:       o.UserID,
			UsernameHint: o.UsernameHint,
			FileCount:    int32(o.FileCount),
			TotalBytes:   o.TotalBytes,
		})
	}
	return out, nil
}

func (s *Server) AdminDeleteMediaImage(ctx context.Context, in *adminv1.AdminDeleteMediaImageReq) (*adminv1.AdminDeleteMediaImageResp, error) {
	actx, err := requireAdminContext(ctx)
	if err != nil {
		return nil, err
	}
	if s.runtime == nil {
		return nil, status.Error(codes.FailedPrecondition, "runtime state unavailable")
	}
	filename := strings.TrimSpace(in.GetFilename())
	if filename == "" {
		return nil, status.Error(codes.InvalidArgument, "filename is required")
	}
	if err := utils.DeleteAdminMediaImage(s.runtime.ImageLocalDir, filename); err != nil {
		return nil, err
	}
	s.recordAudit(actx, "delete", "media_image", filename, "delete media image")
	return &adminv1.AdminDeleteMediaImageResp{}, nil
}

func (s *Server) AdminListMenus(ctx context.Context, in *adminv1.AdminListMenusReq) (*adminv1.AdminListMenusResp, error) {
	if _, err := requireAdminContext(ctx); err != nil {
		return nil, err
	}
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.ListMenus(ctx, in)
}

func (s *Server) AdminUpsertMenu(ctx context.Context, in *adminv1.AdminUpsertMenuReq) (*adminv1.AdminUpsertMenuResp, error) {
	actx, err := requireAdminContext(ctx)
	if err != nil {
		return nil, err
	}
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.UpsertMenu(actx, in)
	if err != nil {
		return nil, err
	}
	if s.recordAudit != nil {
		s.recordAudit(actx, "upsert", "admin_menu", in.GetKey(), "upsert admin menu")
	}
	return resp, nil
}

func (s *Server) AdminDeleteMenu(ctx context.Context, in *adminv1.AdminDeleteMenuReq) (*adminv1.AdminDeleteMenuResp, error) {
	actx, err := requireAdminContext(ctx)
	if err != nil {
		return nil, err
	}
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.DeleteMenu(actx, in)
	if err != nil {
		return nil, err
	}
	if s.recordAudit != nil {
		s.recordAudit(actx, "delete", "admin_menu", in.GetMenuKey(), "delete admin menu")
	}
	return resp, nil
}

func (s *Server) AdminBootstrapMenus(ctx context.Context, in *adminv1.AdminBootstrapMenusReq) (*adminv1.AdminBootstrapMenusResp, error) {
	actx, err := requireAdminContext(ctx)
	if err != nil {
		return nil, err
	}
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	resp, err := app.BootstrapMenus(actx, in)
	if err != nil {
		return nil, err
	}
	if s.recordAudit != nil {
		s.recordAudit(actx, "bootstrap", "admin_menu", "", "bootstrap admin menu")
	}
	return resp, nil
}

func (s *Server) AdminGetRuntimeConfig(ctx context.Context, _ *adminv1.AdminGetRuntimeConfigReq) (*adminv1.AdminGetRuntimeConfigResp, error) {
	if _, err := requireAdminContext(ctx); err != nil {
		return nil, err
	}
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	view, err := app.ReadRuntimeConfig()
	if err != nil {
		return nil, err
	}
	return runtimeConfigToProto(view, s.runtime), nil
}

func (s *Server) AdminUpdateRuntimeConfig(ctx context.Context, in *adminv1.AdminUpdateRuntimeConfigReq) (*adminv1.AdminUpdateRuntimeConfigResp, error) {
	actx, err := requireAdminContext(ctx)
	if err != nil {
		return nil, err
	}
	if s.runtime == nil {
		return nil, status.Error(codes.FailedPrecondition, "runtime state unavailable")
	}
	patch := utils.RuntimeConfigPatch{}
	if in.GetUpdatePublicApiBaseUrl() {
		v := in.GetPublicApiBaseUrl()
		patch.PublicApiBaseUrl = &v
	}
	if in.GetUpdateApiPublicBaseUrl() {
		v := in.GetApiPublicBaseUrl()
		patch.ApiPublicBaseUrl = &v
	}
	if in.GetUpdateImagePublicBaseUrl() {
		v := in.GetImagePublicBaseUrl()
		patch.ImagePublicBaseUrl = &v
	}
	if in.GetUpdateImageLocalDir() {
		v := in.GetImageLocalDir()
		patch.ImageLocalDir = &v
	}
	if in.GetUpdateImageMaxBytes() {
		v := in.GetImageMaxBytes()
		patch.ImageMaxBytes = &v
	}
	view, err := utils.ApplyRuntimeConfigPatch(patch)
	if err != nil {
		return nil, err
	}
	if patch.PublicApiBaseUrl != nil {
		s.runtime.ClientPublicAPIBaseURL = view.PublicApiBaseUrl
	}
	if patch.ImagePublicBaseUrl != nil {
		s.runtime.ImagePublicBaseURL = view.ImagePublicBaseUrl
	}
	if patch.ImageLocalDir != nil {
		s.runtime.ImageLocalDir = view.ImageLocalDir
	}
	if patch.ImageMaxBytes != nil {
		s.runtime.ImageMaxBytes = view.ImageMaxBytes
	}
	s.recordAudit(actx, "update", "runtime_config", "", "update runtime config")
	cfg := runtimeConfigToProto(view, s.runtime)
	return &adminv1.AdminUpdateRuntimeConfigResp{
		PublicApiBaseUrl:   cfg.PublicApiBaseUrl,
		ApiPublicBaseUrl:   cfg.ApiPublicBaseUrl,
		ImagePublicBaseUrl: cfg.ImagePublicBaseUrl,
		ImageLocalDir:      cfg.ImageLocalDir,
		ImageMaxBytes:      cfg.ImageMaxBytes,
		ConfigFile:         cfg.ConfigFile,
		RequiresRestart:    cfg.RequiresRestart,
	}, nil
}

func (s *Server) AdminRuntimeOverview(ctx context.Context, _ *adminv1.AdminGetRuntimeOverviewReq) (*adminv1.AdminGetRuntimeOverviewResp, error) {
	if _, err := requireAdminContext(ctx); err != nil {
		return nil, err
	}
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	data, err := app.RuntimeOverview(ctx)
	if err != nil {
		return nil, err
	}
	return runtimeOverviewToProto(data), nil
}

func runtimeConfigToProto(view utils.RuntimeConfigView, runtime *RuntimeState) *adminv1.AdminGetRuntimeConfigResp {
	out := &adminv1.AdminGetRuntimeConfigResp{
		PublicApiBaseUrl:   view.PublicApiBaseUrl,
		ApiPublicBaseUrl:   view.ApiPublicBaseUrl,
		ImagePublicBaseUrl: view.ImagePublicBaseUrl,
		ImageLocalDir:      view.ImageLocalDir,
		ImageMaxBytes:      view.ImageMaxBytes,
		ConfigFile:         view.ConfigFile,
	}
	if runtime != nil {
		if out.PublicApiBaseUrl == "" {
			out.PublicApiBaseUrl = runtime.ClientPublicAPIBaseURL
		}
		if out.ImagePublicBaseUrl == "" {
			out.ImagePublicBaseUrl = runtime.ImagePublicBaseURL
		}
		if out.ImageLocalDir == "" {
			out.ImageLocalDir = runtime.ImageLocalDir
		}
		if out.ImageMaxBytes == 0 {
			out.ImageMaxBytes = runtime.ImageMaxBytes
		}
	}
	return out
}

func runtimeOverviewToProto(data *adminbiz.RuntimeOverviewResult) *adminv1.AdminGetRuntimeOverviewResp {
	if data == nil {
		return &adminv1.AdminGetRuntimeOverviewResp{}
	}
	return &adminv1.AdminGetRuntimeOverviewResp{
		ApiProcess:       runtimeProcessToProto(data.ApiProcess),
		RpcProcess:       runtimeProcessToProto(data.RpcProcess),
		RpcMonitorOnline: data.RpcMonitorOnline,
		Layout:           data.Layout,
		ProcessesNote:    data.ProcessesNote,
		EstimatedRssMb:   data.EstimatedRssMb,
	}
}

func runtimeProcessToProto(p adminbiz.RuntimeProcessInfo) *adminv1.AdminRuntimeProcessInfo {
	return &adminv1.AdminRuntimeProcessInfo{
		Role:        p.Role,
		Pid:         int32(p.Pid),
		GoAllocMb:   p.GoAllocMb,
		GoSysMb:     p.GoSysMb,
		RssMb:       p.RssMb,
		Goroutines:  int32(p.Goroutines),
		NumCpu:      int32(p.NumCpu),
		Reachable:   p.Reachable,
		SameProcess: p.SameProcess,
	}
}

func requestFromContext(ctx context.Context) (*http.Request, bool) {
	req, ok := khttp.RequestFromServerContext(ctx)
	return req, ok && req != nil
}
