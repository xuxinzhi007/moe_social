package appcfg

import (
	"context"
	"errors"
	"strings"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

// ErrNoPublicAPIBaseURL 表示 backend/config/config.yaml 未配置 app_client.public_api_base_url；
// handler 映射为 HTTP 404，与 Flutter RemoteApiConfig 非 2xx 降级逻辑一致。
var ErrNoPublicAPIBaseURL = errors.New("public api base url not configured")

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
	url := strings.TrimSpace(l.svcCtx.Config.ClientPublicApiBaseUrl)
	if url == "" {
		return nil, ErrNoPublicAPIBaseURL
	}
	for strings.HasSuffix(url, "/") {
		url = strings.TrimSuffix(url, "/")
	}
	return &types.PublicClientConfigResp{ApiBaseUrl: url}, nil
}
