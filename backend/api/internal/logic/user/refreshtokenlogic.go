package user

import (
	"context"
	"strings"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type RefreshTokenLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewRefreshTokenLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RefreshTokenLogic {
	return &RefreshTokenLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *RefreshTokenLogic) RefreshToken(req *types.RefreshTokenReq, authHeader string) (resp *types.RefreshTokenResp, err error) {
	if authHeader == "" {
		return &types.RefreshTokenResp{
			BaseResp: types.BaseResp{
				Code:    401,
				Message: "Authorization header missing",
				Success: false,
			},
		}, nil
	}

	tokenString := authHeader
	if strings.HasPrefix(authHeader, "Bearer ") {
		tokenString = strings.TrimPrefix(authHeader, "Bearer ")
	}

	claims, parseErr := utils.ParseToken(tokenString)
	if parseErr != nil {
		return &types.RefreshTokenResp{
			BaseResp: types.BaseResp{
				Code:    401,
				Message: "invalid token",
				Success: false,
			},
		}, nil
	}

	newToken, genErr := utils.GenerateToken(claims.UserID, claims.Username)
	if genErr != nil {
		l.Errorf("generate refresh token failed: %v", genErr)
		return &types.RefreshTokenResp{
			BaseResp: types.BaseResp{
				Code:    500,
				Message: "failed to generate token",
				Success: false,
			},
		}, nil
	}

	return &types.RefreshTokenResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data: types.RefreshTokenData{
			Token: newToken,
		},
	}, nil
}

