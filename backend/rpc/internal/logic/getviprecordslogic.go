package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipRecordsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipRecordsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipRecordsLogic {
	return &GetVipRecordsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 用户相关服务
func (l *GetVipRecordsLogic) GetVipRecords(in *super.GetVipRecordsReq) (*super.GetVipRecordsResp, error) {
	// 确保page和page_size有默认值
	page := in.Page
	if page <= 0 {
		page = 1
	}
	pageSize := in.PageSize
	if pageSize <= 0 {
		pageSize = 10
	}

	// 计算偏移量
	offset := (page - 1) * pageSize

	// 查询VIP订单列表（包含VIP记录功能）
	var orders []model.VipOrder
	var total int64

	// 获取总数
	l.svcCtx.DB.Model(&model.VipOrder{}).Where("user_id = ?", in.UserId).Count(&total)

	// 分页查询，预加载套餐信息
	result := l.svcCtx.DB.Preload("Plan").Where("user_id = ?", in.UserId).Offset(int(offset)).Limit(int(pageSize)).Find(&orders)
	if result.Error != nil {
		l.Error("获取VIP记录失败: ", result.Error)
		return nil, errorx.Internal("获取VIP记录失败")
	}

	// 构建响应
	respRecords := make([]*super.VipRecord, len(orders))
	for i, order := range orders {
		status := "inactive"
		if order.IsActive {
			status = "active"
		}

		// 格式化时间
		startAt := ""
		endAt := ""
		if order.StartAt != nil {
			startAt = order.StartAt.Format("2006-01-02 15:04:05")
		}
		if order.EndAt != nil {
			endAt = order.EndAt.Format("2006-01-02 15:04:05")
		}

		respRecords[i] = &super.VipRecord{
			Id:        strconv.Itoa(int(order.ID)),
			UserId:    in.UserId,
			PlanId:    strconv.Itoa(int(order.PlanID)),
			PlanName:  order.Plan.Name,
			StartAt:   startAt,
			EndAt:     endAt,
			Status:    status,
			CreatedAt: order.CreatedAt.Format("2006-01-02 15:04:05"),
		}
	}

	return &super.GetVipRecordsResp{
		Records: respRecords,
		Total:   int32(total),
	}, nil
}
