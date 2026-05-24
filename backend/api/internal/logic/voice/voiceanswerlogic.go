package voice

import (
	"context"
	"encoding/json"
	"errors"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type VoiceAnswerLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewVoiceAnswerLogic(ctx context.Context, svcCtx *svc.ServiceContext) *VoiceAnswerLogic {
	return &VoiceAnswerLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *VoiceAnswerLogic) VoiceAnswer(req *types.VoiceAnswerReq) (resp *types.VoiceAnswerResp, err error) {
	userID, err := l.getUserID()
	if err != nil {
		return nil, err
	}
	session, ok := getCall(req.CallId)
	if !ok {
		return nil, errors.New("call not found or expired")
	}
	if session.ReceiverID != userID {
		return nil, errors.New("not allowed to answer this call")
	}

	pushToUser(session.CallerID, map[string]interface{}{
		"type":         "call_answered",
		"call_id":      session.CallID,
		"channel_name": session.ChannelName,
	})

	return &types.VoiceAnswerResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data: types.VoiceAnswerData{
			ChannelName: session.ChannelName,
		},
	}, nil
}

func (l *VoiceAnswerLogic) getUserID() (string, error) {
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
