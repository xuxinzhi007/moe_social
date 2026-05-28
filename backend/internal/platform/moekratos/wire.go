//go:build wireinject
// +build wireinject

package moekratos

import (
	"github.com/google/wire"
)

// InitializeApp Wire 注入纯 Kratos 试点（Phase 4）。
func InitializeApp(opts Options) (*App, error) {
	wire.Build(
		provideBootstrap,
		provideMigrate,
		provideDB,
		provideSuperRPC,
		provideGRPCAddr,
		provideHTTPAddr,
		provideMoeAdmin,
		provideAdminApp,
		buildApp,
	)
	return nil, nil
}
