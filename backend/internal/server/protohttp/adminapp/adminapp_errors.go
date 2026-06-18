package adminapphttp

import (
	"errors"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errAdminAppNil = errors.New("admin app service is nil")

var errVipAdminNil = status.Error(codes.FailedPrecondition, "vip admin unavailable")
