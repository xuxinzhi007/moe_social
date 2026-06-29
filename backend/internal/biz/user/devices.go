package userbiz

import (
	"context"
	"encoding/json"
	"strconv"
	"strings"
	"time"

	userv1 "backend/api/user/v1"
	"backend/model"

	"gorm.io/gorm"
)

// ListUserDevices 分页列出用户设备。
func ListUserDevices(ctx context.Context, store UserStore, in *userv1.ListUserDevicesReq) (*userv1.ListUserDevicesResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	if in.GetUserId() == "" {
		return nil, ErrInvalidArgument
	}
	userID, err := strconv.Atoi(in.GetUserId())
	if err != nil {
		return nil, ErrInvalidArgument
	}
	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	offset := int(in.GetOffset())
	if offset < 0 {
		offset = 0
	}

	total, err := store.CountUserDevices(ctx, uint(userID))
	if err != nil {
		return nil, err
	}
	devices, err := store.ListUserDevices(ctx, uint(userID), offset, limit)
	if err != nil {
		return nil, err
	}

	out := make([]*userv1.UserDeviceRecord, 0, len(devices))
	for i := range devices {
		out = append(out, userDeviceToRecord(&devices[i], in.GetUserId()))
	}
	return &userv1.ListUserDevicesResp{
		Devices: out,
		Total:   total,
		Limit:   int32(limit),
		Offset:  int32(offset),
		HasMore: int64(offset+len(out)) < total,
	}, nil
}

// SyncUserDevice 同步/更新设备信息。
func SyncUserDevice(ctx context.Context, store UserStore, in *userv1.SyncUserDeviceReq) (*userv1.SyncUserDeviceResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	if in.GetUserId() == "" {
		return nil, ErrInvalidArgument
	}
	deviceID := strings.TrimSpace(in.GetDeviceId())
	if deviceID == "" {
		return nil, ErrInvalidArgument
	}
	userID, err := strconv.Atoi(in.GetUserId())
	if err != nil {
		return nil, ErrInvalidArgument
	}

	lastSeen := time.Now().UTC()
	if s := strings.TrimSpace(in.GetLastSeen()); s != "" {
		if t, err := time.Parse(time.RFC3339, s); err == nil {
			lastSeen = t.UTC()
		} else if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			lastSeen = t.UTC()
		}
	}

	payload := strings.TrimSpace(in.GetPayloadJson())
	if payload == "" {
		m := map[string]string{
			"device_id":   deviceID,
			"platform":    strings.TrimSpace(in.GetPlatform()),
			"os_version":  strings.TrimSpace(in.GetOsVersion()),
			"app_version": strings.TrimSpace(in.GetAppVersion()),
			"device_name": strings.TrimSpace(in.GetDeviceName()),
			"last_seen":   lastSeen.Format(time.RFC3339),
		}
		b, _ := json.Marshal(m)
		payload = string(b)
	}

	dev, found, err := store.FindUserDevice(ctx, uint(userID), deviceID)
	if err != nil {
		return nil, err
	}
	if !found {
		deleted, deletedFound, err := store.FindUserDeviceUnscoped(ctx, uint(userID), deviceID)
		if err != nil {
			return nil, err
		}
		if deletedFound {
			dev = deleted
			dev.DeletedAt = gorm.DeletedAt{}
		} else {
			dev = model.UserDevice{UserID: uint(userID), DeviceID: deviceID}
		}
	}

	dev.Platform = strings.TrimSpace(in.GetPlatform())
	dev.OSVersion = strings.TrimSpace(in.GetOsVersion())
	dev.AppVersion = strings.TrimSpace(in.GetAppVersion())
	dev.DeviceName = strings.TrimSpace(in.GetDeviceName())
	dev.PayloadJSON = payload
	dev.LastSeenAt = lastSeen

	if dev.ID == 0 {
		if err := store.CreateUserDevice(ctx, &dev); err != nil {
			return nil, err
		}
	} else {
		if err := store.SaveUserDeviceUnscoped(ctx, &dev); err != nil {
			return nil, err
		}
	}

	return &userv1.SyncUserDeviceResp{Device: userDeviceToRecord(&dev, in.GetUserId())}, nil
}

func userDeviceToRecord(d *model.UserDevice, userID string) *userv1.UserDeviceRecord {
	return &userv1.UserDeviceRecord{
		Id:          strconv.Itoa(int(d.ID)),
		UserId:      userID,
		DeviceId:    d.DeviceID,
		Platform:    d.Platform,
		OsVersion:   d.OSVersion,
		AppVersion:  d.AppVersion,
		DeviceName:  d.DeviceName,
		PayloadJson: d.PayloadJSON,
		LastSeen:    d.LastSeenAt.UTC().Format(time.RFC3339),
		CreatedAt:   d.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:   d.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
}
