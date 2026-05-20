package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListUserDevicesLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewListUserDevicesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListUserDevicesLogic {
	return &ListUserDevicesLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ListUserDevicesLogic) ListUserDevices(req *types.ListUserDevicesReq) (resp *types.ListUserDevicesResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.ListUserDevices(l.ctx, &super.ListUserDevicesReq{
		UserId: req.UserId,
		Limit:  int32(req.Limit),
		Offset: int32(req.Offset),
	})
	if err != nil {
		return &types.ListUserDevicesResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	items := make([]types.UserDeviceRecord, 0, len(rpcResp.Devices))
	for _, d := range rpcResp.Devices {
		items = append(items, types.UserDeviceRecord{
			Id:          d.Id,
			UserId:      d.UserId,
			DeviceId:    d.DeviceId,
			Platform:    d.Platform,
			OSVersion:   d.OsVersion,
			AppVersion:  d.AppVersion,
			DeviceName:  d.DeviceName,
			PayloadJSON: d.PayloadJson,
			LastSeen:    d.LastSeen,
			CreatedAt:   d.CreatedAt,
			UpdatedAt:   d.UpdatedAt,
		})
	}

	return &types.ListUserDevicesResp{
		BaseResp: common.HandleRPCError(nil, "查询设备列表成功"),
		Data:     items,
		Total:    rpcResp.Total,
		Limit:    int(rpcResp.Limit),
		Offset:   int(rpcResp.Offset),
		HasMore:  rpcResp.HasMore,
	}, nil
}
