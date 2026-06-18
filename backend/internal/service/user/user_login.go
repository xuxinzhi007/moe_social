// Package userapp 认证相关方法（登录、注册、OAuth）。
package userapp

import (
	"context"
	userbiz "backend/internal/biz/user"
	userv1 "backend/api/user/v1"
)

// Package userapp 认证相关方法（登录、注册、OAuth）。

// Login 登录。
func (s *AppService) Login(ctx context.Context, in *userv1.LoginReq) (*userv1.LoginResp, error) {
	user, token, err := userbiz.Login(ctx, s.store, in.GetEmail(), in.GetUsername(), in.GetPassword())
	if err != nil {
		return nil, err
	}
	return userbiz.LoginRespV1(user, token), nil
}

// Register 注册。
func (s *AppService) Register(ctx context.Context, in *userv1.RegisterReq) (*userv1.RegisterResp, error) {
	user, token, err := userbiz.Register(ctx, s.store, in.GetUsername(), in.GetEmail(), in.GetPassword())
	if err != nil {
		return nil, err
	}
	return userbiz.RegisterRespV1(user, token), nil
}

// FeishuLogin 飞书 OAuth 登录。
func (s *AppService) FeishuLogin(ctx context.Context, in *userv1.FeishuLoginReq) (*userv1.FeishuLoginResp, error) {
	return userbiz.FeishuLogin(ctx, s.store, in)
}

// FeishuAuthorizeURL 飞书授权地址。
func (s *AppService) FeishuAuthorizeURL(ctx context.Context, in *userv1.FeishuAuthorizeURLReq) (*userv1.FeishuAuthorizeURLResp, error) {
	return userbiz.FeishuAuthorizeURL(ctx, in)
}

// BindFeishu 绑定飞书。
func (s *AppService) BindFeishu(ctx context.Context, in *userv1.BindFeishuReq) (*userv1.BindFeishuResp, error) {
	return userbiz.BindFeishu(ctx, s.store, in)
}

// UnbindFeishu 解绑飞书。
func (s *AppService) UnbindFeishu(ctx context.Context, in *userv1.UnbindFeishuReq) (*userv1.UnbindFeishuResp, error) {
	return userbiz.UnbindFeishu(ctx, s.store, in)
}

// SendFeishuTestCard 发送飞书测试卡片。
func (s *AppService) SendFeishuTestCard(ctx context.Context, in *userv1.SendFeishuTestCardReq) (*userv1.SendFeishuTestCardResp, error) {
	return userbiz.SendFeishuTestCard(ctx, s.store, in)
}

// WechatLogin 微信 OAuth 登录。
func (s *AppService) WechatLogin(ctx context.Context, in *userv1.WechatLoginReq) (*userv1.WechatLoginResp, error) {
	return userbiz.WechatLogin(ctx, s.store, in)
}

// WechatAuthorizeURL 微信授权地址。
func (s *AppService) WechatAuthorizeURL(ctx context.Context, in *userv1.WechatAuthorizeURLReq) (*userv1.WechatAuthorizeURLResp, error) {
	return userbiz.WechatAuthorizeURL(ctx, in)
}