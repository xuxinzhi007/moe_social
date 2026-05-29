package platformhttp

import (
	"context"
	"errors"
	"strings"

	userv1 "backend/api/user/v1"
	moebiz "backend/internal/biz/moe"
	voicebiz "backend/internal/biz/voice"
	"backend/internal/platform/svc"
	moeadmin "backend/internal/service/moe"
	voiceapp "backend/internal/service/voice"
)

type platformMoeToolExecutor struct {
	svcCtx *svc.ServiceContext
}

func newPlatformMoeToolExecutor(svcCtx *svc.ServiceContext) moeadmin.ToolExecutor {
	return &platformMoeToolExecutor{svcCtx: svcCtx}
}

func (e *platformMoeToolExecutor) ExecuteTool(ctx context.Context, in moebiz.ExecuteToolInput) (moebiz.ExecuteToolResult, error) {
	if e == nil || e.svcCtx == nil || e.svcCtx.MoeAdmin == nil {
		return moebiz.ExecuteToolResult{}, errors.New("moe backend unavailable")
	}
	return e.svcCtx.MoeAdmin.ExecuteTool(ctx, in)
}

type voiceUserResolver struct {
	svcCtx *svc.ServiceContext
}

func newVoiceUserResolver(svcCtx *svc.ServiceContext) voicebiz.UserDisplayResolver {
	return &voiceUserResolver{svcCtx: svcCtx}
}

func (r *voiceUserResolver) ResolveVoiceUserDisplay(ctx context.Context, userID string) (displayName, avatar string) {
	displayName = "用户"
	avatar = ""
	if r == nil || r.svcCtx == nil || r.svcCtx.UserApp == nil {
		return displayName, avatar
	}
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return displayName, avatar
	}
	resp, err := r.svcCtx.UserApp.GetUser(ctx, &userv1.GetUserReq{UserId: userID})
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

func newVoiceApp(svcCtx *svc.ServiceContext) *voiceapp.AppService {
	if svcCtx == nil {
		return nil
	}
	return voiceapp.New(newVoiceUserResolver(svcCtx), voicebiz.AgoraConfig{
		AppID:          svcCtx.Config.Agora.AppId,
		AppCertificate: svcCtx.Config.Agora.AppCertificate,
	})
}
