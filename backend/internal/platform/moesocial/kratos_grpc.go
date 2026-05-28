package moesocial

import (
	"context"

	"github.com/zeromicro/go-zero/zrpc"
)

// zrpcServer 将 go-zero zrpc 适配为 kratos transport.Server（PK-7）。
type zrpcServer struct {
	inner *zrpc.RpcServer
}

func wrapZRPC(s *zrpc.RpcServer) *zrpcServer {
	return &zrpcServer{inner: s}
}

func (s *zrpcServer) Start(ctx context.Context) error {
	if s == nil || s.inner == nil {
		return nil
	}
	// zrpc 已在 moesocial.Run 中启动；此处随 kratos.App 生命周期阻塞至退出。
	<-ctx.Done()
	return ctx.Err()
}

func (s *zrpcServer) Stop(ctx context.Context) error {
	if s.inner != nil {
		s.inner.Stop()
	}
	return nil
}
