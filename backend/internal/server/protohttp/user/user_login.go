package userhttp

import (
	"context"

	userbiz "backend/internal/biz/user"
	userv1 "backend/api/user/v1"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/protobuf/types/known/emptypb"
)

func (s *Server) Login(ctx context.Context, in *userv1.LoginReq) (*userv1.LoginResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Login(ctx, in)
}

func (s *Server) Register(ctx context.Context, in *userv1.RegisterReq) (*userv1.RegisterResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.Register(ctx, in)
}

func (s *Server) RefreshToken(ctx context.Context, _ *userv1.RefreshTokenReq) (*userv1.RefreshTokenResp, error) {
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return nil, errUnauthorized
	}
	tok, err := userbiz.RefreshAccessToken(req.Header.Get("Authorization"))
	if err != nil {
		return nil, err
	}
	return &userv1.RefreshTokenResp{Token: tok}, nil
}

func (s *Server) FeishuAuthorizeURL(ctx context.Context, in *userv1.FeishuAuthorizeURLReq) (*userv1.FeishuAuthorizeURLResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.FeishuAuthorizeURL(ctx, in)
}

func (s *Server) FeishuLogin(ctx context.Context, in *userv1.FeishuLoginReq) (*userv1.FeishuLoginResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.FeishuLogin(ctx, in)
}

func (s *Server) FeishuPublicConfig(ctx context.Context, _ *emptypb.Empty) (*userv1.FeishuPublicConfigResp, error) {
	cfg := utils.GetFeishuPublicConfig()
	return &userv1.FeishuPublicConfigResp{
		InviteUrl: cfg.EnterpriseInviteURL,
		HelpText:  cfg.Notice,
		Enabled:   cfg.Enabled,
	}, nil
}

func (s *Server) WechatAuthorizeURL(ctx context.Context, in *userv1.WechatAuthorizeURLReq) (*userv1.WechatAuthorizeURLResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.WechatAuthorizeURL(ctx, in)
}

func (s *Server) WechatLogin(ctx context.Context, in *userv1.WechatLoginReq) (*userv1.WechatLoginResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.WechatLogin(ctx, in)
}

func (s *Server) BindFeishu(ctx context.Context, in *userv1.BindFeishuReq) (*userv1.BindFeishuResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if in.GetUserId() == "" {
		userID, err := actorUserID(ctx)
		if err != nil {
			return nil, err
		}
		in.UserId = userID
	}
	return app.BindFeishu(ctx, in)
}

func (s *Server) UnbindFeishu(ctx context.Context, in *userv1.UnbindFeishuReq) (*userv1.UnbindFeishuResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if in.GetUserId() == "" {
		userID, err := actorUserID(ctx)
		if err != nil {
			return nil, err
		}
		in.UserId = userID
	}
	return app.UnbindFeishu(ctx, in)
}

func (s *Server) SendFeishuTestCard(ctx context.Context, in *userv1.SendFeishuTestCardReq) (*userv1.SendFeishuTestCardResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	if in.GetUserId() == "" {
		userID, err := actorUserID(ctx)
		if err != nil {
			return nil, err
		}
		in.UserId = userID
	}
	return app.SendFeishuTestCard(ctx, in)
}
