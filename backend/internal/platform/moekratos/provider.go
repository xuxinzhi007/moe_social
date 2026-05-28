package moekratos

import (
	"context"
	"fmt"
	"time"

	moeconfv1 "backend/internal/conf/moe/v1"
	"backend/internal/platform/moeconf"
	"backend/internal/platform/moewiring"
	adminapp "backend/internal/service/admin"
	moeadmin "backend/internal/service/moe"
	"backend/rpc/pb/super"
	"backend/utils"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"gorm.io/gorm"
)

func provideBootstrap() (*moeconfv1.Bootstrap, error) {
	return moeconf.LoadBootstrap()
}

func provideMigrate(opts Options) utils.MigrateOptions {
	return opts.Migrate
}

func provideDB(migrate utils.MigrateOptions) (*gorm.DB, error) {
	if err := utils.InitDBWithMigrate(migrate); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, fmt.Errorf("db: nil after init")
	}
	return db, nil
}

func provideSuperRPC(opts Options, bootstrap *moeconfv1.Bootstrap) string {
	if opts.SuperRPC != "" {
		return opts.SuperRPC
	}
	if bootstrap != nil && bootstrap.GetServer() != nil {
		return bootstrap.GetServer().GetSuperRpcEndpoint()
	}
	return ""
}

func provideGRPCAddr(opts Options, bootstrap *moeconfv1.Bootstrap) string {
	if opts.GRPCAddr != "" {
		return opts.GRPCAddr
	}
	if bootstrap != nil && bootstrap.GetServer() != nil && bootstrap.GetServer().GetGrpcAddr() != "" {
		return bootstrap.GetServer().GetGrpcAddr()
	}
	return ":19031"
}

func provideHTTPAddr(opts Options, bootstrap *moeconfv1.Bootstrap) string {
	if opts.HTTPAddr != "" {
		return opts.HTTPAddr
	}
	if bootstrap != nil && bootstrap.GetServer() != nil && bootstrap.GetServer().GetHttpAddr() != "" {
		return bootstrap.GetServer().GetHttpAddr()
	}
	return ":19032"
}

func provideMoeAdmin(db *gorm.DB, superRPC string) (*moeadmin.AdminService, error) {
	return buildMoeAdmin(superRPC, db)
}

func provideAdminApp(db *gorm.DB) (*adminapp.AppService, error) {
	if db == nil {
		return nil, fmt.Errorf("admin app: db is nil")
	}
	return adminapp.New(db), nil
}

func buildApp(
	bootstrap *moeconfv1.Bootstrap,
	moeAdmin *moeadmin.AdminService,
	adminApp *adminapp.AppService,
	grpcAddr, httpAddr, superRPC string,
	db *gorm.DB,
) *App {
	return newApp(bootstrap, moeAdmin, adminApp, grpcAddr, httpAddr, superRPC, db)
}

func buildMoeAdmin(superRPC string, db *gorm.DB) (*moeadmin.AdminService, error) {
	if superRPC == "" {
		return moeadmin.NewAdmin(db), nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	conn, err := grpc.DialContext(ctx, superRPC,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
	)
	if err != nil {
		return nil, fmt.Errorf("super rpc dial %s: %w", superRPC, err)
	}
	client := super.NewSuperClient(conn)
	admin, err := moewiring.NewAPIAdminService(client)
	if err != nil {
		_ = conn.Close()
		return nil, err
	}
	if admin == nil {
		_ = conn.Close()
		return moeadmin.NewAdmin(db), nil
	}
	return admin, nil
}
