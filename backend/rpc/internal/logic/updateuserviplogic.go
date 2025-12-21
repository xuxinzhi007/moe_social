package logic

import (
	"context"
	"strconv"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserVipLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateUserVipLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserVipLogic {
	return &UpdateUserVipLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpdateUserVipLogic) UpdateUserVip(in *rpc.UpdateUserVipReq) (*rpc.UpdateUserVipResp, error) {
	// 1. 查找用户
	var user model.User
	result := l.svcCtx.DB.First(&user, in.UserId)
	if result.Error != nil {
		l.Error("查找用户失败: ", result.Error)
		return nil, errorx.NotFound("用户不存在")
	}

	// 2. 更新用户VIP状态
	if in.IsVip {
		// 激活VIP，创建VIP记录
		// 解析VIP过期时间
		vipExpires, err := time.Parse("2006-01-02 15:04:05", in.VipExpires)
		if err != nil {
			l.Error("解析VIP过期时间失败: ", err)
			return nil, errorx.InvalidArgument("VIP过期时间格式不正确")
		}

		// 将用户所有VIP记录设置为非激活
		l.svcCtx.DB.Model(&model.VipRecord{}).Where("user_id = ?", user.ID).Update("is_active", false)

		// 创建新的VIP记录
		vipStart := time.Now()
		vipRecord := model.VipRecord{
			UserID:   user.ID,
			PlanID:   1, // 默认套餐ID，后续可以根据实际情况修改
			IsActive: true,
			StartAt:  vipStart,
			EndAt:    vipExpires,
		}

		// 保存VIP记录
		if err := l.svcCtx.DB.Create(&vipRecord).Error; err != nil {
			l.Error("创建VIP记录失败: ", err)
			return nil, errorx.Internal("更新VIP状态失败，请稍后重试")
		}

		// 更新用户VIP状态
		user.IsVip = true
		user.VipStartAt = &vipStart
		user.VipEndAt = &vipExpires
	} else {
		// 非激活状态，将用户VIP状态设置为false
		user.IsVip = false
		user.VipStartAt = nil
		user.VipEndAt = nil

		// 将用户所有VIP记录设置为非激活
		l.svcCtx.DB.Model(&model.VipRecord{}).Where("user_id = ?", user.ID).Update("is_active", false)
	}

	// 3. 保存用户信息
	if err := l.svcCtx.DB.Save(&user).Error; err != nil {
		l.Error("更新用户VIP状态失败: ", err)
		return nil, errorx.Internal("更新VIP状态失败，请稍后重试")
	}

	// 4. 构建响应
	vipEndAt := ""
	if user.VipEndAt != nil {
		vipEndAt = user.VipEndAt.Format("2006-01-02 15:04:05")
	}

	return &rpc.UpdateUserVipResp{
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
