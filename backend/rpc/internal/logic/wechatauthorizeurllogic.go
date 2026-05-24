package logic

import (
	"context"

	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/spf13/viper"
	"github.com/zeromicro/go-zero/core/logx"
)

type WechatAuthorizeURLLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewWechatAuthorizeURLLogic(ctx context.Context, svcCtx *svc.ServiceContext) *WechatAuthorizeURLLogic {
	return &WechatAuthorizeURLLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *WechatAuthorizeURLLogic) WechatAuthorizeURL(in *super.WechatAuthorizeURLReq) (*super.WechatAuthorizeURLResp, error) {
	if !viper.GetBool("wechat.enabled") {
		if !viper.IsSet("wechat.enabled") {
			return nil, errorx.New(503, "未配置微信登录：请在 config.yaml 添加 wechat 段（enabled: true）并重启 RPC")
		}
		return nil, errorx.New(503, "微信登录未启用")
	}
	flow := utils.NormalizeWechatOAuthFlow(in.GetFlow())
	if flow == "" {
		flow = "website"
	}
	url, err := utils.WechatOAuthAuthorizeURLForFlow(in.GetState(), flow)
	if err != nil {
		return nil, errorx.InvalidArgument(err.Error())
	}
	return &super.WechatAuthorizeURLResp{AuthorizeUrl: url}, nil
}
