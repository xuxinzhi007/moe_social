package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipOrdersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipOrdersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipOrdersLogic {
	return &GetVipOrdersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}
// 用户相关服务
func (l *GetVipOrdersLogic) GetVipOrders(in *rpc.GetVipOrdersReq) (*rpc.GetVipOrdersResp, error) {
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

	// 查询订单列表
	var orders []model.VipOrder
	var total int64

	// 获取总数
	l.svcCtx.DB.Model(&model.VipOrder{}).Where("user_id = ?", in.UserId).Count(&total)

	// 分页查询，预加载套餐信息
	result := l.svcCtx.DB.Preload("Plan").Where("user_id = ?", in.UserId).Offset(int(offset)).Limit(int(pageSize)).Find(&orders)
	if result.Error != nil {
		l.Error("获取订单列表失败: ", result.Error)
		return nil, errorx.Internal("获取订单列表失败: " + result.Error.Error())
	}

	// 构建响应
	respOrders := make([]*rpc.VipOrder, len(orders))
	for i, order := range orders {
		paidAt := ""
		// 这里可以根据订单状态设置paid_at
		// if order.Status == "paid" {
		//     paidAt = order.UpdatedAt.Format("2006-01-02 15:04:05")
		// }

		respOrders[i] = &rpc.VipOrder{
			Id:        string(rune(order.ID)),
			UserId:    in.UserId,
			PlanId:    string(rune(order.PlanID)),
			PlanName:  order.Plan.Name,
			Amount:    float32(order.Amount),
			Status:    order.Status,
			CreatedAt: order.CreatedAt.Format("2006-01-02 15:04:05"),
			PaidAt:    paidAt,
		}
	}

	return &rpc.GetVipOrdersResp{
		Orders: respOrders,
		Total:  int32(total),
	}, nil
}
