package appcfg

import (
	"context"

	appcfgbiz "backend/internal/biz/appcfg"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

// ErrNoPublicAPIBaseURL 表示 backend/config/config.yaml 未配置 app_client.public_api_base_url；
// handler 映射为 HTTP 404，与 Flutter RemoteApiConfig 非 2xx 降级逻辑一致。
var ErrNoPublicAPIBaseURL = appcfgbiz.ErrNoPublicAPIBaseURL

type PublicClientConfigLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewPublicClientConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *PublicClientConfigLogic {
	return &PublicClientConfigLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *PublicClientConfigLogic) PublicClientConfig(_ *types.EmptyReq) (resp *types.PublicClientConfigResp, err error) {
	url, err := appcfgbiz.NormalizePublicAPIBaseURL(l.svcCtx.Config.ClientPublicApiBaseUrl)
	if err != nil {
		return nil, ErrNoPublicAPIBaseURL
	}
	return &types.PublicClientConfigResp{ApiBaseUrl: url}, nil
}
