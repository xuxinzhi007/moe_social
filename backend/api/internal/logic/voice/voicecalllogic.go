package voice

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"backend/api/internal/svc"
	"backend/api/internal/types"

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
	// 从上下文获取用户ID
	_, err = l.getUserID()
	if err != nil {
		return nil, err
	}

	// 生成唯一的呼叫ID和频道名称
	callID := uuid.New().String()
	channelName := fmt.Sprintf("call_%s", callID)

	// 创建呼叫记录
	// 这里需要实现数据库操作，暂时返回成功
	
	// 发送推送通知给接收方
	// 这里需要实现推送通知逻辑

	return &types.VoiceCallResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data: struct {
			CallId      string `json:"call_id"`
			ChannelName string `json:"channel_name"`
		}{
			CallId:      callID,
			ChannelName: channelName,
		},
	}, nil
}

func (l *VoiceCallLogic) getUserID() (string, error) {
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