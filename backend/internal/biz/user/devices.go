package userbiz

import (
	"context"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// ListUserDevices 分页列出用户设备。
func ListUserDevices(ctx context.Context, db *gorm.DB, in *super.ListUserDevicesReq) (*super.ListUserDevicesResp, error) {
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

	scope := db.WithContext(ctx).Model(&model.UserDevice{}).Where("user_id = ?", uint(userID))
	var total int64
	if err := scope.Count(&total).Error; err != nil {
		return nil, err
	}
	var devices []model.UserDevice
	if err := scope.Order("last_seen_at desc").Offset(offset).Limit(limit).Find(&devices).Error; err != nil {
		return nil, err
	}

	out := make([]*super.UserDeviceRecord, 0, len(devices))
	for i := range devices {
		out = append(out, userDeviceToRecord(&devices[i], in.GetUserId()))
	}
	return &super.ListUserDevicesResp{
		Devices: out,
		Total:   total,
		Limit:   int32(limit),
		Offset:  int32(offset),
		HasMore: int64(offset+len(out)) < total,
	}, nil
}

// SyncUserDevice 同步/更新设备信息。
func SyncUserDevice(ctx context.Context, db *gorm.DB, in *super.SyncUserDeviceReq) (*super.SyncUserDeviceResp, error) {
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

	var dev model.UserDevice
	q := db.WithContext(ctx).Where("user_id = ? AND device_id = ?", uint(userID), deviceID).First(&dev)
	if q.Error != nil {
		if errors.Is(q.Error, gorm.ErrRecordNotFound) {
			var deleted model.UserDevice
			if err := db.WithContext(ctx).Unscoped().
				Where("user_id = ? AND device_id = ?", uint(userID), deviceID).
				First(&deleted).Error; err == nil {
				dev = deleted
				dev.DeletedAt = gorm.DeletedAt{}
			} else if errors.Is(err, gorm.ErrRecordNotFound) {
				dev = model.UserDevice{UserID: uint(userID), DeviceID: deviceID}
			} else {
				return nil, err
			}
		} else {
			return nil, q.Error
		}
	}

	dev.Platform = strings.TrimSpace(in.GetPlatform())
	dev.OSVersion = strings.TrimSpace(in.GetOsVersion())
	dev.AppVersion = strings.TrimSpace(in.GetAppVersion())
	dev.DeviceName = strings.TrimSpace(in.GetDeviceName())
	dev.PayloadJSON = payload
	dev.LastSeenAt = lastSeen

	if dev.ID == 0 {
		if err := db.WithContext(ctx).Omit("User").Create(&dev).Error; err != nil {
			return nil, err
		}
	} else {
		if err := db.WithContext(ctx).Unscoped().Save(&dev).Error; err != nil {
			return nil, err
		}
	}

	_ = db.WithContext(ctx).Where(
		"user_id = ? AND (`key` LIKE ? OR source = ?)",
		uint(userID), "device_info:%", "device_sync",
	).Delete(&model.UserMemory{}).Error

	return &super.SyncUserDeviceResp{Device: userDeviceToRecord(&dev, in.GetUserId())}, nil
}

func userDeviceToRecord(d *model.UserDevice, userID string) *super.UserDeviceRecord {
	return &super.UserDeviceRecord{
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
