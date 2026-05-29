# 数据库操作指南

## 概述

Moe Social项目使用MySQL作为主数据库，并通过GORM库进行ORM操作。本指南将详细介绍如何在项目中进行数据库操作，包括模型定义、查询、事务处理等。

## 环境配置

### 依赖安装

在Go项目中，需要安装以下依赖：

```bash
go get gorm.io/gorm
go get gorm.io/driver/mysql
```

### 数据库连接

在`backend/utils/db.go`中配置数据库连接：

```go
package utils

import (
	"log"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var DB *gorm.DB

func InitDB() {
	dsn := "username:password@tcp(localhost:3306)/moe_social?charset=utf8mb4&parseTime=True&loc=Local"
	var err error
	DB, err = gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	log.Println("Database connected successfully")
}
```

## 模型定义

模型定义位于`backend/model`目录下，以下是一些核心模型的示例：

### 用户模型

```go
// model/user.go
type User struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	Username     string    `gorm:"size:50;not null" json:"username"`
	Email        string    `gorm:"size:100;uniqueIndex;not null" json:"email"`
	Password     string    `gorm:"size:100;not null" json:"-"`
	Avatar       string    `gorm:"size:255" json:"avatar"`
	Gender       string    `gorm:"size:10" json:"gender"`
	Bio          string    `gorm:"size:500" json:"bio"`
	LevelID      uint      `json:"level_id"`
	Level        UserLevel `gorm:"foreignKey:LevelID" json:"level,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}
```

### 帖子模型

```go
// model/post.go
type Post struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	UserID    uint      `json:"user_id"`
	User      User      `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Content   string    `gorm:"size:1000;not null" json:"content"`
	ImageURL  string    `gorm:"size:255" json:"image_url"`
	Likes     int       `gorm:"default:0" json:"likes"`
	Comments  int       `gorm:"default:0" json:"comments"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
```

## 数据库操作

### 基础CRUD操作

#### 创建记录

```go
user := User{
	Username: "testuser",
	Email:    "test@example.com",
	Password: hashedPassword,
}
result := DB.Create(&user)
if result.Error != nil {
	// 处理错误
}
```

#### 查询记录

```go
// 查询单个记录
var user User
DB.First(&user, 1) // 根据ID查询

// 条件查询
DB.Where("email = ?", "test@example.com").First(&user)

// 查询多个记录
var users []User
DB.Where("level_id > ?", 1).Find(&users)
```

#### 更新记录

```go
// 更新单个字段
DB.Model(&user).Update("username", "newname")

// 更新多个字段
DB.Model(&user).Updates(User{Username: "newname", Bio: "New bio"})
```

#### 删除记录

```go
// 根据ID删除
DB.Delete(&User{}, 1)

// 条件删除
DB.Where("email = ?", "test@example.com").Delete(&User{})
```

### 关联查询

```go
// 预加载关联数据
var post Post
DB.Preload("User").First(&post, 1)

// 多级预加载
var user User
DB.Preload("Posts").Preload("Comments").First(&user, 1)
```

### 事务处理

```go	tx := DB.Begin()

// 在事务中执行操作
if err := tx.Create(&user).Error; err != nil {
	tx.Rollback()
	return err
}

if err := tx.Create(&post).Error; err != nil {
	tx.Rollback()
	return err
}

// 提交事务
return tx.Commit().Error
```

## 数据库迁移

### 自动迁移

使用GORM的自动迁移功能创建表结构：

```go
func AutoMigrate() {
	DB.AutoMigrate(
		&User{},
		&Post{},
		&Comment{},
		&Like{},
		&Follow{},
		&UserLevel{},
		&Notification{},
		&AvatarOutfit{},
		&EmojiPack{},
		&VIPPlan{},
		&VIPOrder{},
		&VIPRecord{},
		&Transaction{},
	)
	log.Println("Database migration completed")
}
```

### 手动迁移

对于复杂的迁移，可以编写SQL脚本：

```sql
-- 创建索引
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_comments_post_id ON comments(post_id);

-- 添加字段
ALTER TABLE users ADD COLUMN last_login_at DATETIME;
```

## 性能优化

### 索引优化

为频繁查询的字段添加索引：

```go
type User struct {
	ID       uint   `gorm:"primaryKey"`
	Username string `gorm:"size:50;index"`
	Email    string `gorm:"size:100;uniqueIndex"`
}
```

### 查询优化

- 使用`Select`只查询需要的字段
- 使用`Limit`和`Offset`进行分页
- 避免N+1查询问题，使用`Preload`预加载关联数据
- 使用`Where`条件减少返回的数据量

### 连接池配置

优化数据库连接池：

```go
sqlDB, err := DB.DB()
if err != nil {
	log.Fatal(err)
}

// 设置连接池参数
sqlDB.SetMaxIdleConns(10)
sqlDB.SetMaxOpenConns(100)
sqlDB.SetConnMaxLifetime(time.Hour)
```

## 最佳实践

1. **模型设计**：合理设计模型结构，使用适当的字段类型和约束
2. **事务使用**：对于涉及多个操作的业务逻辑，使用事务确保数据一致性
3. **索引使用**：为频繁查询的字段添加索引，但避免过度索引
4. **查询优化**：使用适当的查询方法，避免全表扫描
5. **错误处理**：妥善处理数据库操作错误，确保系统稳定性
6. **安全措施**：使用参数化查询，避免SQL注入攻击
7. **日志记录**：记录重要的数据库操作，便于排查问题

## 常见问题

### 连接问题

- 检查数据库服务是否运行
- 验证连接字符串是否正确
- 检查网络连接和防火墙设置

### 迁移问题

- 确保模型定义正确
- 对于复杂的迁移，考虑使用手动SQL脚本
- 迁移前备份数据库

### 性能问题

- 分析慢查询日志
- 优化查询语句和索引
- 考虑使用缓存减少数据库负载

## 总结

本指南介绍了Moe Social项目中数据库操作的核心概念和最佳实践。通过合理使用GORM和MySQL，可以构建高效、可靠的数据库层，为应用提供强大的数据支持。

在实际开发中，应根据具体业务需求选择合适的数据库操作方式，并不断优化数据库性能，确保系统的稳定性和响应速度。