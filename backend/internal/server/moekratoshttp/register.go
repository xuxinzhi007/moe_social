package moekratoshttp

import (
	"encoding/json"
	"net/http"

	moepb "backend/api/moe/v1"
	"backend/internal/platform/kratosprogress"
	moegrpcserver "backend/internal/server/moegrpc"
	moeadmin "backend/internal/service/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// Register 注册纯 Kratos 试点 HTTP（与 go-zero :8888 并行）。
func Register(srv *khttp.Server, admin *moeadmin.AdminService) {
	if srv == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/health", healthHandler)
	r.GET("/migration", migrationHandler)
	r.GET("/kratos/v1/moe/runtimes", listRuntimesHandler(admin))
}

func healthHandler(ctx khttp.Context) error {
	return ctx.JSON(http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "moe-kratos",
		"stack":   "kratos-pure-pilot",
	})
}

func migrationHandler(ctx khttp.Context) error {
	rep := kratosprogress.Current()
	b, err := json.Marshal(rep)
	if err != nil {
		return err
	}
	ctx.Response().Header().Set("Content-Type", "application/json")
	_, err = ctx.Response().Write(b)
	return err
}

func listRuntimesHandler(admin *moeadmin.AdminService) func(khttp.Context) error {
	srv := moegrpcserver.New(admin)
	return func(ctx khttp.Context) error {
		reply, err := srv.ListRuntimes(ctx, &moepb.ListRuntimesRequest{})
		if err != nil {
			return ctx.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		return ctx.JSON(http.StatusOK, reply)
	}
}
