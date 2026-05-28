package voice

import (
	"context"
	"strings"

	"backend/api/internal/svc"
	"backend/rpc/pb/super"
)

// ResolveVoiceUserDisplay 从 UserGW 解析通话展示名与头像（F112 Voice 收口）。
func ResolveVoiceUserDisplay(ctx context.Context, svcCtx *svc.ServiceContext, userID string) (displayName, avatar string) {
	displayName = "用户"
	avatar = ""
	if svcCtx == nil || svcCtx.UserGW == nil {
		return displayName, avatar
	}
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return displayName, avatar
	}
	resp, err := svcCtx.UserGW.GetUser(ctx, &super.GetUserReq{UserId: userID})
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
