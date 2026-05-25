package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateAccountLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateAccountLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateAccountLogic {
	return &AdminUpdateAccountLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateAccountLogic) AdminUpdateAccount(in *super.AdminUpdateAccountReq) (*super.AdminUpdateAccountResp, error) {
	id, err := strconv.ParseUint(strings.TrimSpace(in.GetAccountId()), 10, 64)
	if err != nil || id == 0 {
		return nil, errorx.InvalidArgument("账号 ID 无效")
	}
	var row model.AdminAccount
	if err := l.svcCtx.DB.First(&row, id).Error; err != nil {
		return nil, errorx.NotFound("管理员不存在")
	}
	if in.GetUpdateUsername() || strings.TrimSpace(in.GetUsername()) != "" {
		username := strings.TrimSpace(in.GetUsername())
		if username == "" {
			return nil, errorx.InvalidArgument("用户名不能为空")
		}
		row.Username = username
	}
	if in.GetUpdatePassword() || strings.TrimSpace(in.GetPassword()) != "" {
		if strings.TrimSpace(in.GetPassword()) == "" {
			return nil, errorx.InvalidArgument("密码不能为空")
		}
		row.Password = in.GetPassword()
	}
	if in.GetUpdateRole() || strings.TrimSpace(in.GetRole()) != "" {
		role := strings.TrimSpace(in.GetRole())
		if role == "" {
			return nil, errorx.InvalidArgument("角色不能为空")
		}
		row.Role = role
	}
	if err := l.svcCtx.DB.Save(&row).Error; err != nil {
		l.Errorf("[admin] update account: %v", err)
		return nil, errorx.Internal("更新管理员失败")
	}
	return &super.AdminUpdateAccountResp{Account: adminAccountToProto(row)}, nil
}
