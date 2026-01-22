package logic

import (
	"context"
	"strconv"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserInfoLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateUserInfoLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserInfoLogic {
	return &UpdateUserInfoLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpdateUserInfoLogic) UpdateUserInfo(in *super.UpdateUserInfoReq) (*super.UpdateUserInfoResp, error) {
	// 1. 查找用户
	var user model.User
	result := l.svcCtx.DB.First(&user, in.UserId)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	// 2. 更新用户信息
	if in.Username != "" {
		user.Username = in.Username
	}
	if in.Email != "" {
		user.Email = in.Email
	}
	// 更新头像（即使为空字符串也要更新，允许清空头像）
	user.Avatar = in.Avatar

	// 更新个性签名
	if in.Signature != "" {
		if len(in.Signature) > 100 {
			return nil, errorx.InvalidArgument("个性签名长度不能超过100个字符")
		}
		user.Signature = in.Signature
	}

	// 更新性别
	if in.Gender != "" {
		validGenders := []string{"male", "female", "secret"}
		found := false
		for _, g := range validGenders {
			if in.Gender == g {
				found = true
				break
			}
		}
		if !found {
			return nil, errorx.InvalidArgument("性别必须是 male、female 或 secret")
		}
		user.Gender = in.Gender
	}

	// 更新生日
	if in.Birthday != "" {
		// 解析生日日期 (支持 YYYY-MM-DD 格式)
		birthday, err := time.Parse("2006-01-02", in.Birthday)
		if err != nil {
			return nil, errorx.InvalidArgument("生日格式错误，请使用 YYYY-MM-DD 格式")
		}
		// 验证生日不能是未来日期
		if birthday.After(time.Now()) {
			return nil, errorx.InvalidArgument("生日不能是未来日期")
		}
		user.Birthday = &birthday
	}

	// 更新背包
	if in.Inventory != "" {
		user.Inventory = in.Inventory
	}

	// 更新佩戴头像框
	if in.ClearEquippedFrame {
		user.EquippedFrameId = ""
	} else if in.EquippedFrameId != "" {
		user.EquippedFrameId = in.EquippedFrameId
	}

	// 3. 保存更新
	err := l.svcCtx.DB.Save(&user).Error
	if err != nil {
		l.Error("更新用户信息失败: ", err)
		return nil, errorx.Internal("更新用户信息失败，请稍后重试")
	}

	// 4. 构建响应
	vipEndAt := ""
	if user.VipEndAt != nil {
		vipEndAt = user.VipEndAt.Format("2006-01-02 15:04:05")
	}

	birthday := ""
	if user.Birthday != nil {
		birthday = user.Birthday.Format("2006-01-02")
	}

	return &super.UpdateUserInfoResp{
		User: &super.User{
			Id:           strconv.Itoa(int(user.ID)),
			Username:     user.Username,
			Email:        user.Email,
			Avatar:       user.Avatar,
			Signature:    user.Signature,
			Gender:       user.Gender,
			Birthday:     birthday,
			CreatedAt:    user.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt:    user.UpdatedAt.Format("2006-01-02 15:04:05"),
			IsVip:        user.IsVip,
			VipExpiresAt: vipEndAt,
			AutoRenew:    user.AutoRenew,
			Balance:      float32(user.Balance),
			Inventory:    user.Inventory,
			EquippedFrameId: user.EquippedFrameId,
		},
	}, nil
}
