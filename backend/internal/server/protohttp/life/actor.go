package lifehttp

import (
	"context"

	"backend/internal/apilegacy/common"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

func actorUserIDString(ctx context.Context) (string, error) {
	userID, err := common.UserIDString(ctx)
	if err != nil || userID == "" || userID == "0" {
		return "", kerrors.Unauthorized("UNAUTHORIZED", "请先登录")
	}
	return userID, nil
}
