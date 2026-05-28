package voicebiz

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	chatbiz "backend/internal/biz/chat"

	"github.com/google/uuid"
)

// UserDisplayResolver 解析通话展示名与头像。
type UserDisplayResolver interface {
	ResolveVoiceUserDisplay(ctx context.Context, userID string) (displayName, avatar string)
}

// CallResult 发起呼叫结果。
type CallResult struct {
	CallID      string
	ChannelName string
}

// AnswerResult 接听呼叫结果。
type AnswerResult struct {
	ChannelName string
}

// VoiceCall 发起语音呼叫并向被叫推送 incoming_call。
func VoiceCall(ctx context.Context, resolver UserDisplayResolver, callerID, receiverID string) (CallResult, error) {
	callerID = strings.TrimSpace(callerID)
	receiverID = strings.TrimSpace(receiverID)
	if receiverID == "" {
		return CallResult{}, errors.New("receiver_id required")
	}
	if receiverID == callerID {
		return CallResult{}, errors.New("cannot call yourself")
	}

	callID := uuid.New().String()
	channelName := fmt.Sprintf("call_%s", callID)

	callerName, callerAvatar := "用户", ""
	if resolver != nil {
		callerName, callerAvatar = resolver.ResolveVoiceUserDisplay(ctx, callerID)
	}

	session := &CallSession{
		CallID:       callID,
		ChannelName:  channelName,
		CallerID:     callerID,
		ReceiverID:   receiverID,
		CallerName:   callerName,
		CallerAvatar: callerAvatar,
		CreatedAt:    time.Now(),
	}
	putCall(session)

	chatbiz.PushJSONToChatUser(receiverID, map[string]interface{}{
		"type":          "incoming_call",
		"call_id":       callID,
		"channel_name":  channelName,
		"caller_id":     callerID,
		"caller_name":   callerName,
		"caller_avatar": callerAvatar,
	})

	return CallResult{CallID: callID, ChannelName: channelName}, nil
}

// VoiceAnswer 被叫接听并向主叫推送 call_answered。
func VoiceAnswer(_ context.Context, receiverID, callID string) (AnswerResult, error) {
	session, ok := getCall(callID)
	if !ok {
		return AnswerResult{}, errors.New("call not found or expired")
	}
	if session.ReceiverID != receiverID {
		return AnswerResult{}, errors.New("not allowed to answer this call")
	}

	pushToUser(session.CallerID, map[string]interface{}{
		"type":         "call_answered",
		"call_id":      session.CallID,
		"channel_name": session.ChannelName,
	})

	return AnswerResult{ChannelName: session.ChannelName}, nil
}

// VoiceCancel 主叫取消呼叫。
func VoiceCancel(_ context.Context, callerID, callID string) error {
	if callID == "" {
		return nil
	}
	session, ok := getCall(callID)
	if !ok {
		return nil
	}
	if session.CallerID != callerID {
		return errors.New("not allowed to cancel this call")
	}
	pushToUser(session.ReceiverID, map[string]interface{}{
		"type":    "call_cancelled",
		"call_id": session.CallID,
	})
	removeCall(session.CallID)
	return nil
}

// VoiceReject 被叫拒接呼叫。
func VoiceReject(_ context.Context, receiverID, callID string) error {
	session, ok := getCall(callID)
	if !ok {
		return nil
	}
	if session.ReceiverID != receiverID {
		return errors.New("not allowed to reject this call")
	}
	pushToUser(session.CallerID, map[string]interface{}{
		"type":    "call_rejected",
		"call_id": session.CallID,
	})
	removeCall(session.CallID)
	return nil
}

func pushToUser(userID string, payload map[string]interface{}) {
	chatbiz.PushJSONToChatUser(userID, payload)
}
