package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListLevelConfigsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListLevelConfigsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListLevelConfigsLogic {
	return &AdminListLevelConfigsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminListLevelConfigsLogic) AdminListLevelConfigs(in *super.AdminListLevelConfigsReq) (*super.AdminListLevelConfigsResp, error) {
	var rows []model.LevelConfig
	if err := l.svcCtx.DB.Order("level ASC").Find(&rows).Error; err != nil {
		return nil, err
	}
	items := make([]*super.AdminLevelConfigItem, 0, len(rows))
	for _, row := range rows {
		items = append(items, levelConfigToProto(row))
	}
	return &super.AdminListLevelConfigsResp{Items: items}, nil
}
