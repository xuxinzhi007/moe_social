package adminapphttp

import (
	"context"
	"errors"

	"backend/common/errorcode"
	"backend/internal/apilegacy/common"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errAdminUnauthorized = status.Error(codes.Unauthenticated, "请先登录管理后台")

func adminContext(ctx context.Context) (context.Context, error) {
	if adminID := ctx.Value("admin_id"); adminID != nil {
		return ctx, nil
	}
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return ctx, errAdminUnauthorized
	}
	token := req.Header.Get("Authorization")
	if len(token) > 7 && token[:7] == "Bearer " {
		token = token[7:]
		claims, err := utils.ParseAdminToken(token)
		if err != nil {
			return ctx, status.Error(codes.Code(errorcode.E_UNAUTHORIZED), "登录已过期，请重新登录")
		}
		return common.WithAdminActor(ctx, claims, common.ClientIP(req)), nil
	}
	claims, br := common.RequireAdminToken(req)
	if br != nil {
		msg := br.Message
		if msg == "" {
			msg = "请先登录管理后台"
		}
		return ctx, status.Error(codes.Code(errorcode.E_UNAUTHORIZED), msg)
	}
	return common.WithAdminActor(ctx, claims, common.ClientIP(req)), nil
}

func requireAdminContext(ctx context.Context) (context.Context, error) {
	if ctx.Value("admin_id") != nil {
		return ctx, nil
	}
	actx, err := adminContext(ctx)
	if err != nil {
		return ctx, err
	}
	if _, ok := common.AdminActorFromContext(actx); !ok {
		return ctx, errors.New("admin actor missing")
	}
	return actx, nil
}
