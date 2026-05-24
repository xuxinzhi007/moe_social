package voice

import (
	"context"
	"encoding/json"
	"errors"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type VoiceCancelLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewVoiceCancelLogic(ctx context.Context, svcCtx *svc.ServiceContext) *VoiceCancelLogic {
	return &VoiceCancelLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *VoiceCancelLogic) VoiceCancel(req *types.VoiceCancelReq) (resp *types.BaseResp, err error) {
	callerID, err := l.getUserID()
	if err != nil {
		return nil, err
	}
	if req.CallId != "" {
		if session, ok := getCall(req.CallId); ok {
			if session.CallerID != callerID {
				return nil, errors.New("not allowed to cancel this call")
			}
			pushToUser(session.ReceiverID, map[string]interface{}{
				"type":    "call_cancelled",
				"call_id": session.CallID,
			})
			removeCall(session.CallID)
		}
	}

	return &types.BaseResp{Code: 0, Message: "success", Success: true}, nil
}

func (l *VoiceCancelLogic) getUserID() (string, error) {
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
