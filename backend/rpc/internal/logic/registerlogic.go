package logic

import (
	"context"
	"errors"
	"strings"

	userbiz "backend/internal/biz/user"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/logutil"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
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

func (l *RegisterLogic) Register(in *moe.RegisterReq) (*moe.RegisterResp, error) {
	username := strings.TrimSpace(in.GetUsername())
	emailNorm := strings.ToLower(strings.TrimSpace(in.GetEmail()))
	if username == "" {
		return nil, errorx.New(400, "用户名不能为空")
	}
	if emailNorm == "" {
		return nil, errorx.New(400, "邮箱不能为空")
	}

	user, token, err := userbiz.Register(l.ctx, l.svcCtx.DB, username, emailNorm, in.GetPassword())
	if err != nil {
		if errors.Is(err, userbiz.ErrAlreadyExists) {
			if strings.Contains(err.Error(), "email") {
				// generic message from caller paths
			}
			l.Infof("[认证] 注册失败：冲突 用户名=%s", username)
			return nil, errorx.AlreadyExists("用户名或邮箱已存在")
		}
		l.Errorf("[认证] 注册失败：%v", err)
		return nil, mapUserBizErr(err)
	}

	l.Infof("[认证] 注册成功 用户ID=%d 用户名=%s Moe号=%s 邮箱=%s",
		user.ID, user.Username, user.MoeNo, logutil.MaskEmail(user.Email))

	return &moe.RegisterResp{
		User:  modelUserToProto(&user),
		Token: token,
	}, nil
}
