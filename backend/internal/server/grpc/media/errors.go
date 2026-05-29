package mediagrpc

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var (
	errMediaAppNil  = status.Error(codes.FailedPrecondition, "MediaApp 未初始化")
	errUnauthorized = status.Error(codes.Unauthenticated, "unauthorized")
	errForbidden    = status.Error(codes.PermissionDenied, "forbidden")
	errNotFound     = status.Error(codes.NotFound, "图片不存在")
)
