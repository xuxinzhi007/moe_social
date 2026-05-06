package logic

import (
	"context"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

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
	// 更新头像：仅当传入非空字符串时才更新；去掉 host，只存 /api/images/... 或外链
	if in.Avatar != "" {
		user.Avatar = utils.NormalizeAvatarForStorage(in.Avatar)
	}

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

	if mt := strings.TrimSpace(in.MessageRetention); mt != "" {
		switch strings.ToLower(mt) {
		case "auto", "default", "0":
			user.MessageRetentionChoice = 0
		case "7":
			user.MessageRetentionChoice = 7
		case "30":
			user.MessageRetentionChoice = 30
		default:
			return nil, errorx.InvalidArgument("message_retention 仅支持 auto、7、30")
		}
	}

	// 3. 保存更新
	// Use Updates to avoid touching unrelated fields (especially Password).
	updates := map[string]interface{}{}
	if in.Username != "" {
		updates["username"] = user.Username
	}
	if in.Email != "" {
		updates["email"] = user.Email
	}
	if in.Avatar != "" {
		updates["avatar"] = user.Avatar
	}
	if in.Signature != "" {
		updates["signature"] = user.Signature
	}
	if in.Gender != "" {
		updates["gender"] = user.Gender
	}
	if in.Birthday != "" {
		updates["birthday"] = user.Birthday
	}
	if in.Inventory != "" {
		updates["inventory"] = user.Inventory
	}
	if in.ClearEquippedFrame {
		updates["equipped_frame_id"] = ""
	} else if in.EquippedFrameId != "" {
		updates["equipped_frame_id"] = user.EquippedFrameId
	}
	if strings.TrimSpace(in.MessageRetention) != "" {
		updates["message_retention_choice"] = user.MessageRetentionChoice
	}

	if len(updates) == 0 {
		_ = l.svcCtx.DB.First(&user, user.ID).Error
		return &super.UpdateUserInfoResp{User: modelUserToProto(&user)}, nil
	}

	err := l.svcCtx.DB.Model(&user).Updates(updates).Error
	if err != nil {
		l.Error("更新用户信息失败: ", err)
		return nil, errorx.Internal("更新用户信息失败，请稍后重试")
	}

	_ = l.svcCtx.DB.First(&user, user.ID).Error
	return &super.UpdateUserInfoResp{User: modelUserToProto(&user)}, nil
}
