package gifthttp

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var errGiftAppNil = status.Error(codes.FailedPrecondition, "GiftApp 未初始化")
