package platformgrpc

import (
	"context"
	"net/http"
	"strconv"
	"strings"

	"backend/internal/apilegacy/common"
	"backend/utils"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func actorUserIDString(ctx context.Context) (string, error) {
	if s, err := common.UserIDString(ctx); err == nil {
		return s, nil
	}
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return "", errUnauthorized
	}
	return bearerUserIDString(req)
}

func moeBearerUserID(ctx context.Context) (uint, error) {
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return 0, errUnauthorized
	}
	authHeader := req.Header.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return 0, errUnauthorized
	}
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	return utils.GetUserIDFromToken(tokenString)
}

func bearerUserIDString(r *http.Request) (string, error) {
	uid, err := bearerUserID(r)
	if err != nil {
		return "", err
	}
	return strconv.FormatUint(uint64(uid), 10), nil
}

func bearerUserID(r *http.Request) (uint, error) {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(auth, "Bearer ") {
		auth = strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
	}
	if auth == "" {
		return 0, errUnauthorized
	}
	cl, err := utils.ParseToken(auth)
	if err != nil {
		return 0, err
	}
	return cl.UserID, nil
}
