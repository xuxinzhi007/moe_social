package moekratos

import (
	"fmt"

	moeconfv1 "backend/internal/conf/moe/v1"
	"backend/internal/platform/moeconf"
	adminapp "backend/internal/service/admin"
	moeadmin "backend/internal/service/moe"
	"backend/utils"

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

func buildMoeAdmin(_ string, db *gorm.DB) (*moeadmin.AdminService, error) {
	return moeadmin.NewAdmin(db), nil
}
