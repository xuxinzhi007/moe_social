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

type FeishuAuthorizeURLLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewFeishuAuthorizeURLLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FeishuAuthorizeURLLogic {
	return &FeishuAuthorizeURLLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *FeishuAuthorizeURLLogic) FeishuAuthorizeURL(in *super.FeishuAuthorizeURLReq) (*super.FeishuAuthorizeURLResp, error) {
	if !viper.GetBool("feishu.enabled") {
		return nil, errorx.New(503, "飞书功能未启用")
	}
	url, err := utils.FeishuOAuthAuthorizeURL(in.GetState())
	if err != nil {
		return nil, errorx.InvalidArgument(err.Error())
	}
	return &super.FeishuAuthorizeURLResp{AuthorizeUrl: url}, nil
}
