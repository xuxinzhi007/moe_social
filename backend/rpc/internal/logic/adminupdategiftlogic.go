package logic

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminUpdateGiftLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateGiftLogic {
	return &AdminUpdateGiftLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminUpdateGiftLogic) AdminUpdateGift(in *super.AdminUpdateGiftReq) (*super.AdminUpdateGiftResp, error) {
	giftID, err := parseGiftID(in.GetGiftId())
	if err != nil {
		return nil, err
	}

	var gift model.Gift
	if err := l.svcCtx.DB.First(&gift, giftID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errorx.NotFound("礼物不存在")
		}
		l.Errorf("[admin] update gift load: %v", err)
		return nil, errorx.Internal("查询礼物失败")
	}

	if in.GetUpdateName() {
		name := strings.TrimSpace(in.GetName())
		if name == "" {
			return nil, errorx.InvalidArgument("礼物名称不能为空")
		}
		gift.Name = name
	}
	if in.GetUpdatePrice() {
		if in.GetPrice() < 0 {
			return nil, errorx.InvalidArgument("价格不能为负数")
		}
		gift.Price = int(in.GetPrice())
	}
	if in.GetUpdateIcon() {
		gift.Icon = strings.TrimSpace(in.GetIcon())
	}
	if in.GetUpdateDescription() {
		gift.Description = strings.TrimSpace(in.GetDescription())
	}
	if in.GetUpdateCategory() {
		cat := strings.TrimSpace(in.GetCategory())
		if cat == "" {
			return nil, errorx.InvalidArgument("分类不能为空")
		}
		gift.Category = cat
	}
	if in.GetUpdateSortOrder() {
		gift.SortOrder = int(in.GetSortOrder())
	}

	if err := l.svcCtx.DB.Save(&gift).Error; err != nil {
		l.Errorf("[admin] update gift save: %v", err)
		return nil, errorx.Internal("更新礼物失败")
	}

	return &super.AdminUpdateGiftResp{
		Gift: giftModelToProto(gift),
	}, nil
}
