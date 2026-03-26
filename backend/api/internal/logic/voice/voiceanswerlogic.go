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
	// 从上下文获取用户ID
	_, err = l.getUserID()
	if err != nil {
		return nil, err
	}

	// 验证呼叫是否存在
	// 这里需要实现数据库操作

	// 更新呼叫状态为已接听
	// 这里需要实现数据库操作

	// 发送通知给呼叫方
	// 这里需要实现推送通知逻辑

	// 生成频道名称（从数据库获取或根据callId生成）
	channelName := "call_" + req.CallId

	return &types.VoiceAnswerResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data: struct {
			ChannelName string `json:"channel_name"`
		}{
			ChannelName: channelName,
		},
	}, nil
}

func (l *VoiceAnswerLogic) getUserID() (string, error) {
	// 尝试从Context获取userId
	uidVal := l.ctx.Value("userId")
	if uidVal == nil {
		// 尝试 "user_id"
		uidVal = l.ctx.Value("user_id")
	}

	if uidVal == nil {
		return "", errors.New("User not logged in or userId not found in context")
	}

	// 处理 json.Number 或 string
	switch v := uidVal.(type) {
	case string:
		return v, nil
	case json.Number:
		return v.String(), nil
	default:
		// 尝试强转 string
		if s, ok := uidVal.(string); ok {
			return s, nil
		} else {
			return "", errors.New("Invalid userId type in context")
		}
	}
}