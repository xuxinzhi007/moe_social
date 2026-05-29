package platformgrpc

import (
	"context"
	"strings"

	platformv1 "backend/api/platform/v1"
	voicebiz "backend/internal/biz/voice"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

func (s *Server) VoiceCall(ctx context.Context, in *platformv1.VoiceCallReq) (*platformv1.VoiceCallResp, error) {
	if _, err := s.requireSvc(); err != nil {
		return nil, err
	}
	if s.voiceApp == nil {
		return nil, kerrors.BadRequest("VOICE_UNAVAILABLE", "voice app unavailable")
	}
	callerID, err := actorUserIDString(ctx)
	if err != nil {
		return nil, kerrors.BadRequest("UNAUTHORIZED", err.Error())
	}
	result, err := s.voiceApp.VoiceCall(ctx, callerID, in.GetReceiverId())
	if err != nil {
		return nil, kerrors.BadRequest("VOICE_CALL_FAILED", err.Error())
	}
	return &platformv1.VoiceCallResp{
		Code: 0, Message: "success", Success: true,
		Data: &platformv1.VoiceCallData{CallId: result.CallID, ChannelName: result.ChannelName},
	}, nil
}

func (s *Server) VoiceAnswer(ctx context.Context, in *platformv1.VoiceAnswerReq) (*platformv1.VoiceAnswerResp, error) {
	if _, err := s.requireSvc(); err != nil {
		return nil, err
	}
	if s.voiceApp == nil {
		return nil, kerrors.BadRequest("VOICE_UNAVAILABLE", "voice app unavailable")
	}
	userID, err := actorUserIDString(ctx)
	if err != nil {
		return nil, kerrors.BadRequest("UNAUTHORIZED", err.Error())
	}
	result, err := s.voiceApp.VoiceAnswer(ctx, userID, in.GetCallId())
	if err != nil {
		return nil, kerrors.BadRequest("VOICE_ANSWER_FAILED", err.Error())
	}
	return &platformv1.VoiceAnswerResp{
		Code: 0, Message: "success", Success: true,
		Data: &platformv1.VoiceAnswerData{ChannelName: result.ChannelName},
	}, nil
}

func (s *Server) VoiceCancel(ctx context.Context, in *platformv1.VoiceCancelReq) (*platformv1.VoiceSimpleResp, error) {
	if _, err := s.requireSvc(); err != nil {
		return nil, err
	}
	if s.voiceApp == nil {
		return nil, kerrors.BadRequest("VOICE_UNAVAILABLE", "voice app unavailable")
	}
	callerID, err := actorUserIDString(ctx)
	if err != nil {
		return nil, kerrors.BadRequest("UNAUTHORIZED", err.Error())
	}
	if err := s.voiceApp.VoiceCancel(ctx, callerID, in.GetCallId()); err != nil {
		return nil, kerrors.BadRequest("VOICE_CANCEL_FAILED", err.Error())
	}
	return &platformv1.VoiceSimpleResp{Code: 0, Message: "success", Success: true}, nil
}

func (s *Server) VoiceReject(ctx context.Context, in *platformv1.VoiceRejectReq) (*platformv1.VoiceSimpleResp, error) {
	if _, err := s.requireSvc(); err != nil {
		return nil, err
	}
	if s.voiceApp == nil {
		return nil, kerrors.BadRequest("VOICE_UNAVAILABLE", "voice app unavailable")
	}
	userID, err := actorUserIDString(ctx)
	if err != nil {
		return nil, kerrors.BadRequest("UNAUTHORIZED", err.Error())
	}
	if err := s.voiceApp.VoiceReject(ctx, userID, in.GetCallId()); err != nil {
		return nil, kerrors.BadRequest("VOICE_REJECT_FAILED", err.Error())
	}
	return &platformv1.VoiceSimpleResp{Code: 0, Message: "success", Success: true}, nil
}

func (s *Server) GetVoiceToken(ctx context.Context, in *platformv1.GetVoiceTokenReq) (*platformv1.GetVoiceTokenResp, error) {
	if _, err := s.requireSvc(); err != nil {
		return nil, err
	}
	if s.voiceApp == nil {
		return nil, kerrors.BadRequest("VOICE_UNAVAILABLE", "voice app unavailable")
	}
	userAccount := strings.TrimSpace(in.GetUserAccount())
	if userAccount == "" {
		var err error
		userAccount, err = actorUserIDString(ctx)
		if err != nil {
			return nil, kerrors.BadRequest("UNAUTHORIZED", err.Error())
		}
	}
	role := uint8(in.GetRole())
	if role == 0 {
		role = 1
	}
	result, err := s.voiceApp.GetRtcToken(ctx, voicebiz.TokenInput{
		ChannelName: in.GetChannelName(),
		UserAccount: userAccount,
		Role:        role,
	})
	if err != nil {
		return nil, kerrors.BadRequest("VOICE_TOKEN_FAILED", err.Error())
	}
	return &platformv1.GetVoiceTokenResp{
		Code: 0, Message: "success", Success: true,
		Token: result.Token, AppId: result.AppID,
	}, nil
}
