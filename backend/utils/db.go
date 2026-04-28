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
		ensureDBErr = InitDB()
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

// InitDB 初始化数据库连接
func InitDB() error {
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

	// 自动迁移数据库表
	if err := autoMigrate(); err != nil {
		return fmt.Errorf("自动迁移数据库表失败: %v", err)
	}
	postMigrate(DB)

	log.Println("数据库连接成功")
	return nil
}

// autoMigrate 自动迁移数据库表（并发执行）
func autoMigrate() error {
	// 创建多个数据库连接用于并发迁移
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

	// 创建并发迁移任务
	migrateGroups := [][]interface{}{
		// 组1：用户和VIP相关
		{
			&model.User{},
			&model.VipPlan{},
			&model.VipOrder{},
			&model.VipRecord{},
			&model.Transaction{},
		},
		// 组2：社交相关
		{
			&model.Post{},
			&model.PostReport{},
			&model.Like{},
			&model.TopicTag{},
			&model.PostTopic{},
			&model.Comment{},
			&model.Follow{},
		},
		// 组3：通知和形象相关
		{
			&model.Notification{},
			&model.UserAvatar{},
			&model.AvatarOutfit{},
			&model.Emoji{},
			&model.EmojiPack{},
			&model.UserEmojiPack{},
			&model.UserMemory{},
		},
		// 组4：签到等级系统
		{
			&model.UserLevel{},
			&model.LevelConfig{},
			&model.UserCheckIn{},
			&model.CheckInReward{},
			&model.ExpLog{},
			&model.FriendRequest{},
		},
		// 组5：礼物和社区相关
		{
			&model.Gift{},
			&model.GiftRecord{},
			&model.Group{},
			&model.GroupMember{},
			&model.GroupPost{},
		},
	}

	// 使用 WaitGroup 等待所有迁移完成
	var wg sync.WaitGroup
	errChan := make(chan error, len(migrateGroups))

	// 并发执行迁移
	for _, group := range migrateGroups {
		wg.Add(1)
		go func(models []interface{}) {
			defer wg.Done()

			// 为每个组创建独立的数据库连接
			db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
				Logger: logger.Default.LogMode(logger.Warn), // 减少日志输出
			})
			if err != nil {
				errChan <- fmt.Errorf("创建迁移连接失败: %v", err)
				return
			}

			// 设置连接池参数
			sqlDB, _ := db.DB()
			sqlDB.SetMaxIdleConns(2)
			sqlDB.SetMaxOpenConns(5)
			sqlDB.SetConnMaxLifetime(1 * time.Hour)

			// 执行迁移
			if err := db.AutoMigrate(models...); err != nil {
				errChan <- fmt.Errorf("迁移失败: %v", err)
				return
			}

			// 关闭连接
			sqlDB.Close()
		}(group)
	}

	// 等待所有迁移完成
	wg.Wait()
	close(errChan)

	// 检查是否有错误
	for err := range errChan {
		if err != nil {
			return err
		}
	}

	log.Println("数据库表迁移完成（并发执行）")
	return nil
}

// After auto-migrate hooks for legacy rows.
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
		InitDB()
		return DB
	}

	// 使用Ping检查连接是否活跃
	if err := sqlDB.Ping(); err != nil {
		// 如果连接无效，重新初始化
		InitDB()
	}

	return DB
}
