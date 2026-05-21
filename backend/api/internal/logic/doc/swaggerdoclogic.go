// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package doc

import (
	"context"
	"net/http"
	"os"

	"backend/api/internal/svc"

	"github.com/zeromicro/go-zero/core/logx"
)

type SwaggerDocLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSwaggerDocLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SwaggerDocLogic {
	return &SwaggerDocLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SwaggerDocLogic) SwaggerDoc(w http.ResponseWriter) error {
	data, err := loadSwaggerJSON()
	if err != nil {
		http.Error(w, "swagger json not found", http.StatusNotFound)
		return nil
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_, _ = w.Write(data)
	return nil
}

func loadSwaggerJSON() ([]byte, error) {
	candidates := []string{
		"./rest.swagger.json",
		"../rest.swagger.json",
		"../../rest.swagger.json",
	}
	for _, p := range candidates {
		if b, err := os.ReadFile(p); err == nil {
			return b, nil
		}
	}
	return nil, os.ErrNotExist
}
