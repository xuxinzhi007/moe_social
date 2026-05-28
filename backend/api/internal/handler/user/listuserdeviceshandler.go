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

func ListUserDevicesHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ListUserDevicesReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		rpcResp, err := svcCtx.UserGW.ListUserDevices(r.Context(), &moe.ListUserDevicesReq{
			UserId: req.UserId,
			Limit:  int32(req.Limit),
			Offset: int32(req.Offset),
		})
		if err != nil {
			httpx.OkJsonCtx(r.Context(), w, &types.ListUserDevicesResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
			return
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

		httpx.OkJsonCtx(r.Context(), w, &types.ListUserDevicesResp{
			BaseResp: common.HandleRPCError(nil, "查询设备列表成功"),
			Data:     items,
			Total:    rpcResp.Total,
			Limit:    int(rpcResp.Limit),
			Offset:   int(rpcResp.Offset),
			HasMore:  rpcResp.HasMore,
		})
	}
}
