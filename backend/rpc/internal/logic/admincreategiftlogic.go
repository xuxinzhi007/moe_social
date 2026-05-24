package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminCreateGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminCreateGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateGiftLogic {
	return &AdminCreateGiftLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminCreateGiftLogic) AdminCreateGift(in *super.AdminCreateGiftReq) (*super.AdminCreateGiftResp, error) {
	name := strings.TrimSpace(in.GetName())
	if name == "" {
		return nil, errorx.InvalidArgument("礼物名称不能为空")
	}
	if in.GetPrice() < 0 {
		return nil, errorx.InvalidArgument("价格不能为负数")
	}
	category := strings.TrimSpace(in.GetCategory())
	if category == "" {
		category = "special"
	}

	gift := model.Gift{
		Name:        name,
		Price:       int(in.GetPrice()),
		Icon:        strings.TrimSpace(in.GetIcon()),
		Description: strings.TrimSpace(in.GetDescription()),
		Category:    category,
		SortOrder:   int(in.GetSortOrder()),
	}
	if err := l.svcCtx.DB.Create(&gift).Error; err != nil {
		l.Errorf("[admin] create gift: %v", err)
		return nil, errorx.Internal("创建礼物失败")
	}

	return &super.AdminCreateGiftResp{
		Gift: giftModelToProto(gift),
	}, nil
}
