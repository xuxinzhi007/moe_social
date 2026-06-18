package mediahttp

import (
	"context"
	"net/http"

	mediabiz "backend/internal/biz/media"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func claimsFromContext(ctx context.Context) (*utils.CustomClaims, error) {
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return nil, errUnauthorized
	}
	return claimsFromRequest(req)
}

func claimsFromRequest(r *http.Request) (*utils.CustomClaims, error) {
	claims, err := mediabiz.ParseClaimsFromRequest(r)
	if err != nil {
		return nil, errUnauthorized
	}
	return claims, nil
}
