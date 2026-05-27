package utils

import (
	"fmt"
	"log"
	"sync"
	"time"

	"backend/model"

	"github.com/spf13/viper"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// DB 全局数据库实例
var DB *gorm.DB

var dbInitOnce sync.Once
var dbInitErr error

// EnsureDB 在 API 等进程中懒加载一次数据库（与 RPC 共用全局 DB；已连接则直接复用）。
func EnsureDB() error {
	return InitDBWithMigrate(MigrateOptions{Enabled: false})
}

// InitConfig 初始化配置
func InitConfig() error {
	// 设置配置文件路径
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")

	// 添加多个配置文件路径，支持从不同目录读取
	viper.AddConfigPath("./config")                                                 // 当前目录下的config
	viper.AddConfigPath("../config")                                                // 父目录下的config
	viper.AddConfigPath("../../config")                                             // 祖父目录下的config
	viper.AddConfigPath("/Users/admin/Documents/SuperAI_WebProject/backend/config") // 绝对路径

	// 读取配置文件
	if err := viper.ReadInConfig(); err != nil {
		return fmt.Errorf("读取配置文件失败: %v", err)
	}

	return nil
}

// InitDB 初始化数据库连接。
// runAutoMigrate 为 true 时执行 GORM AutoMigrate（改模型/首启库时用）；日常启动传 false，避免多副本抢 DDL、加快启动。
func InitDB(runAutoMigrate bool) error {
	return InitDBWithMigrate(MigrateOptions{Enabled: runAutoMigrate})
}

// InitDBWithMigrate 初始化数据库；迁移时使用 Silent 日志并按 schema hash 跳过未变更表。
// 进程内只连接一次（make moe-social 时 RPC 与 API 共用）；重复调用仅复用全局 DB。
func InitDBWithMigrate(opts MigrateOptions) error {
	if DB != nil {
		if opts.Enabled {
			return RunAutoMigrate(DB, opts)
		}
		return nil
	}

	dbInitOnce.Do(func() {
		dbInitErr = initDBWithMigrateOnce(opts)
	})
	return dbInitErr
}

func initDBWithMigrateOnce(opts MigrateOptions) error {
	if DB != nil {
		return nil
	}
	logMode := logger.Info
	if opts.Enabled {
		logMode = logger.Silent
	}
	gormConfig := &gorm.Config{
		Logger:                                   logger.Default.LogMode(logMode),
		DisableForeignKeyConstraintWhenMigrating: true,
	}

	// 构建MySQL连接DSN
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=%s&parseTime=%t&loc=%s",
		viper.GetString("database.user"),
		viper.GetString("database.password"),
		viper.GetString("database.host"),
		viper.GetInt("database.port"),
		viper.GetString("database.dbname"),
		viper.GetString("database.charset"),
		viper.GetBool("database.parseTime"),
		viper.GetString("database.loc"),
	)

	// 连接MySQL数据库
	var err error
	DB, err = gorm.Open(mysql.Open(dsn), gormConfig)
	if err != nil {
		return fmt.Errorf("连接MySQL数据库失败: %v", err)
	}

	// 配置连接池
	sqlDB, err := DB.DB()
	if err != nil {
		return fmt.Errorf("获取底层sql.DB失败: %v", err)
	}

	// 设置最大空闲连接数
	sqlDB.SetMaxIdleConns(10)
	// 设置最大打开连接数
	sqlDB.SetMaxOpenConns(100)
	// 设置连接最大生命周期
	sqlDB.SetConnMaxLifetime(1 * time.Hour)

	if opts.Enabled {
		if err := RunAutoMigrate(DB, opts); err != nil {
			return fmt.Errorf("自动迁移数据库表失败: %v", err)
		}
		log.Println("仅完成表结构迁移；运营数据（VIP/礼物/成就等）请在 Moe Admin 中导入")
	} else {
		log.Println("已跳过 AutoMigrate；改表后请执行: go run super.go -migrate")
	}

	log.Println("数据库连接成功")
	return nil
}

// EnsureAchievementSeeds 在成就定义表为空时写入默认徽章（由 Admin bootstrap 触发）。
func EnsureAchievementSeeds(db *gorm.DB) error {
	if db == nil {
		return nil
	}
	var n int64
	if err := db.Model(&model.AchievementDefinition{}).Count(&n).Error; err != nil {
		return fmt.Errorf("查询 achievement_definitions: %w", err)
	}
	if n > 0 {
		return nil
	}
	return SeedAchievementDefinitions(db)
}

// GetDB 获取数据库实例，并确保连接有效。
func GetDB() *gorm.DB {
	if DB == nil {
		_ = InitDB(false)
		return DB
	}
	// 检查连接是否有效
	sqlDB, err := DB.DB()
	if err != nil {
		// 如果获取底层sql.DB失败，尝试重新初始化
		_ = InitDB(false)
		return DB
	}

	// 使用Ping检查连接是否活跃
	if err := sqlDB.Ping(); err != nil {
		// 如果连接无效，重新初始化
		_ = InitDB(false)
	}

	return DB
}
