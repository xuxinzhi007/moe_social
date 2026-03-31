package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
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
	// 1. 检查用户名是否已存在
	var existingUser model.User
	err := l.svcCtx.DB.Where("username = ?", in.Username).First(&existingUser).Error
	if err == nil {
		return nil, errorx.AlreadyExists("用户名已存在")
	} else if err != gorm.ErrRecordNotFound {
		l.Error("检查用户名失败: ", err)
		return nil, errorx.Internal("服务器内部错误")
	}

	// 2. 检查邮箱是否已存在
	err = l.svcCtx.DB.Where("email = ?", in.Email).First(&existingUser).Error
	if err == nil {
		return nil, errorx.AlreadyExists("邮箱已被注册")
	} else if err != gorm.ErrRecordNotFound {
		l.Error("检查邮箱失败: ", err)
		return nil, errorx.Internal("服务器内部错误")
	}

	// 3. 创建新用户
	user := model.User{
		Username: in.Username,
		Password: in.Password,
		Email:    in.Email,
		Avatar:   "https://picsum.photos/150", // 设置默认头像
		IsVip:    false,
	}

	// 4. 保存到数据库
	err = l.svcCtx.DB.Create(&user).Error
	if err != nil {
		l.Error("创建用户失败: ", err)
		return nil, errorx.Internal("注册失败，请稍后重试")
	}

	if _, err := utils.EnsureUserMoeNo(l.svcCtx.DB, user.ID); err != nil {
		l.Errorf("assign moe_no: %v", err)
	}
	_ = l.svcCtx.DB.First(&user, user.ID).Error

	return &super.RegisterResp{
		User: modelUserToProto(&user),
	}, nil
}
