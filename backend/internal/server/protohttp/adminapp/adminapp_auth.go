package adminapphttp

import (
	"context"
	"errors"
	"strings"

	"backend/common/errorcode"
	apicomm "backend/internal/platform/apicomm"
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
		return apicomm.WithAdminActor(ctx, claims, apicomm.ClientIP(req)), nil
	}
	claims, br := apicomm.RequireAdminToken(req)
	if br != nil {
		msg := br.Message
		if msg == "" {
			msg = "请先登录管理后台"
		}
		return ctx, status.Error(codes.Code(errorcode.E_UNAUTHORIZED), msg)
	}
	return apicomm.WithAdminActor(ctx, claims, apicomm.ClientIP(req)), nil
}

func requireAdminContext(ctx context.Context) (context.Context, error) {
	if ctx.Value("admin_id") != nil {
		return ctx, nil
	}
	actx, err := adminContext(ctx)
	if err != nil {
		return ctx, err
	}
	if _, ok := apicomm.AdminActorFromContext(actx); !ok {
		return ctx, errors.New("admin actor missing")
	}
	return actx, nil
}

// requireSuperAdmin 要求已登录且角色为 super_admin（jwtAuthFilter 注入 admin_role）。
func requireSuperAdmin(ctx context.Context) error {
	if _, err := requireAdminContext(ctx); err != nil {
		return err
	}
	role, _ := ctx.Value("admin_role").(string)
	if strings.EqualFold(strings.TrimSpace(role), "super_admin") {
		return nil
	}
	return status.Error(codes.PermissionDenied, "需要 super_admin 权限")
}
