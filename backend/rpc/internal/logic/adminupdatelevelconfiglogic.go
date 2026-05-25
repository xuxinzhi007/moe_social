package logic

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminUpdateLevelConfigLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateLevelConfigLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateLevelConfigLogic {
	return &AdminUpdateLevelConfigLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminUpdateLevelConfigLogic) AdminUpdateLevelConfig(in *super.AdminUpdateLevelConfigReq) (*super.AdminUpdateLevelConfigResp, error) {
	id := uint(in.GetId())
	if id == 0 {
		return nil, errors.New("invalid level_id")
	}
	var row model.LevelConfig
	if err := l.svcCtx.DB.First(&row, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("level config not found")
		}
		return nil, err
	}
	updates := map[string]interface{}{}
	if in.GetUpdateTitle() {
		updates["title"] = strings.TrimSpace(in.GetTitle())
	}
	if in.GetUpdateMinExp() {
		updates["min_exp"] = int(in.GetMinExp())
	}
	if in.GetUpdateMaxExp() {
		updates["max_exp"] = int(in.GetMaxExp())
	}
	if in.GetUpdatePrivileges() {
		updates["privileges"] = strings.TrimSpace(in.GetPrivileges())
	}
	if in.GetUpdateBadgeUrl() {
		updates["badge_url"] = strings.TrimSpace(in.GetBadgeUrl())
	}
	if len(updates) == 0 {
		return &super.AdminUpdateLevelConfigResp{Item: levelConfigToProto(row)}, nil
	}
	if err := l.svcCtx.DB.Model(&row).Updates(updates).Error; err != nil {
		return nil, err
	}
	if err := l.svcCtx.DB.First(&row, id).Error; err != nil {
		return nil, err
	}
	return &super.AdminUpdateLevelConfigResp{Item: levelConfigToProto(row)}, nil
}
