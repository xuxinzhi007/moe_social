package voice

import (
	"context"
	"encoding/json"
	"errors"

	"backend/api/internal/svc"
	"backend/api/internal/types"

	rtctokenbuilder "github.com/AgoraIO-Community/go-tokenbuilder/rtctokenbuilder"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetRtcTokenLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetRtcTokenLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetRtcTokenLogic {
	return &GetRtcTokenLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetRtcTokenLogic) GetRtcToken(req *types.GetRtcTokenReq) (resp *types.GetRtcTokenResp, err error) {
	appId := l.svcCtx.Config.Agora.AppId
	appCertificate := l.svcCtx.Config.Agora.AppCertificate

	if appId == "" || appCertificate == "" {
		// 如果未配置，返回一个特定的错误提示
		return nil, errors.New("Agora AppId/Certificate not configured")
	}

	userAccount := req.UserAccount
	if userAccount == "" {
		// 尝试从 Context 获取 userId
		// jwt 中间件通常将 payload 放入 context，key 为 "userId" (取决于 jwt 生成时的 claim key)
		// 这里尝试获取 "userId"
		uidVal := l.ctx.Value("userId")
		if uidVal == nil {
			// 尝试 "user_id"
			uidVal = l.ctx.Value("user_id")
		}

		if uidVal == nil {
			return nil, errors.New("User not logged in or userId not found in context")
		}

		// 处理 json.Number 或 string
		switch v := uidVal.(type) {
		case string:
			userAccount = v
		case json.Number:
			userAccount = v.String()
		default:
			// 尝试强转 string
			if s, ok := uidVal.(string); ok {
				userAccount = s
			} else {
				return nil, errors.New("Invalid userId type in context")
			}
		}
	}

	// Token 有效期 24 小时
	expireTimeInSeconds := uint32(86400)

	// 角色
	role := rtctokenbuilder.RolePublisher
	if req.Role == 2 {
		role = rtctokenbuilder.RoleSubscriber
	}

	// 生成 Token
	// BuildTokenWithAccount accepts expire as seconds from now
	token, err := rtctokenbuilder.BuildTokenWithAccount(appId, appCertificate, req.ChannelName, userAccount, rtctokenbuilder.Role(role), expireTimeInSeconds)
	if err != nil {
		return nil, err
	}

	return &types.GetRtcTokenResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Token: token,
		AppId: appId,
	}, nil
}
