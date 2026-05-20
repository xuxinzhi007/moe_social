package logic

import (
	"context"
	"encoding/json"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type SyncUserDeviceLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSyncUserDeviceLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SyncUserDeviceLogic {
	return &SyncUserDeviceLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *SyncUserDeviceLogic) SyncUserDevice(in *super.SyncUserDeviceReq) (*super.SyncUserDeviceResp, error) {
	if in.UserId == "" {
		return nil, errorx.InvalidArgument("user_id不能为空")
	}
	deviceID := strings.TrimSpace(in.DeviceId)
	if deviceID == "" {
		return nil, errorx.InvalidArgument("device_id不能为空")
	}

	userID, err := strconv.Atoi(in.UserId)
	if err != nil {
		return nil, errorx.InvalidArgument("无效的user_id")
	}

	lastSeen := time.Now().UTC()
	if s := strings.TrimSpace(in.LastSeen); s != "" {
		if t, err := time.Parse(time.RFC3339, s); err == nil {
			lastSeen = t.UTC()
		} else if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
			lastSeen = t.UTC()
		}
	}

	payload := strings.TrimSpace(in.PayloadJson)
	if payload == "" {
		m := map[string]string{
			"device_id":    deviceID,
			"platform":     strings.TrimSpace(in.Platform),
			"os_version":   strings.TrimSpace(in.OsVersion),
			"app_version":  strings.TrimSpace(in.AppVersion),
			"device_name":  strings.TrimSpace(in.DeviceName),
			"last_seen":    lastSeen.Format(time.RFC3339),
		}
		b, _ := json.Marshal(m)
		payload = string(b)
	}

	var dev model.UserDevice
	db := l.svcCtx.DB.Where("user_id = ? AND device_id = ?", uint(userID), deviceID).First(&dev)
	if db.Error != nil {
		if db.Error == gorm.ErrRecordNotFound {
			var deleted model.UserDevice
			if err := l.svcCtx.DB.Unscoped().
				Where("user_id = ? AND device_id = ?", uint(userID), deviceID).
				First(&deleted).Error; err == nil {
				dev = deleted
				dev.DeletedAt = gorm.DeletedAt{}
			} else if err == gorm.ErrRecordNotFound {
				dev = model.UserDevice{
					UserID:   uint(userID),
					DeviceID: deviceID,
				}
			} else {
				l.Errorf("查询用户设备失败: %v", err)
				return nil, errorx.Internal("同步设备信息失败")
			}
		} else {
			l.Errorf("查询用户设备失败: %v", db.Error)
			return nil, errorx.Internal("同步设备信息失败")
		}
	}

	dev.Platform = strings.TrimSpace(in.Platform)
	dev.OSVersion = strings.TrimSpace(in.OsVersion)
	dev.AppVersion = strings.TrimSpace(in.AppVersion)
	dev.DeviceName = strings.TrimSpace(in.DeviceName)
	dev.PayloadJSON = payload
	dev.LastSeenAt = lastSeen

	if dev.ID == 0 {
		if err := l.svcCtx.DB.Omit("User").Create(&dev).Error; err != nil {
			l.Errorf("创建设备记录失败: %v", err)
			return nil, errorx.Internal("同步设备信息失败")
		}
	} else {
		if err := l.svcCtx.DB.Unscoped().Save(&dev).Error; err != nil {
			l.Errorf("更新设备记录失败: %v", err)
			return nil, errorx.Internal("同步设备信息失败")
		}
	}

	// 清理历史上误写入 user_memories 的设备项。
	if err := l.svcCtx.DB.Where(
		"user_id = ? AND (`key` LIKE ? OR source = ?)",
		uint(userID), "device_info:%", "device_sync",
	).Delete(&model.UserMemory{}).Error; err != nil {
		l.Errorf("清理旧设备记忆失败: %v", err)
	}

	return &super.SyncUserDeviceResp{Device: userDeviceToRecord(&dev, in.UserId)}, nil
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
