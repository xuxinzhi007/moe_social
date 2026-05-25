package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminCreateAccountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminCreateAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateAccountLogic {
	return &AdminCreateAccountLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminCreateAccountLogic) AdminCreateAccount(in *super.AdminCreateAccountReq) (*super.AdminCreateAccountResp, error) {
	username := strings.TrimSpace(in.GetUsername())
	if username == "" {
		return nil, errorx.InvalidArgument("用户名不能为空")
	}
	if strings.TrimSpace(in.GetPassword()) == "" {
		return nil, errorx.InvalidArgument("密码不能为空")
	}
	role := strings.TrimSpace(in.GetRole())
	if role == "" {
		role = "admin"
	}
	row := model.AdminAccount{
		Username: username,
		Password: in.GetPassword(),
		Role:     role,
	}
	if err := l.svcCtx.DB.Create(&row).Error; err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "duplicate") {
			return nil, errorx.AlreadyExists("用户名已存在")
		}
		l.Errorf("[admin] create account: %v", err)
		return nil, errorx.Internal("创建管理员失败")
	}
	return &super.AdminCreateAccountResp{Account: adminAccountToProto(row)}, nil
}
