package httplegacy

import (
	"context"
	"net/http"

	"backend/internal/platform/svc"
	"backend/internal/legacy/types"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// invokeLogicJSON 解析 types 请求并调用 legacy logic，返回可 JSON 序列化的响应。
func invokeLogicJSON[Req any](
	svcCtx *svc.ServiceContext,
	call func(context.Context, *svc.ServiceContext, *Req) (any, error),
) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req Req
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		resp, err := call(ctx, svcCtx, &req)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

// invokeLogicEmpty 无 body 的 GET 等请求。
func invokeLogicEmpty(
	svcCtx *svc.ServiceContext,
	call func(context.Context, *svc.ServiceContext) (any, error),
) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		resp, err := call(ctx, svcCtx)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}
