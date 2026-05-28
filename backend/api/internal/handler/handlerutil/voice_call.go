package handlerutil

import (
	"context"
	"strings"
	"sync"
	"time"

	"backend/api/internal/svc"
	"backend/rpc/pb/moe"
)

type voiceCallSession struct {
	CallID       string
	ChannelName  string
	CallerID     string
	ReceiverID   string
	CallerName   string
	CallerAvatar string
	CreatedAt    time.Time
}

var (
	voiceCallMu   sync.RWMutex
	voiceCallByID = make(map[string]*voiceCallSession)
)

// PutVoiceCall 注册内存呼叫会话。
func PutVoiceCall(s *voiceCallSession) {
	voiceCallMu.Lock()
	voiceCallByID[s.CallID] = s
	voiceCallMu.Unlock()
}

// GetVoiceCall 按 callID 查询会话。
func GetVoiceCall(callID string) (*voiceCallSession, bool) {
	voiceCallMu.RLock()
	s, ok := voiceCallByID[callID]
	voiceCallMu.RUnlock()
	return s, ok
}

// RemoveVoiceCall 移除呼叫会话。
func RemoveVoiceCall(callID string) {
	voiceCallMu.Lock()
	delete(voiceCallByID, callID)
	voiceCallMu.Unlock()
}

// NewVoiceCallSession 构造呼叫会话（供 voice handler 使用）。
func NewVoiceCallSession(callID, channelName, callerID, receiverID, callerName, callerAvatar string) *voiceCallSession {
	return &voiceCallSession{
		CallID: callID, ChannelName: channelName, CallerID: callerID, ReceiverID: receiverID,
		CallerName: callerName, CallerAvatar: callerAvatar, CreatedAt: time.Now(),
	}
}

// VoiceCallSession 导出字段访问（voice handler 需要 ChannelName 等）。
type VoiceCallSession = voiceCallSession

// ResolveVoiceUserDisplay 从 UserGW 解析通话展示名与头像。
func ResolveVoiceUserDisplay(ctx context.Context, svcCtx *svc.ServiceContext, userID string) (displayName, avatar string) {
	displayName = "用户"
	if svcCtx == nil || svcCtx.UserGW == nil {
		return displayName, avatar
	}
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return displayName, avatar
	}
	resp, err := svcCtx.UserGW.GetUser(ctx, &moe.GetUserReq{UserId: userID})
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
