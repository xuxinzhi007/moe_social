package logic

import (
	"context"
	"fmt"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteUserLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteUserLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteUserLogic {
	return &DeleteUserLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *DeleteUserLogic) DeleteUser(in *super.DeleteUserReq) (*super.DeleteUserResp, error) {
	var user model.User
	result := l.svcCtx.DB.First(&user, in.UserId)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	if err := scrubUserBeforeDelete(&user); err != nil {
		l.Errorf("[认证] 注销账号：清理用户资料失败 用户ID=%d 错误=%v", user.ID, err)
		return nil, errorx.Internal("注销账号失败，请稍后重试")
	}
	if err := l.svcCtx.DB.Save(&user).Error; err != nil {
		l.Errorf("[认证] 注销账号：保存清理结果失败 用户ID=%d 错误=%v", user.ID, err)
		return nil, errorx.Internal("注销账号失败，请稍后重试")
	}

	if err := l.svcCtx.DB.Delete(&user).Error; err != nil {
		l.Errorf("[认证] 注销账号：删除用户失败 用户ID=%d 错误=%v", user.ID, err)
		return nil, errorx.Internal("注销账号失败，请稍后重试")
	}

	l.Infof("[认证] 用户已注销 用户ID=%d", user.ID)
	return &super.DeleteUserResp{}, nil
}

func scrubUserBeforeDelete(user *model.User) error {
	if user == nil {
		return fmt.Errorf("user is nil")
	}
	ts := time.Now().Unix()
	user.Username = fmt.Sprintf("deleted_%d", user.ID)
	user.Email = fmt.Sprintf("deleted_%d_%d@deleted.local", user.ID, ts)
	user.WechatOpenID = nil
	user.WechatUnionID = ""
	user.WechatNickname = ""
	user.FeishuOpenID = nil
	user.FeishuEmail = ""
	user.FeishuName = ""
	user.Password = randomWechatPassword()
	return nil
}
