//go:build hybrid

package user

import (
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func SyncUserDeviceHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SyncUserDeviceReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.SyncUserDevice(r.Context(), &moe.SyncUserDeviceReq{
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
			httpx.OkJsonCtx(r.Context(), w, &types.SyncUserDeviceResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
		}

		d := rpcResp.Device
		httpx.OkJsonCtx(r.Context(), w, &types.SyncUserDeviceResp{
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
		})
	}
}
