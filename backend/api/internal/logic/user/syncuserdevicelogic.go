package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type SyncUserDeviceLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSyncUserDeviceLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SyncUserDeviceLogic {
	return &SyncUserDeviceLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SyncUserDeviceLogic) SyncUserDevice(req *types.SyncUserDeviceReq) (resp *types.SyncUserDeviceResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.SyncUserDevice(l.ctx, &super.SyncUserDeviceReq{
		UserId:      req.UserId,
		DeviceId:    req.DeviceId,
		Platform:    req.Platform,
		OsVersion:   req.OSVersion,
		AppVersion:  req.AppVersion,
		DeviceName:  req.DeviceName,
		LastSeen:    req.LastSeen,
		PayloadJson: req.PayloadJSON,
	})
	if err != nil {
		return &types.SyncUserDeviceResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	d := rpcResp.Device
	return &types.SyncUserDeviceResp{
		BaseResp: common.HandleRPCError(nil, "同步设备信息成功"),
		Data: types.UserDeviceRecord{
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
		},
	}, nil
}
