package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

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
func (l *RegisterLogic) Register(in *rpc.RegisterReq) (*rpc.RegisterResp, error) {
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
		IsVip:    false,
	}

	// 4. 保存到数据库
	err = l.svcCtx.DB.Create(&user).Error
	if err != nil {
		l.Error("创建用户失败: ", err)
		return nil, errorx.Internal("注册失败，请稍后重试")
	}

	// 5. 构建响应
	vipEndAt := ""
	if user.VipEndAt != nil {
		vipEndAt = user.VipEndAt.Format("2006-01-02 15:04:05")
	}

	return &rpc.RegisterResp{
		User: &rpc.User{
			Id:           strconv.Itoa(int(user.ID)),
			Username:     user.Username,
			Email:        user.Email,
			CreatedAt:    user.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt:    user.UpdatedAt.Format("2006-01-02 15:04:05"),
			IsVip:        user.IsVip,
			VipExpiresAt: vipEndAt,
			AutoRenew:    false,
		},
	}, nil
}
