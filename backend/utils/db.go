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

var ensureDBOnce sync.Once
var ensureDBErr error

// EnsureDB 在 API 等进程中懒加载一次数据库（与 RPC 共用全局 DB）。
func EnsureDB() error {
	ensureDBOnce.Do(func() {
		if err := InitConfig(); err != nil {
			ensureDBErr = err
			return
		}
		ensureDBErr = InitDB(false)
	})
	return ensureDBErr
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
	// 配置gorm日志
	gormConfig := &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
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

	if runAutoMigrate {
		if err := autoMigrate(); err != nil {
			return fmt.Errorf("自动迁移数据库表失败: %v", err)
		}
		postMigrate(DB)
	} else {
		log.Println("已跳过 AutoMigrate 与启动数据同步（补 moe_no、默认礼物）；改表/改种子后请执行: go run super.go -migrate")
	}

	log.Println("数据库连接成功")
	return nil
}

// autoMigrate 自动迁移数据库表（串行执行，避免并发建表竞争）
func autoMigrate() error {
	// 模型之间存在外键/关联依赖，并发迁移会在首次建表时竞争创建同一张表（如 users）。
	// 串行迁移能保证幂等和稳定，避免 "Table already exists" 导致启动失败。
	models := []interface{}{
		// 用户和VIP相关
		&model.User{},
		&model.VipPlan{},
		&model.VipOrder{},
		&model.VipRecord{},
		&model.Transaction{},
		// 社交相关
		&model.Post{},
		&model.PostReport{},
		&model.Like{},
		&model.TopicTag{},
		&model.PostTopic{},
		&model.Comment{},
		&model.Follow{},
		// 通知和形象相关
		&model.Notification{},
		&model.UserAvatar{},
		&model.AvatarOutfit{},
		&model.Emoji{},
		&model.EmojiPack{},
		&model.UserEmojiPack{},
		&model.UserMemory{},
		// 签到等级系统
		&model.UserLevel{},
		&model.LevelConfig{},
		&model.UserCheckIn{},
		&model.CheckInReward{},
		&model.ExpLog{},
		&model.FriendRequest{},
		// 礼物和社区相关
		&model.Gift{},
		&model.GiftRecord{},
		&model.Group{},
		&model.GroupMember{},
		&model.GroupPost{},
		&model.PrivateMessage{},
	}

	if err := DB.AutoMigrate(models...); err != nil {
		return fmt.Errorf("迁移失败: %v", err)
	}

	log.Println("数据库表迁移完成（串行执行）")
	return nil
}

// postMigrate 仅在 -migrate 时调用：与 AutoMigrate 同频，避免每次普通启动扫表、写礼物。
func postMigrate(db *gorm.DB) {
	BackfillAllUserMoeNos(db)
	SeedDefaultGifts(db)
}

// GetDB 获取数据库实例，并确保连接有效
func GetDB() *gorm.DB {
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
