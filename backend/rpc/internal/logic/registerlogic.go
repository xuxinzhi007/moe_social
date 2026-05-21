package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/logutil"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type RegisterLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewRegisterLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RegisterLogic {
	return &RegisterLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 用户相关服务
func (l *RegisterLogic) Register(in *super.RegisterReq) (*super.RegisterResp, error) {
	username := strings.TrimSpace(in.Username)
	emailNorm := strings.ToLower(strings.TrimSpace(in.Email))
	if username == "" {
		return nil, errorx.New(400, "用户名不能为空")
	}
	if emailNorm == "" {
		return nil, errorx.New(400, "邮箱不能为空")
	}

	// 1. 检查用户名是否已存在
	var existingUser model.User
	err := l.svcCtx.DB.Where("username = ?", username).First(&existingUser).Error
	if err == nil {
		l.Infof("[认证] 注册失败：用户名已被占用 用户名=%s", username)
		return nil, errorx.AlreadyExists("用户名已存在")
	} else if err != gorm.ErrRecordNotFound {
		l.Errorf("[认证] 注册失败：检查用户名时数据库异常 用户名=%s 错误=%v", username, err)
		return nil, errorx.Internal("服务器内部错误")
	}

	// 2. 检查邮箱是否已存在（与登录一致：忽略大小写与首尾空格）
	err = l.svcCtx.DB.Where("LOWER(TRIM(email)) = ?", emailNorm).First(&existingUser).Error
	if err == nil {
		l.Infof("[认证] 注册失败：邮箱已被注册 邮箱=%s", logutil.MaskEmail(emailNorm))
		return nil, errorx.AlreadyExists("邮箱已被注册")
	} else if err != gorm.ErrRecordNotFound {
		l.Errorf("[认证] 注册失败：检查邮箱时数据库异常 邮箱=%s 错误=%v", logutil.MaskEmail(emailNorm), err)
		return nil, errorx.Internal("服务器内部错误")
	}

	// 3. 创建新用户
	user := model.User{
		Username: username,
		Password: in.Password,
		Email:    emailNorm,
		Avatar:   "https://picsum.photos/150", // 设置默认头像
		IsVip:    false,
	}

	// 4. 保存到数据库
	err = l.svcCtx.DB.Create(&user).Error
	if err != nil {
		l.Errorf("[认证] 注册失败：写入用户失败 用户名=%s 错误=%v", in.Username, err)
		return nil, errorx.Internal("注册失败，请稍后重试")
	}

	if _, err := utils.EnsureUserMoeNo(l.svcCtx.DB, user.ID); err != nil {
		l.Errorf("[认证] 注册过程异常：分配 Moe 号失败 用户ID=%d 错误=%v", user.ID, err)
	}
	_ = l.svcCtx.DB.First(&user, user.ID).Error

	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		l.Errorf("[认证] 注册失败：生成登录令牌失败 用户ID=%d 错误=%v", user.ID, err)
		return nil, errorx.New(500, "注册失败，请稍后重试")
	}

	l.Infof("[认证] 注册成功 用户ID=%d 用户名=%s Moe号=%s 邮箱=%s",
		user.ID, user.Username, user.MoeNo, logutil.MaskEmail(user.Email))

	return &super.RegisterResp{
		User:  modelUserToProto(&user),
		Token: token,
	}, nil
}
