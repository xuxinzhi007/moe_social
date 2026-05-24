package voice

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"backend/api/internal/logic/chat"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/google/uuid"
	"github.com/zeromicro/go-zero/core/logx"
)

type VoiceCallLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewVoiceCallLogic(ctx context.Context, svcCtx *svc.ServiceContext) *VoiceCallLogic {
	return &VoiceCallLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *VoiceCallLogic) VoiceCall(req *types.VoiceCallReq) (resp *types.VoiceCallResp, err error) {
	callerID, err := l.getUserID()
	if err != nil {
		return nil, err
	}
	receiverID := strings.TrimSpace(req.ReceiverId)
	if receiverID == "" {
		return nil, errors.New("receiver_id required")
	}
	if receiverID == callerID {
		return nil, errors.New("cannot call yourself")
	}

	callID := uuid.New().String()
	channelName := fmt.Sprintf("call_%s", callID)

	callerName := "用户"
	callerAvatar := ""
	if l.svcCtx.SuperRpcClient != nil {
		if u, e := l.svcCtx.SuperRpcClient.GetUser(l.ctx, &super.GetUserReq{UserId: callerID}); e == nil && u.GetUser() != nil {
			if n := strings.TrimSpace(u.GetUser().GetUsername()); n != "" {
				callerName = n
			}
			callerAvatar = strings.TrimSpace(u.GetUser().GetAvatar())
		}
	}

	session := &callSession{
		CallID:       callID,
		ChannelName:  channelName,
		CallerID:     callerID,
		ReceiverID:   receiverID,
		CallerName:   callerName,
		CallerAvatar: callerAvatar,
		CreatedAt:    time.Now(),
	}
	putCall(session)

	payload := map[string]interface{}{
		"type":          "incoming_call",
		"call_id":       callID,
		"channel_name":  channelName,
		"caller_id":     callerID,
		"caller_name":   callerName,
		"caller_avatar": callerAvatar,
	}
	if !chat.PushJSONToChatUser(receiverID, payload) {
		l.Infof("voice call: receiver %s not on chat ws, incoming_call not delivered live", receiverID)
	}

	return &types.VoiceCallResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data: types.VoiceCallData{
			CallId:      callID,
			ChannelName: channelName,
		},
	}, nil
}

func (l *VoiceCallLogic) getUserID() (string, error) {
	uidVal := l.ctx.Value("userId")
	if uidVal == nil {
		uidVal = l.ctx.Value("user_id")
	}
	if uidVal == nil {
		return "", errors.New("user not logged in")
	}
	switch v := uidVal.(type) {
	case string:
		return v, nil
	case json.Number:
		return v.String(), nil
	default:
		if s, ok := uidVal.(string); ok {
			return s, nil
		}
		return "", errors.New("invalid userId in context")
	}
}
