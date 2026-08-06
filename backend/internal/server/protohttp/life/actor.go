package lifehttp

import (
	"context"

	apicomm "backend/internal/platform/apicomm"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

func actorUserIDString(ctx context.Context) (string, error) {
	userID, err := apicomm.UserIDString(ctx)
	if err != nil || userID == "" || userID == "0" {
		return "", kerrors.Unauthorized("UNAUTHORIZED", "请先登录")
	}
	return userID, nil
}
