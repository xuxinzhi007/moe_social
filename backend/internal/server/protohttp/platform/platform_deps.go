package platformhttp

import (
	"context"
	"errors"
	"strings"

	userv1 "backend/api/user/v1"
	moebiz "backend/internal/biz/moe"
	voicebiz "backend/internal/biz/voice"
	moeadmin "backend/internal/service/moe"
	userapp "backend/internal/service/user"
)

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
