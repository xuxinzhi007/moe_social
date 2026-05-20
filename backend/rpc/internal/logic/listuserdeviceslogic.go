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

type ListUserDevicesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListUserDevicesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListUserDevicesLogic {
	return &ListUserDevicesLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListUserDevicesLogic) ListUserDevices(in *super.ListUserDevicesReq) (*super.ListUserDevicesResp, error) {
	start := time.Now()
	if in.UserId == "" {
		return nil, errorx.InvalidArgument("user_id不能为空")
	}

	userID, err := strconv.Atoi(in.UserId)
	if err != nil {
		return nil, errorx.InvalidArgument("无效的user_id")
	}

	limit := int(in.Limit)
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	offset := int(in.Offset)
	if offset < 0 {
		offset = 0
	}

	scope := l.svcCtx.DB.Model(&model.UserDevice{}).Where("user_id = ?", uint(userID))

	var total int64
	if err := scope.Count(&total).Error; err != nil {
		l.Error("统计用户设备总数失败: ", err)
		return nil, errorx.Internal("查询设备列表失败")
	}

	var devices []model.UserDevice
	if err := scope.Order("last_seen_at desc").
		Offset(offset).
		Limit(limit).
		Find(&devices).Error; err != nil {
		l.Error("查询用户设备列表失败: ", err)
		return nil, errorx.Internal("查询设备列表失败")
	}
	if cost := time.Since(start); cost > 150*time.Millisecond {
		l.Infof("slow list user devices, user_id=%d limit=%d offset=%d total=%d cost_ms=%d",
			userID, limit, offset, total, cost.Milliseconds())
	}

	out := make([]*super.UserDeviceRecord, 0, len(devices))
	for i := range devices {
		out = append(out, userDeviceToRecord(&devices[i], in.UserId))
	}

	return &super.ListUserDevicesResp{
		Devices: out,
		Total:   total,
		Limit:   int32(limit),
		Offset:  int32(offset),
		HasMore: int64(offset+len(out)) < total,
	}, nil
}
