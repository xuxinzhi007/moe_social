package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type LoginLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LoginLogic {
	return &LoginLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *LoginLogic) Login(in *rpc.LoginReq) (*rpc.LoginResp, error) {
	// 1. 查找用户
	var user model.User
	var err error

	// 根据用户名或邮箱查找用户
	query := l.svcCtx.DB
	if in.Username != "" && in.Email != "" {
		// 如果同时提供了用户名和邮箱，使用OR条件
		err = query.Where("username = ? OR email = ?", in.Username, in.Email).First(&user).Error
	} else if in.Username != "" {
		// 只提供了用户名
		err = query.Where("username = ?", in.Username).First(&user).Error
	} else if in.Email != "" {
		// 只提供了邮箱
		err = query.Where("email = ?", in.Email).First(&user).Error
	} else {
		// 用户名和邮箱都为空
		return nil, errorx.New(400, "用户名或邮箱不能为空")
	}

	if err != nil {
		l.Error("查找用户失败: ", err)
		return nil, errorx.New(401, "用户名或密码错误")
	}

	// 2. 验证密码
	if !user.CheckPassword(in.Password) {
		return nil, errorx.New(401, "用户名或密码错误")
	}

	// 3. 生成JWT令牌
	token, err := utils.GenerateToken(user.ID, user.Username)
	if err != nil {
		l.Error("生成令牌失败: ", err)
		return nil, errorx.New(500, "登录失败，请稍后重试")
	}

	// 4. 构建响应
	vipEndAt := ""
	if user.VipEndAt != nil {
		vipEndAt = user.VipEndAt.Format("2006-01-02 15:04:05")
	}

	return &rpc.LoginResp{
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
		Token: token,
	}, nil
}
