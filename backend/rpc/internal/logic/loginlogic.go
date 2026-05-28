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

func (l *LoginLogic) Login(in *moe.LoginReq) (*moe.LoginResp, error) {
	email := strings.TrimSpace(in.GetEmail())
	username := strings.TrimSpace(in.GetUsername())
	attempt := logutil.LoginAttemptTag(email, username)

	if email == "" && username == "" {
		l.Infof("[认证] 登录失败：未填写用户名或邮箱")
		return nil, errorx.New(400, "用户名或邮箱不能为空")
	}

	user, token, err := userbiz.Login(l.ctx, l.svcCtx.UserStore(), email, username, in.GetPassword())
	if err != nil {
		if errors.Is(err, userbiz.ErrUnauthorized) {
			if email != "" || username != "" {
				l.Infof("[认证] 登录失败：凭证无效 %s", attempt)
			}
			return nil, errorx.New(401, "用户名或密码错误")
		}
		if errors.Is(err, userbiz.ErrInvalidArgument) {
			return nil, errorx.New(400, "用户名或邮箱不能为空")
		}
		l.Errorf("[认证] 登录失败：%v %s", err, attempt)
		return nil, mapUserBizErr(err)
	}

	l.Infof("[认证] 登录成功 用户ID=%d 用户名=%s Moe号=%s 邮箱=%s %s",
		user.ID, user.Username, user.MoeNo, logutil.MaskEmail(user.Email), attempt)

	return &moe.LoginResp{
		User:  modelUserToProto(&user),
		Token: token,
	}, nil
}
