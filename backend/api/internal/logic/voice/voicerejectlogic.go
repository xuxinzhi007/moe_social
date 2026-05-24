package voice

import (
	"context"
	"encoding/json"
	"errors"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type VoiceRejectLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewVoiceRejectLogic(ctx context.Context, svcCtx *svc.ServiceContext) *VoiceRejectLogic {
	return &VoiceRejectLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *VoiceRejectLogic) VoiceReject(req *types.VoiceRejectReq) (resp *types.BaseResp, err error) {
	userID, err := l.getUserID()
	if err != nil {
		return nil, err
	}
	session, ok := getCall(req.CallId)
	if !ok {
		return &types.BaseResp{Code: 0, Message: "success", Success: true}, nil
	}
	if session.ReceiverID != userID {
		return nil, errors.New("not allowed to reject this call")
	}

	pushToUser(session.CallerID, map[string]interface{}{
		"type":    "call_rejected",
		"call_id": session.CallID,
	})
	removeCall(session.CallID)

	return &types.BaseResp{Code: 0, Message: "success", Success: true}, nil
}

func (l *VoiceRejectLogic) getUserID() (string, error) {
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
