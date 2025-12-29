package utils

import (
	"fmt"
	"log"
	"time"

	"backend/model"

	"github.com/spf13/viper"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// DB 全局数据库实例
var DB *gorm.DB

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

	log.Println("数据库连接成功")
	return nil
}

// autoMigrate 自动迁移数据库表
func autoMigrate() error {
	return DB.AutoMigrate(
		&model.User{},
		&model.VipPlan{},
		&model.VipOrder{},
		&model.VipRecord{},
		&model.Transaction{},  // 交易记录表
		&model.Post{},         // 帖子表
		&model.PostLike{},     // 帖子点赞表
		&model.Comment{},      // 评论表
		&model.CommentLike{},  // 评论点赞表
		&model.Notification{}, // 通知表
	)
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
