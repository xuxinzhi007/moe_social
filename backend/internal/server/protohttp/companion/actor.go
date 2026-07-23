package companionhttp

import (
	"context"

	"backend/internal/apilegacy/common"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

func actorUserID(ctx context.Context) (uint, error) {
	userID, err := common.UserIDUint(ctx)
	if err != nil || userID == 0 {
		return 0, kerrors.Unauthorized("UNAUTHORIZED", "请先登录")
	}
	return userID, nil
}
