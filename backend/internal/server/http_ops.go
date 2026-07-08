package server

import (
	"net/http"

	moepb "backend/api/moe/v1"
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
