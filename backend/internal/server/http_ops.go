package server

import (
	"encoding/json"
	"net/http"

	moepb "backend/api/moe/v1"
	"backend/internal/platform/kratosprogress"
	moeadminhttp "backend/internal/server/protohttp"
	moeadmin "backend/internal/service/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func healthHandler(ctx khttp.Context) error {
	return ctx.JSON(http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "moe-social",
		"stack":   "kratos",
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
	srv := moeadminhttp.New(admin)
	return func(ctx khttp.Context) error {
		reply, err := srv.ListRuntimes(ctx, &moepb.ListRuntimesRequest{})
		if err != nil {
			return ctx.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		return ctx.JSON(http.StatusOK, reply)
	}
}
